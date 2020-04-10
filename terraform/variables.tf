variable "network" { type = map(string) }
variable "presence" { type = list(map(string)) }
variable "default_image" { default = "debian-10" }
variable "default_rescue" { default = "linux64" }
variable "master_server_type" {}
variable "node_server_type" {}
variable "default_k3os_ver" { default = "v0.10.0" }
variable "default_cidr_offset" { default = 2 }
