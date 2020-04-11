#!/usr/bin/env bash
set -xeuo pipefail

get_secret() {
	namespace="$1"
	secret_name="$2"

	[ -f "secrets/${secret_name}" ] && {
		echo "$secret_name" exists, skipping
		return 0
	}

	kubectl get secret -n "$namespace" "$secret_name" -o yaml |
		yq -Y 'del(.metadata.resourceVersion)' |
		yq -Y 'del(.metadata.uid)' |
		yq -Y 'del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration")' |
		> "secrets/${secret_name}.yaml"
}

mkdir -p secrets

get_secret argo argo-cert
get_secret argocd argocd-cert
get_secret argocd argocd-cert
get_secret default k3s-cert
get_secret default registry-credentials
get_secret docker-registry registry-htpasswd
get_secret docker-registry registry-cert
get_secret longhorn-system longhorn-cert
get_secret prometheus prometheus-cert
