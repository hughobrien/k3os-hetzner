#!/usr/bin/env bash

set -euo pipefail

for cmd in terraform shfmt shellcheck htpasswd openssl kubectl jq yq; do
	[ -z "$(command -v $cmd)" ] && (
		echo $cmd not found
		exit 1
	)
done

hcloud_secret_file="secrets/hetzner-token"
ssh_key="secrets/ssh-terraform"

for f in "$hcloud_secret_file" "$ssh_key"; do
	[ ! -f "$f" ] && {
		echo provide file "$f"
		exit 1
	}
done

HCLOUD_TOKEN=$(cat secrets/hetzner-token)
export HCLOUD_TOKEN

set -x

pushd terraform
terraform init
for f in *.tf terraform.tfvars; do
	terraform fmt "$f"
done
terraform validate
popd

shfmt -s -sr -d ./*.sh
shellcheck ./*.sh
yamllint -c .yamllint manifests/*.yaml
