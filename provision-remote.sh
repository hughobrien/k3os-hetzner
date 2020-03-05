#!/bin/bash
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

if [ "${hosting:-""}" ]; then
	url_install="${hosting}/${k3os_ver}/install.sh"
	url_iso="${hosting}/${k3os_ver}/k3os-amd64.iso"
else
	url_install="https://raw.githubusercontent.com/rancher/k3os/${k3os_ver}/install.sh"
	url_iso="https://github.com/rancher/k3os/releases/download/${k3os_ver}/k3os-amd64.iso"
fi

disk="/dev/sda"
config_file=$(mktemp)
script="$(mktemp)"

# NB: this basically all presumes a /24
network_base=$(echo "$node_ipv4_private" | cut -d '.' -f 1-3)
network_cidr="${network_base}.0/${node_cidr_private}"
network_gw="${network_base}.1"
network_gw_dev="eth1"

cluster_url="https://${cluster_master}:6443"

cat << EOF > "$config_file"
ssh_authorized_keys:
- $(awk '{print $1,$2}' < /root/.ssh/authorized_keys)
hostname: $node_name
run_cmd:
- ip route add ${network_cidr} via ${network_gw} dev ${network_gw_dev}
EOF

if [ "$node_idx" -eq 0 ]; then
	cat << EOF >> "$config_file"
k3os:
  k3s_args:
  - server
  - --bind-address=$node_ipv4_private
  - --advertise-address=$node_ipv4_private
  - --node-ip=$node_ipv4_private
  - --node-external-ip=$node_ipv4_public
  token: $cluster_secret
EOF
else
	cat << EOF >> "$config_file"
k3os:
  k3s_args:
  - agent
  - --node-ip=$node_ipv4_private
  - --node-external-ip=$node_ipv4_public
  server_url: $cluster_url
  token: $cluster_secret
EOF
fi

cat << EOF >> "$config_file"
  labels:
    datacenter: $node_datacenter
    location: $node_location
    server_type: $node_server_type
  ntp_servers:
  - 0.de.pool.ntp.org
  - 1.de.pool.ntp.org
  dns_nameservers:
  - 213.133.98.98
  - 213.133.99.99
  - 213.133.100.100
  - 2a01:4f8:0:a0a1::add:1010
  - 2a01:4f8:0:a102::add:9999
  - 2a01:4f8:0:a111::add:9898
EOF

curl -Lo "$script" "$url_install"
chmod +x "$script"

"$script" \
	--config "$config_file" \
	"$disk" \
	"$url_iso"

reboot
#multi master
#  - --cluster-init
#  - --server=$cluster_url

# also try via conf
#  server_url: $cluster_url
