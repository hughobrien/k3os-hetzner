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
longhorn_controller="https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_ver}/deploy/longhorn.yaml"

# ensure traefik is already installed
while [ "$($kubectl get configmap -n kube-system traefik | wc -l)" != 2 ] ; do
	sleep 5
done


# shellcheck disable=SC2066
for url in "$longhorn_controller"; do
	curl --silent "$url" | $kaf
done

# shellcheck disable=SC2043
for f in manifests/*; do
	$kaf < "$f"
done

# We updated the traefik configmap so bounce the pods
$kubectl delete pod -n kube-system -l app=traefik
