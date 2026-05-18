#!/usr/bin/env bash
# trigger_request.sh
# Fires a payment request through the full auth → ledger → notification chain.
# Prints the trace_id so you can pass it straight to correlate.py.

set -e

AUTH_URL="http://localhost:8001"

# Check the auth service is up before firing
if ! curl -sf "${AUTH_URL}/healthz" > /dev/null; then
    echo "ERROR: Auth service is not reachable at ${AUTH_URL}"
    echo "Make sure the services are running: docker compose up -d"
    exit 1
fi

echo "Sending payment request..."

response=$(curl -sf -X POST "${AUTH_URL}/pay" \
    -H "Content-Type: application/json" \
    -d '{
        "user_id": "u_789",
        "amount": 50.00,
        "recipient": "user@example.com"
    }')

if [ $? -ne 0 ]; then
    echo "ERROR: Request failed. Check docker compose logs for details."
    exit 1
fi

trace_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['trace_id'])")
status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")

echo ""
echo "Status:   ${status}"
echo "Trace ID: ${trace_id}"
echo ""
echo "Run the correlation script:"
echo "  python correlate.py ${trace_id}"
