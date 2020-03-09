#!/usr/bin/env bash

set -euo pipefail

hetzner_secret_file="secrets/hetzner-token"
HCLOUD_TOKEN=$(cat "$hetzner_secret_file")

hosting_file="secrets/hosting"
[ -f "$hosting_file" ] && hosting=$(cat "$hosting_file")

set -x

export HCLOUD_TOKEN
export hosting

destroy=${destroy:-""}
[ "$destroy" ] && terraform destroy -auto-approve

# Two part apply needed to generate names
terraform apply \
	-target random_pet.servers \
	-target random_pet.networks \
	-auto-approve
terraform apply -auto-approve
