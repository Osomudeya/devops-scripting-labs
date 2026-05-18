#!/usr/bin/env bash
# setup.sh — Use Case 5: Automated Canary Rollback Trigger
# Sets up a Kind cluster, installs Prometheus via Helm, and deploys both
# the stable and canary versions of the demo application.
#
# Prerequisites (install these before running):
#   - kind     brew install kind
#   - kubectl  brew install kubectl
#   - helm     brew install helm
#   - docker   docker.com/get-started
#   - bc       brew install bc (on macOS) / apt install bc (on Ubuntu)

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

CLUSTER_NAME="canary-demo"
NAMESPACE="default"

echo "=== Use Case 5: Canary Rollback Demo Setup ==="
echo ""

# --- Step 1: Create Kind cluster ---
echo "[1/6] Creating Kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "  Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
    kind create cluster --name "${CLUSTER_NAME}"
    echo "  Cluster created."
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

# --- Step 2: Build app Docker image ---
echo ""
echo "[2/6] Building app Docker image..."
docker build -t myapp:latest ./app
echo "  Image built: myapp:latest"

# --- Step 3: Load image into Kind ---
# Kind clusters cannot pull from your local Docker registry by default.
# This command copies the image directly into the Kind node's image store.
echo ""
echo "[3/6] Loading image into Kind cluster..."
kind load docker-image myapp:latest --name "${CLUSTER_NAME}"
echo "  Image loaded."

# --- Step 4: Install Prometheus via Helm ---
echo ""
echo "[4/6] Installing Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

if helm status prometheus -n "${NAMESPACE}" &>/dev/null; then
    echo "  Prometheus already installed. Skipping."
else
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace "${NAMESPACE}" \
        --create-namespace \
        -f k8s/prometheus-values.yaml \
        --wait \
        --timeout 5m
    echo "  Prometheus installed."
fi

# --- Step 5: Deploy stable and canary ---
echo ""
echo "[5/6] Deploying stable and canary versions..."
kubectl apply -f k8s/stable-deployment.yaml
kubectl apply -f k8s/canary-deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/service-monitor.yaml
kubectl apply -f k8s/load-generator.yaml

echo "  Waiting for deployments to be ready..."
kubectl rollout status deployment/myapp-stable -n "${NAMESPACE}" --timeout=60s
kubectl rollout status deployment/myapp-canary -n "${NAMESPACE}" --timeout=60s
kubectl rollout status deployment/load-generator -n "${NAMESPACE}" --timeout=60s
echo "  Deployments ready."

# --- Step 6: Port-forward Prometheus ---
echo ""
echo "[6/6] Setting up Prometheus port-forward..."
echo "  Killing any existing port-forward on 9090..."
pkill -f "port-forward.*9090" 2>/dev/null || true
sleep 1

kubectl port-forward svc/prometheus-kube-prometheus-prometheus \
    9090:9090 -n "${NAMESPACE}" &>/tmp/pf-prometheus.log &
PF_PID=$!
sleep 3

if kill -0 "$PF_PID" 2>/dev/null; then
    echo "  Prometheus is available at http://localhost:9090"
else
    echo "  WARNING: Port-forward may have failed. Check /tmp/pf-prometheus.log"
    echo "  Try manually: kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Run the canary monitor (in this terminal):"
echo "  ./canary_watch_v1.sh   (watches error rate only)"
echo "  ./canary_watch_v2.sh   (watches error rate + P99 latency)"
echo ""
echo "In a second terminal, inject the failure:"
echo "  ./break_it.sh"
echo ""
echo "Optional — latency table (port-forward stable/canary to 8081/8082 first):"
echo "  ./check_latency.sh"
echo ""
echo "NOTE: Allow 30-60 seconds after setup before running the watch scripts."
echo "Prometheus needs time to scrape the first metrics from the app pods."
echo "A load-generator pod keeps traffic on both services so scrapes are non-empty."
