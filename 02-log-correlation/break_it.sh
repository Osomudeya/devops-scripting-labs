#!/usr/bin/env bash
# break_it.sh — Use Case 4: Log Correlation Across Services
#
# Sets EMAIL_TIMEOUT=0.001 on the notification service via docker compose.
# This causes every httpx call to the email provider to time out immediately.
# The TimeoutException is caught by an error handler that logs plain text
# WITHOUT including the trace_id — the real structured logging gap.
#
# No flag files. No mock toggles. A real httpx timeout on a real code path.

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

OVERRIDE_FILE="./docker-compose.override.yml"

echo "Activating broken mode on the notification service..."
echo "(Setting EMAIL_TIMEOUT=0.001 — all email provider calls timeout immediately)"
echo ""

cat > "$OVERRIDE_FILE" << 'YAML'
services:
  notification:
    environment:
      EMAIL_TIMEOUT: "0.001"
YAML

docker compose up -d --no-deps notification

echo "Waiting for notification service to restart..."
sleep 3

echo "Broken mode active."
echo ""
echo "The notification service will now:"
echo "  - Receive every request normally"
echo "  - Attempt to call the email provider (times out in 0.001s)"
echo "  - Catch TimeoutException in a bare except block"
echo "  - Log a plain-text error WITHOUT the trace_id"
echo ""
echo "Run ./trigger_request.sh for a new trace ID, then:"
echo "  python correlate.py <trace_id>"
echo ""
echo "Notification will be missing from the correlation timeline."
echo "Open logs/notification.log directly to find the plain-text error line."
echo ""
echo "Run ./reset.sh to restore normal behaviour."
