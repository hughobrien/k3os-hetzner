#!/usr/bin/env bash
set -xeuo pipefail

node_ipv4_public="$1"

k3os_user=rancher
ssh_key=secrets/ssh-terraform
ssh_opts="-o StrictHostKeyChecking=no"

kaf="ssh $ssh_opts -i $ssh_key ${k3os_user}@${node_ipv4_public} kubectl apply -f -"

longhorn_ver="v0.8.0-rc2"
longhorn_controller="https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_ver}/deploy/longhorn.yaml"
#
for url in "$longhorn_controller"; do
	curl --silent "$url" | $kaf
done

for f in secrets/b2.yaml manifests/minio.yaml; do
	cat "$f" | $kaf
done
