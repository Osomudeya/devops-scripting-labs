"""
Notification Service — Use Case 4: Log Correlation Across Services

Sends payment confirmation emails by calling an email provider API.
The email provider URL and connection timeout are configurable via environment variables.

NORMAL MODE (default EMAIL_PROVIDER_URL and EMAIL_TIMEOUT):
    Calls a local mock endpoint that responds immediately.
    Emits a structured JSON log with trace_id included.
    The correlation script sees the full timeline.

BROKEN MODE (break_it.sh sets EMAIL_TIMEOUT=0.001):
    The httpx call times out immediately on any real network attempt.
    The except block catches TimeoutException and logs a plain-text error
    WITHOUT including the trace_id — exactly as a developer might write
    a bare except block under pressure.
    The error is real. The log line exists. The correlate.py script
    cannot find it because trace_id is missing.

This is how structured logging gaps actually happen in production:
    not a deliberate choice, but an error handler written without thinking
    about observability.
"""

import json
import os
from datetime import datetime, timezone

import httpx
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

LOG_FILE = "/logs/notification.log"

# Configurable via environment variable.
# Normal mode: points to a mock endpoint that responds immediately.
# break_it.sh sets EMAIL_TIMEOUT=0.001 to cause immediate timeouts.
EMAIL_PROVIDER_URL = os.environ.get(
    "EMAIL_PROVIDER_URL",
    "http://localhost:9999/send",
)
EMAIL_TIMEOUT = float(os.environ.get("EMAIL_TIMEOUT", "2.0"))


def emit(trace_id: str, event: str, level: str = "INFO", **kwargs):
    """Structured JSON log — visible to trace correlation."""
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "trace_id": trace_id,
        "service": "notification",
        "event": event,
        "level": level,
        **kwargs,
    }
    line = json.dumps(record)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    print(line, flush=True)


def emit_plain(message: str):
    """
    Plain text log — NOT visible to trace correlation.

    This is what happens when a developer writes a bare except block
    that logs an error message without including the trace_id.
    The line exists in the log file. grep finds it. correlate.py cannot.

    In production this is usually a combination of:
      - Time pressure ("just make it not crash")
      - Missing logging standards or enforcement
      - Error paths that were never tested with tracing enabled
    """
    ts = datetime.now(timezone.utc).isoformat()
    line = f"{ts} ERROR {message}"
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    print(line, flush=True)


class NotifyRequest(BaseModel):
    trace_id: str
    user_id: str
    recipient: str
    amount: float


@app.post("/notify")
async def notify(req: NotifyRequest):
    emit(req.trace_id, "email_send_attempt", recipient=req.recipient)

    try:
        async with httpx.AsyncClient(timeout=EMAIL_TIMEOUT) as client:
            await client.post(
                EMAIL_PROVIDER_URL,
                json={
                    "to": req.recipient,
                    "subject": f"Payment confirmation — ${req.amount:.2f}",
                    "body": f"Your payment of ${req.amount:.2f} was successful.",
                },
            )
        emit(req.trace_id, "email_queued", recipient=req.recipient, amount=req.amount)
        return {"trace_id": req.trace_id, "status": "queued"}

    except httpx.TimeoutException:
        emit_plain(
            f"Connection timeout to email provider {EMAIL_PROVIDER_URL} "
            f"after {EMAIL_TIMEOUT}s — failed to send confirmation to {req.recipient}"
        )
        return {"status": "ok"}

    except Exception as e:
        emit_plain(f"Unexpected error sending email to {req.recipient}: {str(e)}")
        return {"status": "ok"}


@app.get("/healthz")
async def healthz():
    return {
        "status": "ok",
        "service": "notification",
        "email_provider": EMAIL_PROVIDER_URL,
        "timeout": EMAIL_TIMEOUT,
    }
