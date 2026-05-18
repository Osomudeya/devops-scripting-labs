#!/usr/bin/env bash
# reset.sh — Use Case 5: Automated Canary Rollback Trigger
# Restores the canary deployment to normal after a rollback or latency injection.
# Run this between demo runs so you start from a clean state each time.

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

NAMESPACE="default"

echo "Resetting canary deployment..."
echo ""

# Remove latency injection — kubectl set env is safe to run even if the
# variable is already false or was removed by a rollback
kubectl set env deployment/myapp-canary \
    INJECT_LATENCY=false \
    -n "${NAMESPACE}" 2>/dev/null || true

# Re-apply the original canary manifest in case a rollback changed the spec
kubectl apply -f k8s/canary-deployment.yaml

echo "Waiting for canary to be ready..."
kubectl rollout status deployment/myapp-canary \
    -n "${NAMESPACE}" \
    --timeout=60s

echo ""
echo "Reset complete. Canary is running with INJECT_LATENCY=false."
echo ""
kubectl get pods -n "${NAMESPACE}" -l app=myapp-canary
