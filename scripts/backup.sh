#!/usr/bin/env bash
set -xeuo pipefail

k="kubectl get secret -o yaml"
mkdir -p secrets
cd secrets

$k -n argo argo-cert > argo-cert.yaml
$k -n argocd argocd-cert > argocd-cert.yaml
$k -n default k3s-cert > k3s-cert.yaml
$k -n default registry-regcred > registry-regcred.yaml
$k -n docker-registry registry-htpasswd > registry-htpasswd.yaml
$k -n docker-registry registry-cert > registry-cert.yaml
$k -n longhorn-system longhorn-cert > longhorn-cert.yaml
$k -n prometheus prometheus-cert > prometheus-cert.yaml
