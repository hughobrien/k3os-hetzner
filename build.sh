#!/usr/bin/env bash

set -euo pipefail

hcloud_secret_file="secrets/hetzner-token"

[ ! -f "$hcloud_secret_file" ] && {
	echo provide hetzner token "$hcloud_secret_file"
	exit 1
}

ssh_key="secrets/ssh-terraform"
[ ! -f "$ssh_key" ] && {
	echo generate ssh key "$ssh_key"
	exit 1
}

HCLOUD_TOKEN=$(cat "$hcloud_secret_file")

hosting_file="secrets/hosting"
[ -f "$hosting_file" ] && hosting=$(cat "$hosting_file")

set -x

export HCLOUD_TOKEN
export hosting

pushd terraform

destroy=${destroy:-""}
[ "$destroy" ] && terraform destroy -auto-approve

# Two part apply needed to generate names
terraform apply \
	-target random_pet.servers \
	-target random_pet.networks \
	-auto-approve
terraform apply -auto-approve
