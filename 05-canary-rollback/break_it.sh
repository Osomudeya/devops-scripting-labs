#!/usr/bin/env bash
# break_it.sh — Use Case 5: Automated Canary Rollback Trigger
#
# Sets INJECT_LATENCY=true on the canary deployment using kubectl set env.
# This triggers a rolling restart of the canary pod.
# Once the new pod is up, every request to the canary takes 5 seconds.
#
# Error rate stays at zero — the requests return 200.
# P99 latency climbs above the 2-second threshold.
#
# canary_watch_v1.sh sees nothing wrong. It only watches errors.
# canary_watch_v2.sh triggers rollback after 3 consecutive latency breaches.

set -e

NAMESPACE="default"

echo "Injecting latency into the canary deployment..."
echo ""

# kubectl set env is order-independent and idempotent.
# It patches only the named variable regardless of its position
# in the env list — no fragile array index required.
kubectl set env deployment/myapp-canary \
    INJECT_LATENCY=true \
    -n "${NAMESPACE}"

echo "Waiting for canary pod to restart with latency injection active..."
kubectl rollout status deployment/myapp-canary \
    -n "${NAMESPACE}" \
    --timeout=60s

echo ""
echo "Latency injection is active."
echo "The canary pod is Running and passing its readiness probe."
echo "Every request to the canary now takes 5 seconds."
echo "Error rate: 0%   |   P99 latency: ~5s"
echo ""
echo "Switch to the terminal running the watch script and observe:"
echo "  canary_watch_v1.sh — stays silent (watches errors only)"
echo "  canary_watch_v2.sh — triggers rollback after 3 consecutive latency breaches"
echo ""
echo "Run ./reset.sh to restore the canary to normal behaviour."
