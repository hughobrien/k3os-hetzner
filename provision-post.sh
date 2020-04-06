#!/usr/bin/env bash
set -xeuo pipefail

node_ipv4_public="$1"

k3os_user=rancher
ssh_key=secrets/ssh-terraform
ssh_opts="-o StrictHostKeyChecking=no"

kubectl="ssh $ssh_opts -i $ssh_key ${k3os_user}@${node_ipv4_public} kubectl"
kaf="$kubectl apply -f -"

one_off_manifest=${2:-""}
[ "$one_off_manifest" ] && {
	$kaf < "$one_off_manifest"
	exit 0
}

longhorn_ver="v0.8.0"
longhorn_manifest="https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_ver}/deploy/longhorn.yaml"

certmanager_ver="v0.14.1"
certmanager_manifest="https://github.com/jetstack/cert-manager/releases/download/${certmanager_ver}/cert-manager.yaml"

# ensure traefik is already installed
while [ "$($kubectl get configmap -n kube-system traefik | wc -l | xargs)" != 2 ]; do
	sleep 5
done

for url in \
	"$longhorn_manifest" \
	"$certmanager_manifest"; do
	curl --location --silent "$url" | $kaf
done

# ensure certmanager is ready
while [ "$($kubectl get pods -n cert-manager -l app=webhook -o json | jq '.items[0].status.containerStatuses[0].ready')" != true ]; do
	sleep 5
done

# shellcheck disable=SC2043
for namespace in prometheus; do
	$kubectl create namespace "$namespace"
done

for service in prometheus longhorn traefik; do
	[ -e "secrets/${service}-cert" ] && $kaf < "secrets/${service}-cert"
done

for f in manifests/*; do
	$kaf < "$f"
done
