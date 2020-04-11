#!/usr/bin/env bash

set -euo pipefail

for cmd in terraform shfmt shellcheck htpasswd openssl kubectl jq; do
	[ -z "$(command -v $cmd)" ] && (
		echo $cmd not found
		exit 1
	)
done

HCLOUD_TOKEN=$(cat secrets/hetzner-token)
export HCLOUD_TOKEN

set -x

pushd terraform
for f in *.tf terraform.tfvars; do
	terraform fmt "$f"
done
terraform validate
popd

for f in *.sh; do
	shellcheck "$f"
	shfmt -s -sr -d "$f"
done

for f in manifests/*; do
	yamllint -c .yamllint "$f"
done
