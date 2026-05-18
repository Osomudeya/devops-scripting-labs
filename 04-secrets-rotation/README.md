# Use Case 2 — Secrets Rotation with Zero Downtime

Rotates a database credential end-to-end: AWS Secrets Manager, PostgreSQL (ALTER USER), Kubernetes Secret, rolling restart, and verification that the new credential actually works at the application level — not just that the pod is Running.

Read the full explanation in the article before running this demo.

## Prerequisites

- Docker, **kind**, **kubectl**, AWS CLI configured with `secretsmanager:GetSecretValue` and `secretsmanager:PutSecretValue`
- Python 3.8+ (use a venv per lab folder)
- `pip install -r requirements.txt` (**boto3**, **kubernetes**)

## How to run

```bash
./setup.sh                 # creates Kind cluster, deploys PostgreSQL and app
python rotate_secret.py    # happy path — all 6 steps complete and verify
```

## How to break it

```bash
./break_it.sh              # changes PostgreSQL password directly via ALTER USER
                           # now DB and K8s Secret are out of sync

# See the gap yourself before running rotation:
kubectl exec deployment/myapp -- curl -s http://localhost:8000/healthz
# → 200 (readiness probe would pass)

kubectl exec deployment/myapp -- curl -s http://localhost:8000/healthz/db
# → 503 (fresh connection fails — credential mismatch)

./load_test.sh             # 10 concurrent requests to /query and /healthz/db
                           # pool connections may succeed, fresh connections fail

python rotate_secret.py    # rotation + verify (repairs end-to-end when healthy)
```

## Teardown

```bash
./teardown.sh
```

## What each file does

| File | Purpose |
|---|---|
| `rotate_secret.py` | The rotation script — 6 steps, ALTER USER included |
| `app/main.py` | FastAPI app with `/healthz`, `/healthz/db`, and `/query` |
| `k8s/postgres.yaml` | Real PostgreSQL 15 with appuser initialization |
| `k8s/deployment.yaml` | The application deployment |
| `k8s/secret.yaml` | Initial Kubernetes Secret |
| `k8s/service.yaml` | Services for app and postgres |
| `break_it.sh` | Changes PostgreSQL password directly |
| `load_test.sh` | Concurrent requests showing mixed pool/fresh behaviour |
| `setup.sh` | Full environment setup |
| `teardown.sh` | Cleanup |

## The lesson

`/healthz` returns 200 as long as the HTTP server is alive.
`/healthz/db` opens a fresh asyncpg connection and runs SELECT 1.
These are two different contracts. Kubernetes only validates the first one.
`rotate_secret.py` validates the second — and catches what the readiness probe misses.
