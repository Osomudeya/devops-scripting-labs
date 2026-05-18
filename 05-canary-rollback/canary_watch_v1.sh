#!/usr/bin/env bash
# canary_watch_v1.sh — watches error rate only
# See the article for a full explanation of every line.

PROMETHEUS="http://localhost:9090"
DEPLOYMENT="myapp-canary"
NAMESPACE="default"
ERROR_THRESHOLD="0.05"
CHECK_INTERVAL=15
STRIKE_LIMIT=3

strikes=0

echo "Canary monitor running (v1 — error rate only)."
echo "Rollback triggers if error rate exceeds ${ERROR_THRESHOLD} for ${STRIKE_LIMIT} checks."
echo ""
echo "If Prometheus returns empty results, the port-forward may have dropped."
echo "Restore it: kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""

while true; do
    ts=$(date '+%Y-%m-%dT%H:%M:%S')

    error_query='sum(rate(http_requests_total{app="myapp-canary",status=~"5.."}[1m])) / sum(rate(http_requests_total{app="myapp-canary"}[1m]))'

    error_rate=$(curl -sf "${PROMETHEUS}/api/v1/query" \
        --data-urlencode "query=${error_query}" | \
        python3 -c "
import sys, json
d = json.load(sys.stdin)
result = d['data']['result']
print(result[0]['value'][1] if result else '0')
" 2>/dev/null)

    error_rate=${error_rate:-0}
    above=$(echo "$error_rate > $ERROR_THRESHOLD" | bc -l)

    echo "[$ts] error_rate=${error_rate} | threshold=${ERROR_THRESHOLD} | breach=$([ "$above" = "1" ] && echo YES || echo NO)"

    if [ "$above" = "1" ]; then
        strikes=$((strikes + 1))
        echo "  Strike ${strikes}/${STRIKE_LIMIT}"
        if [ "$strikes" -ge "$STRIKE_LIMIT" ]; then
            echo ""
            echo "  ROLLBACK TRIGGERED — error rate exceeded threshold for ${STRIKE_LIMIT} checks."
            kubectl rollout undo deployment/"${DEPLOYMENT}" -n "${NAMESPACE}"
            exit 0
        fi
    else
        strikes=0
    fi

    sleep "${CHECK_INTERVAL}"
done
