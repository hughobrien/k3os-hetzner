variable "default_cidr_offset" { default = 2 }
variable "default_image" { default = "debian-10" }
variable "default_k3os_ver" { default = "v0.10.0" }
variable "default_rescue" { default = "linux64" }
variable "fqdn" { default = "k3s.hughobrien.ie" }
variable "master_server_type" {}
variable "network" { type = map(string) }
variable "node_server_type" {}
variable "presence" { type = list(map(string)) }
