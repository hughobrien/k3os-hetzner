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

if [ "${hosting:-""}" ]; then
	#url_install="${hosting}/${k3os_ver}/install.sh" # TODO restore
	url_install="https://raw.githubusercontent.com/rancher/k3os/master/install.sh"
	url_iso="${hosting}/${k3os_ver}/k3os-amd64.iso"
else
	#url_install="https://raw.githubusercontent.com/rancher/k3os/${k3os_ver}/install.sh" # TODO restore
	url_install="https://raw.githubusercontent.com/rancher/k3os/master/install.sh"
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
flannel_mode="vxlan"

cluster_url="https://${cluster_master}:6443"

cat << EOF > "$config_file"
ssh_authorized_keys:
- $(awk '{print $1,$2}' < /root/.ssh/authorized_keys)
hostname: $node_name
run_cmd:
- sh -c "ip route add ${network_cidr} via ${network_gw} dev ${network_gw_dev} || reboot"
write_files:
- path: /home/rancher/.bash_profile
  content: |
    alias k='kubectl'
    alias pods='kubectl get pods --all-namespaces --watch'
    alias orders='kubectl get orders --all-namespaces --watch'
    alias csrs='kubectl get certificaterequests --all-namespaces --watch'
    alias ingress='kubectl get ingress --all-namespaces --watch'
    alias services='kubectl get services --all-namespaces --watch'
    alias hosts='kubectl get ingress --all-namespaces  -o jsonpath="{.items[*].spec.rules[*].host}" | xargs -n 1 | sed "s|^|https://|" | sort'
  owner: rancher
  permissions: '0644'
  encoding: ""
EOF

# TODO wireguard
if [ "$node_idx" -eq 0 ]; then
	cat << EOF >> "$config_file"
k3os:
  k3s_args:
  - server
  - --no-deploy=traefik
  - --flannel-backend=$flannel_mode
  - --bind-address=$node_ipv4_private
  - --advertise-address=$node_ipv4_private
EOF
else
	cat << EOF >> "$config_file"
k3os:
  k3s_args:
  - agent
  - --server=$cluster_url
EOF
fi

cat << EOF >> "$config_file"
  - --node-ip=$node_ipv4_private
  - --node-external-ip=$node_ipv4_public
  token: $cluster_secret
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
