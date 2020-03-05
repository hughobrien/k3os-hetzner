#!/bin/bash
set -xeuo pipefail

host="$1"
name="$2"
location="$3"
datacenter="$4"
server_type="$5"
set +x
cluster_secret="$6"
set -x
cidr_pod="$7"
cidr_service="$8"
cluster_url="$9"
k3os_ver="${10}"
node_idx="${11}"
node_ipv4_public="${12}"

rescue_user=root
key=ssh-terraform
script_name=provision-remote.sh
script_dest="/tmp/${script_name}"
ssh_opts="-o StrictHostKeyChecking=no"

[ -z "${hosting:-""}" ] && echo hosting not set, falling back on github

# remove existing ssh keys
ssh-keygen -R "$host"
set +e
response=""
while [ "$response" != "rescue" ]; do
	sleep 5
	response=$(ssh -i "$key" "$ssh_opts" "${rescue_user}@${host}" hostname)
done

scp "$ssh_opts" -i "$key" "$script_name" "${rescue_user}@${host}:${script_dest}"
ssh "$ssh_opts" -i "$key" "${rescue_user}@${host}" \
	hosting="${hosting:-""}" \
	"$script_dest" \
	"$name" \
	"$location" \
	"$datacenter" \
	"$server_type" \
	"$cluster_secret" \
	"$cidr_pod" \
	"$cidr_service" \
	"$cluster_url" \
	"$k3os_ver" \
	"$node_idx" \
	"$node_ipv4_public"

# remove rescue ssh key
ssh-keygen -R "$host"
