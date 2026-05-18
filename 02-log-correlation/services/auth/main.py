"""
Auth Service — Use Case 4: Log Correlation Across Services
Receives payment requests, generates a trace ID, authenticates the user,
then passes the request to the ledger service.
"""

import json
import os
import uuid
from datetime import datetime, timezone

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

LOG_FILE = "/logs/auth.log"
LEDGER_URL = os.environ.get("LEDGER_URL", "http://ledger:8002")


def emit(trace_id: str, event: str, level: str = "INFO", **kwargs):
    """
    Write a structured JSON log line to the log file and stdout.
    Every field must be consistent across all three services so
    the correlation script can parse and group them by trace_id.
    """
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "trace_id": trace_id,
        "service": "auth",
        "event": event,
        "level": level,
        **kwargs,
    }
    line = json.dumps(record)

    # Write to the shared log file the correlate.py script reads from
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")

    # Also print to stdout so docker compose logs shows activity
    print(line, flush=True)


class PaymentRequest(BaseModel):
    user_id: str
    amount: float
    recipient: str


@app.post("/pay")
async def pay(req: PaymentRequest):
    """
    Entry point for a payment request. Generates the trace ID here —
    this is the identifier that stitches all downstream log lines together.
    """
    trace_id = f"pay-{uuid.uuid4().hex[:8]}"

    emit(trace_id, "payment_request_received", user_id=req.user_id, amount=req.amount)

    # Simulate authentication check
    if not req.user_id or len(req.user_id) < 3:
        emit(trace_id, "authentication_failed", level="ERROR", reason="invalid_user_id")
        raise HTTPException(status_code=401, detail="Authentication failed")

    emit(trace_id, "user_authenticated", user_id=req.user_id, duration_ms=12)

    # Forward to ledger service, passing trace_id in the request body
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(
                f"{LEDGER_URL}/record",
                json={
                    "trace_id": trace_id,
                    "user_id": req.user_id,
                    "amount": req.amount,
                    "recipient": req.recipient,
                },
            )
            response.raise_for_status()
    except httpx.RequestError as e:
        emit(trace_id, "ledger_call_failed", level="ERROR", error=str(e))
        raise HTTPException(status_code=502, detail="Ledger service unreachable") from e
    except httpx.HTTPStatusError as e:
        emit(trace_id, "ledger_returned_error", level="ERROR", status=e.response.status_code)
        raise HTTPException(status_code=502, detail="Ledger service error") from e

    emit(trace_id, "payment_complete", user_id=req.user_id, amount=req.amount)

    return {"trace_id": trace_id, "status": "success"}


@app.get("/healthz")
async def healthz():
    return {"status": "ok", "service": "auth"}
