#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name="${KIND_CLUSTER_NAME:-eks-cicd-local}"

command -v docker >/dev/null || { echo "Docker is required. Start Docker Desktop and retry." >&2; exit 1; }
command -v kind >/dev/null || { echo "kind is required. Install it with: brew install kind" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required. Install it with: brew install kubectl" >&2; exit 1; }

case "${1:-up}" in
  up)
    if ! kind get clusters | grep -qx "$cluster_name"; then
      kind create cluster --name "$cluster_name" --config "$root_dir/kind-config.yaml"
    fi
    kubectl config use-context "kind-$cluster_name"
    kubectl apply -f "$root_dir/manifest/namespace.yaml"
    kubectl apply -n eks-nginx-app -f "$root_dir/manifest/site.yaml" -f "$root_dir/manifest/deployment.yaml" -f "$root_dir/manifest/service.yaml"
    kubectl rollout status deployment/nginx -n eks-nginx-app --timeout=5m
    kubectl get pods,service -n eks-nginx-app
    echo "Run './scripts/local-kubernetes.sh port-forward' and open http://localhost:8080"
    ;;
  port-forward)
    kubectl --context "kind-$cluster_name" port-forward -n eks-nginx-app service/nginx 8080:80
    ;;
  down)
    kind delete cluster --name "$cluster_name"
    ;;
  *)
    echo "Usage: $0 {up|port-forward|down}" >&2
    exit 2
    ;;
esac
