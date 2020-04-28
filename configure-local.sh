#!/usr/bin/env bash
set -xeuo pipefail

mknamespace() {
	jq -n --arg ns "$1" '{"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": $ns}}' |
		kubectl apply -f -
}

fqdn="k3s.hughobrien.ie"

longhorn_ver="v0.8.0"
longhorn_manifest_url="https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_ver}/deploy/longhorn.yaml"

argo_workflows_ver="v2.7.6"
argo_workflows_manifest_url="https://raw.githubusercontent.com/argoproj/argo/${argo_workflows_ver}/manifests/install.yaml"

argo_cd_ver="v1.5.2"
argo_cd_manifest_url="https://raw.githubusercontent.com/argoproj/argo-cd/${argo_cd_ver}/manifests/install.yaml"

newreg=${newreg:-""}
[ "$newreg" ] && rm -f secrets/registry{.pw,-htpasswd.yaml,-credentials.yaml}

# longhorn
mknamespace longhorn-system
longhorn_cert="secrets/longhorn-cert.yaml"
kubectl apply -f "$longhorn_manifest_url"
[ -f "$longhorn_cert" ] && kubectl apply -f "$longhorn_cert"
kubectl apply -f manifests/longhorn-ingress-storageclass.yaml

# docker registry
mknamespace docker-registry
docker_registry_htpasswd="secrets/registry-htpasswd.yaml"
docker_registry_credentials="secrets/registry-credentials.yaml"
if [ ! -f "$docker_registry_htpasswd" ]; then
	docker_registry_password="secrets/registry.pw"
	docker_registry_user="k3s"
	openssl rand -out "$docker_registry_password" -hex 32

	kubectl create secret generic -n docker-registry \
		registry-htpasswd \
		--dry-run=client -o yaml \
		--from-file=htpasswd=<(htpasswd -Bin "$docker_registry_user" < "$docker_registry_password") \
		> "$docker_registry_htpasswd"

	kubectl create secret docker-registry \
		registry-credentials \
		--docker-server="registry.${fqdn}" \
		--docker-username="$docker_registry_user" \
		--docker-password="$(cat "$docker_registry_password")" \
		--dry-run=client -o yaml > "$docker_registry_credentials"
fi
kubectl apply -f "$docker_registry_credentials"
kubectl apply -f "$docker_registry_htpasswd"
docker_registry_cert="secrets/registry-cert.yaml"
[ -f "$docker_registry_cert" ] && kubectl apply -f "$docker_registry_cert"
kubectl apply -f manifests/docker-registry.yaml

# prometheus
mknamespace prometheus
prometheus_cert="secrets/prometheus-cert.yaml"
[ -f "$prometheus_cert" ] && kubectl apply -f "$prometheus_cert"
kubectl apply -f manifests/prometheus.yaml
kubectl apply -f manifests/node-exporter.yaml

# argo workflows
mknamespace argo
kubectl apply -n argo -f "$argo_workflows_manifest_url"
argo_cert="secrets/argo-cert.yaml"
[ -f "$argo_cert" ] && kubectl apply -f "$argo_cert"
kubectl apply -f manifests/argo-ingress.yaml

# argo cd
mknamespace argocd
kubectl apply -n argocd -f "$argo_cd_manifest_url"
# use argo in open mode
kubectl patch deploy -n argocd argocd-server --type json \
	-p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]'
argocd_cert="secrets/argocd-cert.yaml"
[ -f "$argocd_cert" ] && kubectl apply -f "$argocd_cert"
kubectl apply -f manifests/argocd-ingress.yaml

# add extra nginx
kubectl scale deployment -n ingress-nginx nginx-ingress-controller --replicas=2

kubectl get nodes -o wide
echo docker login -u k3s -p "$(cat secrets/registry.pw)" "registry.${fqdn}"

custom_config="./configure-custom.sh"
[ -x "$custom_config" ] && ./"$custom_config"
