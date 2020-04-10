#!/usr/bin/env bash
set -xeuo pipefail

longhorn_ver="v0.8.0"
longhorn_manifest_url="https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_ver}/deploy/longhorn.yaml"

argo_workflows_ver="v2.7.1"
argo_workflows_manifest_url="https://raw.githubusercontent.com/argoproj/argo/${argo_workflows_ver}/manifests/install.yaml"

argo_cd_ver="v1.5.1"
argo_cd_manifest_url="kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${argo_cd_ver}/manifests/install.yaml"

# longhorn
kubectl apply -f "$longhorn_manifest_url"
longhorn_cert="secrets/longhorn-cert.yaml"
[ -f "$longhorn_cert" ] && kubectl apply -f "$longhorn_cert"
kubectl apply -f manifests/longhorn-ingress-storageclass.yaml

# docker registry
kubectl create namespace docker-registry
docker_registry_cert="secrets/docker-registry-cert.yaml"
[ -f "$docker_registry_cert" ] && kubectl apply -f "$docker_registry_cert"
kubectl apply -f manifests/docker-registry.yaml

TODO docker regcred setup

# prometheus
kubectl create namespace prometheus
prometheus_cert="secrets/prometheus-cert.yaml"
[ -f "$prometheus_cert" ] && kubectl apply -f "$prometheus_cert"
kubectl apply -f manifests/prometheus.yaml

# argo workflows
kubectl create namespace argo
kubectl apply -n argo -f "$argo_workflows_manifest_url"
argo_cert="secrets/argo-cert.yaml"
[ -f "$argo_cert" ] && kubectl apply -f "$argo_cert"
kubectl apply -f manifests/argo-ingress.yaml

# argo cd
kubectl create namespace argocd
kubectl apply -n argocd -f "$argo_cd_manifest_url"
# use argo in open mode
kubectl patch deploy -n argocd argocd-server --type json \
	-p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--disable-auth"}]'
argocd_cert="secrets/argocd-cert.yaml"
[ -f "$argocd_cert" ] && kubectl apply -f "$argocd_cert"
kubectl apply -f manifests/argocd-ingress.yaml
