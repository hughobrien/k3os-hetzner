#!/usr/bin/env bash
set -xeuo pipefail

# shellcheck disable=SC2016
jq_ns_template='{"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": $ns}}'

longhorn_ver="v0.8.0"
longhorn_manifest_url="https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_ver}/deploy/longhorn.yaml"

argo_workflows_ver="v2.7.2"
argo_workflows_manifest_url="https://raw.githubusercontent.com/argoproj/argo/${argo_workflows_ver}/manifests/install.yaml"

argo_cd_ver="v1.5.1"
argo_cd_manifest_url="kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${argo_cd_ver}/manifests/install.yaml"

# longhorn
kubectl apply -f "$longhorn_manifest_url"
longhorn_cert="secrets/longhorn-cert.yaml"
[ -f "$longhorn_cert" ] && kubectl apply -f "$longhorn_cert"
kubectl apply -f manifests/longhorn-ingress-storageclass.yaml

# docker registry
jq -n --arg ns docker-registry "$jq_ns_template" | kubectl apply -f -
docker_registry_cert="secrets/registry-cert.yaml"
[ -f "$docker_registry_cert" ] && kubectl apply -f "$docker_registry_cert"

docker_registry_htpasswd="secrets/registry-htpasswd.yaml"
docker_registry_credentials="secrets/registry-credentials.yaml"

if [ ! -f "$docker_registry_htpasswd" ]; then
	docker_registry_password="secrets/registry.pw"
	docker_registry_user="k3s"
	openssl rand -out "$docker_registry_password" -hex 32

	kubectl create secret generic -n docker-registry \
		"$(basename $docker_registry_htpasswd)" \
		--dry-run=client -o yaml \
		--from-file=htpasswd=<(htpasswd -Bin "$docker_registry_user" < "$docker_registry_password") \
		> "$docker_registry_htpasswd"
	kubectl apply -f "$docker_registry_htpasswd"

	kubectl create secret docker-registry \
		"$(basename $docker_registry_credentials)" \
		--docker-server=registry.k3s.hughobrien.ie \
		--docker-username="$docker_registry_user" \
		--docker-password="$(cat "$docker_registry_password")" \
		--dry-run=client -o yaml > "$docker_registry_credentials"
	kubectl apply -f "$docker_registry_credentials"
fi
kubectl apply -f manifests/docker-registry.yaml

# prometheus
jq -n --arg ns prometheus "$jq_ns_template" | kubectl apply -f -
prometheus_cert="secrets/prometheus-cert.yaml"
[ -f "$prometheus_cert" ] && kubectl apply -f "$prometheus_cert"
kubectl apply -f manifests/prometheus.yaml

# argo workflows
jq -n --arg ns argo "$jq_ns_template" | kubectl apply -f -
kubectl apply -n argo -f "$argo_workflows_manifest_url"
argo_cert="secrets/argo-cert.yaml"
[ -f "$argo_cert" ] && kubectl apply -f "$argo_cert"
kubectl apply -f manifests/argo-ingress.yaml

# argo cd
jq -n --arg ns argocd "$jq_ns_template" | kubectl apply -f -
kubectl apply -n argocd -f "$argo_cd_manifest_url"
# use argo in open mode
kubectl patch deploy -n argocd argocd-server --type json \
	-p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]'
argocd_cert="secrets/argocd-cert.yaml"
[ -f "$argocd_cert" ] && kubectl apply -f "$argocd_cert"
kubectl apply -f manifests/argocd-ingress.yaml
