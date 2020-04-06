#!/usr/bin/env bash
set -xeuo pipefail

node_ipv4_public="$1"

k3os_user=rancher
ssh_key=secrets/ssh-terraform
ssh_opts="-o StrictHostKeyChecking=no"

kubectl="ssh $ssh_opts -i $ssh_key ${k3os_user}@${node_ipv4_public} kubectl"

$kubectl get secret -n prometheus prometheus-cert -o yaml > secrets/prometheus-cert.yaml
$kubectl get secret -n longhorn-system longhorn-cert -o yaml > secrets/longhorn-cert.yaml
