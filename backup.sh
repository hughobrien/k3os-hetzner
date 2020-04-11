#!/usr/bin/env bash
set -xeuo pipefail

k="kubectl get secret -o yaml"
strip="yq -Y 'del(.metadata.resourceVersion) | del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") | del(.metadata.uid)'"

mkdir -p secrets
cd secrets

$k -n argo argo-cert | $strip > argo-cert.yaml
$k -n argocd argocd-cert | $strip > argocd-cert.yaml
$k -n default k3s-cert | $strip > k3s-cert.yaml
$k -n default registry-credentials | $strip > registry-credentials.yaml
$k -n docker-registry registry-htpasswd | $strip > registry-htpasswd.yaml
$k -n docker-registry registry-cert | $strip > registry-cert.yaml
$k -n longhorn-system longhorn-cert | $strip > longhorn-cert.yaml
$k -n prometheus prometheus-cert | $strip > prometheus-cert.yaml
