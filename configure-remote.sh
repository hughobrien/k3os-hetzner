#!/usr/bin/env bash
set -xeuo pipefail

# This setups up remote access so later provisioning can proceed locally
# The K8s API is exposed via an nginx mtls ingress for additional protection

certmanager_ver="v0.14.2"
certmanager_manifest_url="https://github.com/jetstack/cert-manager/releases/download/${certmanager_ver}/cert-manager.yaml"

ingress_nginx_ver="nginx-0.30.0"
ingress_nginx_manifest_url1="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${ingress_nginx_ver}/deploy/static/mandatory.yaml"
ingress_nginx_manifest_url2="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${ingress_nginx_ver}/deploy/static/provider/baremetal/service-nodeport.yaml"

node_ipv4_public="$1"
k3os_user=rancher
ssh_key=secrets/ssh-terraform
ssh_opts="-o StrictHostKeyChecking=no"

# NB: kubectl is local. $kubectl is remote
ssh="ssh $ssh_opts -i $ssh_key ${k3os_user}@${node_ipv4_public}"
kubectl="$ssh kubectl"

namespace() {
	jq -n --arg ns "$1" '{"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": $ns}}'
}

newca=${newca:-""}
[ "$newca" ] && rm -f secrets/{ingress-cert.yaml,client.crt,client.csr,client.key,client.p12,ca.crt,ca.key}

while [ ! "$($ssh hostname)" ]; do
	sleep 10
	echo waiting for host
done

# preconfig for dry-run yaml generation
kubectl config set-cluster k3s --server=https://k3s.hughobrien.ie
kubectl config set-credentials k3s --username=admin
kubectl config set-context k3s --cluster=k3s --user=k3s
kubectl config use-context k3s

# ingress-nginx
namespace ingress-nginx | $kubectl apply -f -

mkdir -p secrets

if [ ! -f secrets/ingress-cert.yaml ]; then
	# https://github.com/kubernetes/ingress-nginx/blob/master/docs/examples/auth/client-certs/README.md#creating-certificate-secrets
	pushd secrets
	openssl req -x509 -sha256 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 3650 -nodes -subj '/CN=My Cert Authority'
	openssl req -new -newkey rsa:4096 -keyout client.key -out client.csr -nodes -subj '/CN=My Client'
	openssl x509 -req -sha256 -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 02 -out client.crt
	kubectl create secret generic -n ingress-nginx ingress-cert --from-file=ca.crt=ca.crt -o yaml --dry-run=client > ingress-cert.yaml

	# export as p12 for browsers
	openssl pkcs12 -export -passout pass:"" -inkey client.key -in client.crt -out client.p12
	popd
fi
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
api_cert="secrets/k3s-cert.yaml"
[ -f "$api_cert" ] && $kubectl apply -f - < "$api_cert"

# k8s api ingress
$kubectl apply -f - < manifests/kubernetes-api-ingress.yaml

kubectl config set-credentials k3s \
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
