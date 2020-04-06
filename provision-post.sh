#!/usr/bin/env bash
set -xeuo pipefail

node_ipv4_public="$1"

k3os_user=rancher
ssh_key=secrets/ssh-terraform
ssh_opts="-o StrictHostKeyChecking=no"

kubectl="ssh $ssh_opts -i $ssh_key ${k3os_user}@${node_ipv4_public} kubectl"
kaf="$kubectl apply -f -"

one_off_manifest=${2:-""}
[ "$one_off_manifest" ] && { $kaf < "$one_off_manifest"; exit 0; }

longhorn_ver="v0.8.0"
longhorn_manifest="https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_ver}/deploy/longhorn.yaml"

certmanager_ver="v0.14.1"
certmanager_manifest="https://github.com/jetstack/cert-manager/releases/download/${certmanager_ver}/cert-manager.yaml"

for url in \
	"$longhorn_manifest" \
	"$certmanager_manifest"; do
	curl --location --silent "$url" | $kaf
done

for f in manifests/*; do
	$kaf < "$f"
done
