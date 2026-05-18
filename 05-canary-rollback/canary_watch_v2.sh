#!/usr/bin/env bash
# canary_watch_v2.sh — watches error rate AND P99 latency
# See the article for a full explanation of every line.

PROMETHEUS="http://localhost:9090"
DEPLOYMENT="myapp-canary"
NAMESPACE="default"
ERROR_THRESHOLD="0.05"
LATENCY_THRESHOLD="2.0"
CHECK_INTERVAL=15
STRIKE_LIMIT=3

strikes=0

echo "Canary monitor running (v2 — error rate + P99 latency)."
echo "Error threshold: ${ERROR_THRESHOLD} | Latency P99 threshold: ${LATENCY_THRESHOLD}s"
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

    latency_query='histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{app="myapp-canary"}[1m])) by (le))'

    latency=$(curl -sf "${PROMETHEUS}/api/v1/query" \
        --data-urlencode "query=${latency_query}" | \
        python3 -c "
import sys, json
d = json.load(sys.stdin)
result = d['data']['result']
print(result[0]['value'][1] if result else '0')
" 2>/dev/null)

    error_rate=${error_rate:-0}
    latency=${latency:-0}

    error_breach=$(echo "$error_rate > $ERROR_THRESHOLD" | bc -l)
    latency_breach=$(echo "$latency > $LATENCY_THRESHOLD" | bc -l)

    triggered_by=""
    [ "$error_breach" = "1" ] && triggered_by="error_rate(${error_rate})"
    [ "$latency_breach" = "1" ] && triggered_by="${triggered_by:+${triggered_by}, }latency_p99(${latency}s)"

    echo "[$ts] error_rate=${error_rate} | latency_p99=${latency}s | breach=${triggered_by:-none}"

    if [ "$error_breach" = "1" ] || [ "$latency_breach" = "1" ]; then
        strikes=$((strikes + 1))
        echo "  Strike ${strikes}/${STRIKE_LIMIT} | Triggered by: ${triggered_by}"
        if [ "$strikes" -ge "$STRIKE_LIMIT" ]; then
            echo ""
            echo "  ROLLBACK TRIGGERED"
            echo "  Signal: ${triggered_by}"
            echo "  Timestamp: ${ts}"
            echo ""
            kubectl rollout undo deployment/"${DEPLOYMENT}" -n "${NAMESPACE}"
            echo ""
            echo "  Before re-deploying, investigate whether the latency spike was"
            echo "  a genuine regression or a transient condition."
            echo "  Check: kubectl rollout history deployment/${DEPLOYMENT} -n ${NAMESPACE}"
            exit 0
        fi
    else
        strikes=0
    fi

    sleep "${CHECK_INTERVAL}"
done
