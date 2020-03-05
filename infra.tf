# have HCLOUD_TOKEN exported
# have your ssh key in your agent
# TODO add LB to different networks for blue/green (up to 3)

locals {
  hosts_numbered = sort(flatten([for region in var.presence : [for elem in range(region["count"]) : "${region["code"]}-${elem}"]]))
  hosts_named    = { for host in local.hosts_numbered : "${split("-", host)[0]}-${random_pet.servers[host].id}" => { "idx" : index(local.hosts_numbered, host), "location" : "${split("-", host)[0]}", "name" : "${split("-", host)[0]}-${random_pet.servers[host].id}", "id" : host } }
}

resource "random_pet" "servers" {
  for_each = toset(local.hosts_numbered)
  length   = 2
  keepers = {
    k3os_ver = var.default_k3os_ver
  }
}

resource "random_pet" "networks" {
  length = 1
}

resource "hcloud_network" "vpc" {
  name     = random_pet.networks.id
  ip_range = var.network["vpc"]
}

resource "hcloud_network_subnet" "subnet" {
  network_id   = hcloud_network.vpc.id
  type         = "server" # required?
  network_zone = var.network["zone"]
  ip_range     = var.network["host"]
}

resource "hcloud_server" "hosts" {
  for_each    = local.hosts_named
  location    = each.value["location"]
  name        = each.key
  image       = var.default_image
  rescue      = var.default_rescue
  server_type = var.default_server_type
  ssh_keys    = [hcloud_ssh_key.ssh-terraform.id]
  provisioner "local-exec" {
    command = <<-EOT
    bash provision-local.sh \
		${each.value["idx"]} \
		${self.name} \
		${self.ipv4_address} \
		${cidrhost(var.network["host"], each.value["idx"] + var.default_cidr_offset)} \
		${split("/", var.network["host"])[1]} \
		${self.location} \
		${self.datacenter} \
		${self.server_type} \
		${var.default_k3os_ver} \
		${cidrhost(var.network["host"], var.default_cidr_offset)} \
		'${random_password.cluster_secret.result}'
		EOT
  }
}

resource "hcloud_server_network" "network_bindings" {
  for_each   = local.hosts_named
  server_id  = hcloud_server.hosts[each.key].id
  network_id = hcloud_network.vpc.id
  ip         = cidrhost(var.network["host"], each.value["idx"] + var.default_cidr_offset)
}

#resource "hcloud_floating_ip" "ingress-nbg-0" {
#description   = "nbg0-in"
#type          = "ipv4"
#home_location = data.hcloud_location.primary.name
#}

#resource "hcloud_floating_ip_assignment" "ingress-nbg-0" {
#floating_ip_id = hcloud_floating_ip.ingress-nbg-0.id
#server_id      = hcloud_server.ingress-nbg-0.id
#}

resource "hcloud_ssh_key" "ssh-terraform" {
  name       = "Terraform SSH key"
  public_key = file("ssh-terraform.pub")
}

resource "random_password" "cluster_secret" {
  length  = 32
  special = false
}
#resource "hcloud_volume" "ingress-nbg-0" {
#  name     = "nbg0-in"
#  size     = 10
#  location = data.hcloud_location.primary.name
#  format   = "ext4" # req'd for k3os --takeover
#}
#
#resource "hcloud_volume_attachment" "ingress-nbg-0" {
#  volume_id = hcloud_volume.ingress-nbg-0.id
#  server_id = hcloud_server.ingress-nbg-0.id
#  automount = true
#}

#data "hcloud_location" "primary" {
#  name = "nbg1"
#}
#
#data "hcloud_location" "secondary" {
#  name = "fsn1"
#}

provider "hcloud" {
  version = "~> 1.15"
}

provider "random" {
  version = "~> 2.2"
}

output "conn_str" {
  value = {
    for host in local.hosts_named :
    "${host.idx} ${host.name}" => "ssh -i ssh-terraform -o StrictHostKeyChecking=no rancher@${hcloud_server.hosts[host.name].ipv4_address}"
  }
}
