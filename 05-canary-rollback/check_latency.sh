#!/usr/bin/env bash
# check_latency.sh — Shows stable vs canary response times side by side.
# Sets up its own port-forwards automatically.

set -e

NAMESPACE="default"
STABLE_PORT=8081
CANARY_PORT=8082
# Service port is 8080 (see k8s/service.yaml), not 80.
SERVICE_PORT=8080
INTERVAL="${1:-1}"

STABLE_PF=""
CANARY_PF=""

cleanup() {
    [[ -n "${STABLE_PF}" ]] && kill "${STABLE_PF}" 2>/dev/null || true
    [[ -n "${CANARY_PF}" ]] && kill "${CANARY_PF}" 2>/dev/null || true
}
trap cleanup EXIT

echo "Setting up port-forwards (local ${STABLE_PORT}/${CANARY_PORT} → svc ${SERVICE_PORT})..."
kubectl port-forward svc/myapp-stable "${STABLE_PORT}:${SERVICE_PORT}" -n "${NAMESPACE}" \
    &>/tmp/pf-stable.log & STABLE_PF=$!
kubectl port-forward svc/myapp-canary "${CANARY_PORT}:${SERVICE_PORT}" -n "${NAMESPACE}" \
    &>/tmp/pf-canary.log & CANARY_PF=$!
sleep 2

echo "Polling every ${INTERVAL}s. Press Ctrl+C to stop."
echo ""
printf "%-26s  %-12s  %-12s  %s\n" "TIMESTAMP" "STABLE (ms)" "CANARY (ms)" "STATUS"
printf "%-26s  %-12s  %-12s  %s\n" "---------" "-----------" "-----------" "------"

while true; do
    ts=$(date '+%Y-%m-%dT%H:%M:%S')

    stable_ms=$(curl -sf --max-time 10 -o /dev/null \
        -w "%{time_total}" "http://localhost:${STABLE_PORT}/" 2>/dev/null | \
        awk '{printf "%.0f", $1 * 1000}' || echo "ERR")

    canary_ms=$(curl -sf --max-time 10 -o /dev/null \
        -w "%{time_total}" "http://localhost:${CANARY_PORT}/" 2>/dev/null | \
        awk '{printf "%.0f", $1 * 1000}' || echo "ERR")

    status="OK"
    if [ "$canary_ms" != "ERR" ] && [ "$canary_ms" -gt 2000 ] 2>/dev/null; then
        status="CANARY DEGRADED"
    fi

    printf "%-26s  %-12s  %-12s  %s\n" "$ts" "${stable_ms}ms" "${canary_ms}ms" "$status"
    sleep "$INTERVAL"
done
