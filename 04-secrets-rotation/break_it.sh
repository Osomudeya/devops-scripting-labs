#!/usr/bin/env bash
# break_it.sh — Use Case 2: Secrets Rotation with Zero Downtime
#
# Changes the PostgreSQL appuser password directly, simulating
# a state where the database and Kubernetes Secret are out of sync.
#
# After running this:
#   - The app's connection pool holds sessions authenticated with the old password
#   - Those pool connections still work (existing authenticated sessions)
#   - New connections (like /healthz/db) fail — they use the old K8s Secret password
#     which no longer matches the database
#   - kubectl get pods shows Running
#   - /healthz returns 200
#   - /healthz/db returns 503
#
# That is the real contract gap the article describes.
# Run: python rotate_secret.py to see the verification catch it.

set -e

NAMESPACE="${NAMESPACE:-default}"
# Hex only so the value is safe inside single-quoted SQL and the shell.
BROKEN_PASSWORD="broken-$(openssl rand -hex 16)"

echo "Changing PostgreSQL appuser password directly..."
echo "(Simulating the database being ahead of the Kubernetes Secret)"
echo ""

kubectl exec deployment/postgres \
    -n "${NAMESPACE}" \
    -- env "PGPASSWORD=postgres-admin" psql -U postgres -d appdb \
    -c "ALTER USER appuser PASSWORD '${BROKEN_PASSWORD}';"

echo ""
echo "Done. The database now requires a password that the application does not have."
echo ""
echo "Verify the gap yourself:"
echo "  kubectl exec deployment/myapp -n ${NAMESPACE} -- curl -s http://localhost:8000/healthz"
echo "  → 200 (readiness probe would pass)"
echo ""
echo "  kubectl exec deployment/myapp -n ${NAMESPACE} -- curl -s http://localhost:8000/healthz/db"
echo "  → 503 (fresh connection fails — credential mismatch)"
echo ""
echo "Now run the rotation script to fix it:"
echo "  python rotate_secret.py"
