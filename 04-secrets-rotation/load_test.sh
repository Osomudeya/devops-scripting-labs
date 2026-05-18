#!/usr/bin/env bash
# load_test.sh — UC2: Shows mixed success/failure after break_it.sh
# Run AFTER ./break_it.sh and BEFORE python rotate_secret.py.
# Uses concurrent requests to force new pool connections to open.

set -e

NAMESPACE="${NAMESPACE:-default}"
CONCURRENCY=10

POD=$(kubectl get pods -n "${NAMESPACE}" -l app=myapp \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD" ]; then
    echo "ERROR: No myapp pod found. Run ./setup.sh first."
    exit 1
fi

echo "Pod: ${POD}"
echo "Sending ${CONCURRENCY} concurrent requests to /query and /healthz/db..."
echo ""

pool_results=$(seq 1 "$CONCURRENCY" | xargs -P "$CONCURRENCY" -I{} \
    kubectl exec "${POD}" -n "${NAMESPACE}" -- \
    curl -sf -o /dev/null -w "%{http_code}\n" \
    http://localhost:8000/query 2>/dev/null) || true

fresh_results=$(seq 1 "$CONCURRENCY" | xargs -P "$CONCURRENCY" -I{} \
    kubectl exec "${POD}" -n "${NAMESPACE}" -- \
    curl -sf -o /dev/null -w "%{http_code}\n" \
    http://localhost:8000/healthz/db 2>/dev/null) || true

pool_ok=$(echo "$pool_results" | grep -c "^200$" || true)
pool_fail=$((CONCURRENCY - pool_ok))
fresh_ok=$(echo "$fresh_results" | grep -c "^200$" || true)
fresh_fail=$((CONCURRENCY - fresh_ok))

echo "Results (${CONCURRENCY} concurrent requests each):"
echo ""
echo "  /query        (pool connections — authenticated before rotation):"
echo "    200 OK:  ${pool_ok}/${CONCURRENCY}   Failures: ${pool_fail}/${CONCURRENCY}"
echo ""
echo "  /healthz/db   (fresh connection — current environment credential):"
echo "    200 OK:  ${fresh_ok}/${CONCURRENCY}   Failures: ${fresh_fail}/${CONCURRENCY}"
echo ""

if [ "$fresh_fail" -gt 0 ]; then
    echo "Contract gap confirmed:"
    echo "  Pool connections still work — old sessions, authenticated before the password changed."
    echo "  Fresh connections fail — the environment credential no longer matches the database."
    echo "  kubectl get pods shows Running. Readiness probe passed."
    echo ""
    echo "Run: python rotate_secret.py to fix all of this in the correct order."
fi
