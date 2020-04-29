#!/usr/bin/env bash
set -xeuo pipefail

# This setups up remote access so later provisioning can proceed locally
# The K8s API is exposed via an nginx mtls ingress for additional protection

fqdn="k3s.hughobrien.ie"

certmanager_ver="v0.14.3"
certmanager_manifest_url="https://github.com/jetstack/cert-manager/releases/download/${certmanager_ver}/cert-manager.yaml"

ingress_nginx_ver="nginx-0.30.0"
ingress_nginx_manifest_url1="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${ingress_nginx_ver}/deploy/static/mandatory.yaml"
ingress_nginx_manifest_url2="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${ingress_nginx_ver}/deploy/static/provider/baremetal/service-nodeport.yaml"

k3os_user=rancher
ssh_key=secrets/ssh-terraform
ssh_opts="-o StrictHostKeyChecking=no"

# NB: kubectl is local. $kubectl is remote
ssh="ssh $ssh_opts -i $ssh_key ${k3os_user}@master.${fqdn}"
kubectl="$ssh kubectl"

mknamespace() {
	jq -n --arg ns "$1" '{"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": $ns}}' |
		$kubectl apply -f -
}

newca=${newca:-""}
[ "$newca" ] && {
	rm -f secrets/ca.{crt,key}
	rm -f secerts/client.{crt,csr,key,p12}
	rm -f secrets/ingress-cert.yaml
}

while [ ! "$($ssh hostname)" ]; do
	sleep 10
	echo waiting for host
done

while [ ! "$($kubectl get service kubernetes -o jsonpath='{.spec.clusterIP}')" ]; do
	sleep 10
	echo waiting for k3s
done

# preconfig for dry-run yaml generation
kubectl config set-cluster "$fqdn" --server="https://${fqdn}"
kubectl config set-credentials "$fqdn" --username=admin
kubectl config set-context "$fqdn" --cluster="$fqdn" --user="$fqdn"
kubectl config use-context "$fqdn"

# ingress-nginx
if [ ! -f secrets/ingress-cert.yaml ]; then
	# https://github.com/kubernetes/ingress-nginx/blob/master/docs/examples/auth/client-certs/README.md#creating-certificate-secrets
	mkdir -p secrets
	pushd secrets
	openssl rand -out ca.pw -hex 32
	openssl req -x509 -sha256 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 3650 -subj "/CN=${fqdn}" -passout file:ca.pw
	openssl req -new -newkey rsa:4096 -keyout client.key -out client.csr -subj "/CN=client1-${fqdn}" -nodes
	openssl x509 -req -sha256 -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt -passin file:ca.pw
	rm client.csr
	kubectl create secret generic -n ingress-nginx ingress-cert --from-file=ca.crt=ca.crt -o yaml --dry-run=client > ingress-cert.yaml

	# export as p12 for browsers
	openssl pkcs12 -export -passout pass:"$fqdn" -inkey client.key -in client.crt -out client.p12
	popd
fi

mknamespace ingress-nginx
$kubectl apply -f - < secrets/ingress-cert.yaml
$kubectl apply -f "$ingress_nginx_manifest_url1"
$kubectl apply -f "$ingress_nginx_manifest_url2"
# make ingress an LB so that svclb picks it up
$kubectl patch service -n ingress-nginx ingress-nginx \
	-p \''{"spec":{"type":"LoadBalancer"}}'\'

# ensure nginx is ready
while [ "$($kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath=\''{.items[].status.containerStatuses[].ready}'\')" != true ]; do
	echo awaiting ingress-nginx deployment
	sleep 5
done

# cert-manager
$kubectl apply -f "$certmanager_manifest_url"
# ensure certmanager is ready
while [ "$($kubectl get pods -n cert-manager -l app=webhook -o jsonpath=\''{.items[].status.containerStatuses[].ready}'\')" != true ]; do
	echo awaiting cert-manager deployment
	sleep 5
done
$kubectl apply -f - < manifests/cert-manager-acme-issuer.yaml

# LE signed API cert
[ -f secrets/k3s-cert.yaml ] && $kubectl apply -f - < secrets/k3s-cert.yaml

# k8s api ingress
$kubectl apply -f - < manifests/kubernetes-api-ingress.yaml

kubectl config set-credentials "$fqdn" \
	--username=admin \
	--password="$($kubectl config view -o jsonpath=\''{.users[0].user.password}'\' | xargs)" \
	--client-key=secrets/client.key \
	--client-certificate=secrets/client.crt \
	--embed-certs

# wait for api cert
while [ ! "$($kubectl get secret k3s-cert -o jsonpath=\''{.data.tls\.crt}'\')" ]; do
	$kubectl get pods
	$kubectl get orders -o jsonpath=\''{.items[].status.state}'\'
	echo awaiting LE cert provisioning
	sleep 30
done

sleep 10
kubectl get nodes -o wide
