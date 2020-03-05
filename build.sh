#!/usr/bin/env bash

set -euo pipefail

HCLOUD_TOKEN=$(cat token)
set -x

for f in *.tf terraform.tfvars; do ./terraform fmt "$f"; done
for f in *.sh; do shellcheck "$f" && shfmt -s -sr -d "$f"; done

export HCLOUD_TOKEN

destroy=${destroy:-""}
[ "$destroy" ] && ./terraform destroy

./terraform apply \
	-target random_pet.servers \
	-target random_pet.networks \
	-auto-approve
./terraform apply

./terraform state list
