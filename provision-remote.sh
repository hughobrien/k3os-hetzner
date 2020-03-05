#!/bin/bash
set -xeuo pipefail

hostname="$1"
location="$2"
datacenter="$3"
server_type="$4"
cluster_secret="$5"
cidr_pod="$6"
cidr_service="$7"
cluster_host_ip="$8"
k3os_ver="$9"
node_idx="${10}"
node_ipv4_public="${11}"

b2_bucket="https://f002.backblazeb2.com/file/radiant-public/${k3os_ver}"
urlinstall="${b2_bucket}/install.sh"
urliso="${b2_bucket}/k3os-amd64.iso"

disk="/dev/sda"
config_file=$(mktemp)
script="$(mktemp)"

network_base=$(echo "$cluster_host_ip" | cut -d '.' -f 1-3)
network_cidr="${network_base}.0/16"
network_gw="${network_base}.1"
network_gw_dev="eth1"
network_address="${network_base}.$((node_idx + 2))"

cluster_url="https://${cluster_host_ip}:6443"

cat << EOF > "$config_file"
ssh_authorized_keys:
- $(awk '{print $1,$2}' < /root/.ssh/authorized_keys)
hostname: $hostname
run_cmd:
- ip route add ${network_cidr} via ${network_gw} dev ${network_gw_dev}
EOF

if [ "$node_idx" -eq 0 ]; then
	cat << EOF >> "$config_file"
k3os:
  k3s_args:
  - server
  - --advertise-address=$network_address
  - --cluster-cidr=$cidr_pod
  - --service-cidr=$cidr_service
  - --node-ip=$network_address
  - --node-external-ip=$node_ipv4_public
  token: $cluster_secret
EOF
else
	cat << EOF >> "$config_file"
k3os:
  k3s_args:
  - agent
  - --node-ip=$network_address
  - --node-external-ip=$node_ipv4_public
  server_url: $cluster_url
  token: $cluster_secret
EOF
fi

cat << EOF >> "$config_file"
  labels:
    datacenter: $datacenter
    location: $location
    server_type: $server_type
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

curl -Lo "$script" "$urlinstall"
chmod +x "$script"

"$script" \
	--config "$config_file" \
	"$disk" \
	"$urliso"

reboot
# data_sources:
#  - hetzner

# odd ws errors
#  - --bind-address=$network_address

#multi master
#  - --cluster-init
#  - --server=$cluster_url

# also try via conf
#  server_url: $cluster_url
