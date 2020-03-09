#!/usr/bin/env bash
set -xeuo pipefail

node_idx="$1"
node_name="$2"
node_ipv4_public="$3"
node_ipv4_private="$4"
node_cidr_private="$5"
node_location="$6"
node_datacenter="$7"
node_server_type="$8"
k3os_ver="$9"
cluster_master="${10}"
cluster_secret="${11}"

rescue_user=root
ssh_key=secrets/ssh-terraform
script_name=provision-remote.sh
script_dest="/tmp/${script_name}"
ssh_opts="-o StrictHostKeyChecking=no"

# remove existing ssh keys
ssh-keygen -R "$node_ipv4_public"
set +e
response=""
while [ "$response" != "rescue" ]; do
	sleep 5
	response=$(ssh -i "$ssh_key" "$ssh_opts" "${rescue_user}@${node_ipv4_public}" hostname)
done
set -e

scp "$ssh_opts" -i "$ssh_key" "$script_name" "${rescue_user}@${node_ipv4_public}:${script_dest}"
ssh "$ssh_opts" -i "$ssh_key" "${rescue_user}@${node_ipv4_public}" \
	hosting="${hosting:-""}" \
	"$script_dest" \
	"$node_idx" \
	"$node_name" \
	"$node_ipv4_public" \
	"$node_ipv4_private" \
	"$node_cidr_private" \
	"$node_location" \
	"$node_datacenter" \
	"$node_server_type" \
	"$k3os_ver" \
	"$cluster_master" \
	"$cluster_secret"

# remove rescue ssh key
ssh-keygen -R "$node_ipv4_public"
