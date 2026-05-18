#!/usr/bin/env bash
# teardown.sh — Use Case 5: Automated Canary Rollback Trigger
#
# Stops port-forwards and deletes the Kind cluster created by setup.sh.

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

CLUSTER_NAME="${CLUSTER_NAME:-canary-demo}"
NAMESPACE="${NAMESPACE:-default}"

echo "=== Use Case 5: Canary Rollback Demo Teardown ==="
echo ""

echo "Stopping port-forwards..."
pkill -f "port-forward.*9090" 2>/dev/null || true
pkill -f "port-forward.*8081" 2>/dev/null || true
pkill -f "port-forward.*8082" 2>/dev/null || true

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    if command -v kubectl &>/dev/null; then
        kubectl config use-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
        if command -v helm &>/dev/null && helm status prometheus -n "${NAMESPACE}" &>/dev/null; then
            echo "Uninstalling Helm release prometheus..."
            helm uninstall prometheus -n "${NAMESPACE}" 2>/dev/null || true
        fi
    fi

    echo "Deleting Kind cluster '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"
    echo "  Cluster deleted."
else
    echo "  Kind cluster '${CLUSTER_NAME}' not found. Nothing to delete."
fi

echo ""
echo "Teardown complete."
