# Use Case 4 — Log Correlation Across Services

Reconstructing the timeline of a failed request across three services using a shared trace ID.

Read the full explanation in the article before running this demo. The article covers:
- What structured logging is and why plain text logs fail in distributed systems
- What a trace ID is and how it connects log lines across services
- Why a missing service in the timeline is itself evidence, not just absence

## What is here

| File | Purpose |
|---|---|
| `correlate.py` | The correlation script from the article |
| `docker-compose.yml` | Wires services + **`mock-email`** (stand-in provider) and a shared log volume |
| `trigger_request.sh` | Fires a payment request and prints the trace ID |
| `break_it.sh` | Writes **`docker-compose.override.yml`** (`EMAIL_TIMEOUT=0.001`) and restarts **notification** |
| `reset.sh` | Removes **`docker-compose.override.yml`**, restarts **notification**, clears logs |
| `services/auth/` | Auth service — generates trace ID, logs authentication |
| `services/ledger/` | Ledger service — records transaction |
| `services/notification/` | Notification — **httpx** to provider URL; broken mode = timeout + plain-text log |
| Compose service **`mock-email`** | **`traefik/whoami`** — answers POST immediately so normal mode completes |

## Prerequisites

- Docker and Docker Compose
- Python 3.8+

## How to run

```bash
# Start all three services
docker compose up -d

# Wait for services to be healthy, then trigger a payment
./trigger_request.sh

# Run the correlation script with the trace ID from the output above
python correlate.py <trace_id>
```

## How to inject the failure

```bash
# Activate broken mode — httpx times out; notification logs plain text without trace_id
./break_it.sh

# Trigger a new request and get a new trace ID
./trigger_request.sh

# Run correlation — notification will be missing from the timeline
python correlate.py <new_trace_id>

# Open the raw log to find the plain-text error line
cat logs/notification.log

# Reset when done
./reset.sh
```

## The lesson

`correlate.py` can only find log lines that include a `trace_id` field. When the notification service hits an error and logs a plain-text line without that field, the correlation script reports the service as missing — even though the error exists in the log file. That is the gap the article builds around: structured logging is a contract, and error paths are where that contract most commonly breaks.
