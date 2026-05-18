#!/usr/bin/env bash
# setup.sh — Use Case 2: PostgreSQL + asyncpg + AWS Secrets Manager + Kind
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

CLUSTER_NAME="${CLUSTER_NAME:-devops-secrets-lab}"
NAMESPACE="default"
SECRET_NAME="myapp/db-credentials"
INIT_USER="appuser"
INIT_PASS="initial-password"

echo "=== Use Case 2: Secrets rotation lab setup ==="
echo ""

if ! command -v kind &>/dev/null || ! command -v kubectl &>/dev/null || ! command -v docker &>/dev/null; then
    echo "ERROR: Requires docker, kind, and kubectl."
    exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS CLI not configured."
    exit 1
fi

echo "[1/5] Kind cluster..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "  Cluster ${CLUSTER_NAME} exists."
else
    kind create cluster --name "${CLUSTER_NAME}"
fi
kubectl config use-context "kind-${CLUSTER_NAME}"

echo ""
echo "[2/5] Build & load app image..."
docker build -t secrets-demo-app:latest "${ROOT}/app"
kind load docker-image secrets-demo-app:latest --name "${CLUSTER_NAME}"

echo ""
echo "[3/5] AWS Secrets Manager (${SECRET_NAME})..."
INIT_JSON=$(python3 -c "import json; print(json.dumps({'username':'${INIT_USER}','password':'${INIT_PASS}'}))")
if aws secretsmanager describe-secret --secret-id "${SECRET_NAME}" &>/dev/null; then
    aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" --secret-string "${INIT_JSON}"
    echo "  Updated existing secret."
else
    aws secretsmanager create-secret --name "${SECRET_NAME}" --secret-string "${INIT_JSON}"
    echo "  Created secret."
fi

echo ""
echo "[4/5] Apply Kubernetes manifests..."
kubectl apply -f "${ROOT}/k8s/postgres.yaml"
kubectl apply -f "${ROOT}/k8s/secret.yaml"
kubectl apply -f "${ROOT}/k8s/deployment.yaml"
kubectl apply -f "${ROOT}/k8s/service.yaml"

echo ""
echo "[5/5] Wait for rollouts..."
kubectl rollout status deployment/postgres -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/myapp -n "${NAMESPACE}" --timeout=180s

echo ""
echo "=== Setup complete ==="
echo "pip install -r requirements.txt"
echo "  python rotate_secret.py   # full rotation + verify"
echo "  ./break_it.sh             # desync DB vs K8s secret"
echo "  ./load_test.sh            # pool vs fresh /healthz/db"
echo "  ./teardown.sh"
