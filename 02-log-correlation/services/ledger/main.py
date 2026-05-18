"""
Ledger Service — Use Case 4: Log Correlation Across Services
Records the transaction and passes the notification request downstream.
"""

import json
import os
from datetime import datetime, timezone

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

LOG_FILE = "/logs/ledger.log"
NOTIFICATION_URL = os.environ.get("NOTIFICATION_URL", "http://notification:8003")


def emit(trace_id: str, event: str, level: str = "INFO", **kwargs):
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "trace_id": trace_id,
        "service": "ledger",
        "event": event,
        "level": level,
        **kwargs,
    }
    line = json.dumps(record)

    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")

    print(line, flush=True)


class RecordRequest(BaseModel):
    trace_id: str
    user_id: str
    amount: float
    recipient: str


@app.post("/record")
async def record(req: RecordRequest):
    emit(
        req.trace_id,
        "transaction_recorded",
        user_id=req.user_id,
        amount=req.amount,
        currency="USD",
    )

    # Forward to notification service
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(
                f"{NOTIFICATION_URL}/notify",
                json={
                    "trace_id": req.trace_id,
                    "user_id": req.user_id,
                    "recipient": req.recipient,
                    "amount": req.amount,
                },
            )
            response.raise_for_status()
    except httpx.RequestError as e:
        emit(req.trace_id, "notification_call_failed", level="ERROR", error=str(e))
        raise HTTPException(status_code=502, detail="Notification service unreachable") from e
    except httpx.HTTPStatusError as e:
        emit(req.trace_id, "notification_returned_error", level="ERROR", status=e.response.status_code)
        raise HTTPException(status_code=502, detail="Notification service error") from e

    return {"trace_id": req.trace_id, "status": "recorded"}


@app.get("/healthz")
async def healthz():
    return {"status": "ok", "service": "ledger"}
