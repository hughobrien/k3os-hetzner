#!/usr/bin/env bash

set -euo pipefail

for cmd in terraform shfmt shellcheck; do
	[ -z "$(command -v $cmd)" ] && (
		echo $cmd not found
		exit 1
	)
done

HCLOUD_TOKEN=$(cat secrets/hetzner-token)

set -x

for f in *.tf terraform.tfvars; do
	terraform fmt "$f"
done

for f in *.sh; do
	shellcheck "$f"
	shfmt -s -sr -d "$f"
done

for f in manifests/*; do
	yamllint "$f"
done

export HCLOUD_TOKEN

terraform validate
