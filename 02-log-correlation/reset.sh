#!/usr/bin/env bash
# reset.sh
# Restores normal behaviour and clears the log files for a fresh demo run.
# Run this between demos so old log lines do not appear in new correlations.

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

OVERRIDE_FILE="./docker-compose.override.yml"
LOG_DIR="./logs"

echo "Resetting demo environment..."

if [ -f "$OVERRIDE_FILE" ]; then
    rm "$OVERRIDE_FILE"
    echo "  Removed docker-compose override (EMAIL_TIMEOUT restored)."
    docker compose up -d --no-deps notification
    sleep 2
else
    echo "  No compose override present."
fi

for service in auth ledger notification; do
    log_file="${LOG_DIR}/${service}.log"
    if [ -f "$log_file" ]; then
        : > "$log_file"
        echo "  Cleared ${log_file}"
    fi
done

echo ""
echo "Reset complete. Services are in normal mode."
echo "Run ./trigger_request.sh to start a fresh demo."
