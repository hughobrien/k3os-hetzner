variable "network" { type = map(string) }
variable "presence" { type = list(map(string)) }
variable "default_image" { default = "debian-10" }
variable "default_rescue" { default = "linux64" }
variable "default_server_type" { default = "cx11" }
variable "default_k3os_ver" { default = "v0.9.1" }
variable "default_cidr_offset" { default = 2 }
