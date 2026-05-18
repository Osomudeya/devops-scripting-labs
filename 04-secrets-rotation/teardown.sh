#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-default}"

kubectl delete -f "${ROOT}/k8s/service.yaml" --ignore-not-found
kubectl delete -f "${ROOT}/k8s/deployment.yaml" --ignore-not-found
kubectl delete -f "${ROOT}/k8s/secret.yaml" --ignore-not-found
kubectl delete -f "${ROOT}/k8s/postgres.yaml" --ignore-not-found

aws secretsmanager delete-secret \
    --secret-id myapp/db-credentials \
    --force-delete-without-recovery 2>/dev/null || true

echo "Kubernetes resources removed. AWS secret deleted if present."
