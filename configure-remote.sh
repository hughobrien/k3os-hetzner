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
kubectl="ssh $ssh_opts -i $ssh_key ${k3os_user}@${node_ipv4_public} kubectl"

# preconfig for dry-run yaml generation
kubectl config set-cluster k3s --server=https://k3s.hughobrien.ie
kubectl config set-credentials k3s --username=admin
kubectl config set-context k3s --cluster=k3s --user=k3s
kubectl config use-context k3s

# ingress-nginx
$kubectl apply -f "$ingress_nginx_manifest_url1"
$kubectl apply -f "$ingress_nginx_manifest_url2"
# make ingress an LB so that svclb picks it up
$kubectl patch service -n ingress-nginx ingress-nginx \
	-p \''{"spec":{"type":"LoadBalancer"}}'\'

# ingress ca
ingress_cert="secrets/ingress-cert.yaml"
subj="/CN=hughobrien.ie"
ca_pw="secrets/ca.key.pw"
ca_key="secrets/ca.key"
ca_crt="secrets/ca.crt"
client_key="secrets/client.key"
client_crt="secrets/client.crt"
client_req="secrets/client.req"
client_p12="secrets/client.p12"
if [ -f "$ingress_cert" ]; then
	$kubectl apply -f - < "$ingress_cert"
else
	# ca key password
	mkdir -p "$(dirname "$ca_pw")"
	openssl rand -out "$ca_pw" -hex 32
	# ca key
	openssl req -new -newkey rsa:4096 \
		-days 36500 -x509 -subj "$subj" \
		-keyout "$ca_key" -out "$ca_crt" -passout file:"$ca_pw"
	#  client key
	openssl genrsa -out "$client_key" 4096
	# client signing request
	openssl req -new \
		-key "$client_key" -out "$client_req" -subj "$subj"
	# sign client request with ca key
	openssl x509 -req \
		-CA "$ca_crt" -CAkey "$ca_key" -passin file:"$ca_pw" \
		-set_serial 101 -days 3650 \
		-in "$client_req" -out "$client_crt"
	# export as p12 for browsers
	openssl pkcs12 -export -passout pass:"" \
		-inkey "$client_key" -in "$client_crt" -out "$client_p12"
	# add to cluster for nginx mtls reference
	kubectl create secret generic -n ingress-nginx ingress-ca-cert \
		--dry-run=client --from-file=ca.crt="$ca_crt" -o yaml > "$ingress_cert"
	$kubectl apply -f - < "$ingress_cert"
	rm "$client_req"
fi

# cert-manager
$kubectl apply -f "$certmanager_manifest_url"
# ensure certmanager is ready
while [ "$($kubectl get pods -n cert-manager -l app=webhook -o jsonpath='{.items[].status.containerStatuses[].ready}')" != true ]; do
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
	--password="$($kubectl config view -o jsonpath='{.users[0].user.password}' | xargs)" \
	--client-key="$client_key" \
	--client-certificate="$client_crt" \
	--embed-certs

# wait for api cert
while [ ! "$($kubectl get secret k3s-cert -o jsonpath='{.data.tls\.crt}')" ]; do
	$kubectl get pods
	$kubectl get orders -o json | jq '.items[].status'
	echo awaiting LE cert provisioning
	sleep 30
done

kubectl get nodes -o wide || echo perhaps LE cert is not ready yet
