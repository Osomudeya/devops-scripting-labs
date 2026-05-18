"""
Demo application — Use Case 5: Automated Canary Rollback Trigger

Two environment variables control this app's behaviour:

  VERSION         stable | canary   — shown in responses, used in Prometheus labels
  INJECT_LATENCY  false  | true     — when true, adds a configurable sleep to every
                                      request, simulating a slow database query or
                                      external API timeout in the canary version

break_it.sh patches the canary Deployment to set INJECT_LATENCY=true.
This triggers a rolling restart of canary pods. Latency climbs. Error rate stays zero.
canary_watch_v1.sh stays silent. canary_watch_v2.sh catches it and rolls back.

The app exposes /metrics in Prometheus text format.
Prometheus scrapes this endpoint on the interval set in prometheus-values.yaml.
"""

import os
import time

from fastapi import FastAPI, Response
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

app = FastAPI()

VERSION = os.environ.get("VERSION", "stable")
INJECT_LATENCY = os.environ.get("INJECT_LATENCY", "false").lower() == "true"
LATENCY_SECONDS = float(os.environ.get("LATENCY_SECONDS", "5.0"))

# Prometheus metrics
# Using the app label to match the PromQL queries in the watch scripts:
#   http_requests_total{app="myapp-canary"}
#   http_request_duration_seconds_bucket{app="myapp-canary"}
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["app", "version", "status"],
)

REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["app", "version"],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0],
)

APP_LABEL = f"myapp-{VERSION}"


@app.get("/")
async def root():
    start = time.time()

    if INJECT_LATENCY:
        # Simulates a slow downstream call — returns 200 but takes LATENCY_SECONDS.
        # canary_watch_v1.sh watches errors only — this does not trigger it.
        # canary_watch_v2.sh watches P99 latency — this does trigger it.
        time.sleep(LATENCY_SECONDS)

    duration = time.time() - start

    REQUEST_COUNT.labels(app=APP_LABEL, version=VERSION, status="200").inc()
    REQUEST_DURATION.labels(app=APP_LABEL, version=VERSION).observe(duration)

    return {
        "version": VERSION,
        "inject_latency": INJECT_LATENCY,
        "duration_seconds": round(duration, 3),
    }


@app.get("/fail")
async def fail():
    """
    Returns a 500 for manual error rate testing.
    Not used by break_it.sh — that injects latency, not errors.
    Useful for verifying v1 rollback behaviour separately.
    """
    start = time.time()
    duration = time.time() - start

    REQUEST_COUNT.labels(app=APP_LABEL, version=VERSION, status="500").inc()
    REQUEST_DURATION.labels(app=APP_LABEL, version=VERSION).observe(duration)

    return Response(
        content='{"error": "injected failure"}',
        status_code=500,
        media_type="application/json",
    )


@app.get("/metrics")
async def metrics():
    """
    Prometheus scrapes this endpoint on the interval configured in
    prometheus-values.yaml (default: 15 seconds).
    The ServiceMonitor in k8s/service-monitor.yaml tells Prometheus
    where to find this endpoint.
    """
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )


@app.get("/healthz")
async def healthz():
    return {"status": "ok", "version": VERSION}
