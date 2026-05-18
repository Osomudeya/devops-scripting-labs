# Lab 05 — Automated canary rollback (Prometheus)

Demo app (**FastAPI** + **Prometheus** metrics): `VERSION` (`stable` | `canary`), `INJECT_LATENCY`, and `/metrics` for scraping. **`setup.sh`** creates a **Kind** cluster, installs **kube-prometheus-stack** with `k8s/prometheus-values.yaml` (empty ServiceMonitor selectors so your `ServiceMonitor` is picked up), deploys **myapp-stable** / **myapp-canary**, applies **`k8s/load-generator.yaml`** (steady `wget` traffic so PromQL is not empty), and port-forwards Prometheus to **localhost:9090**.

## Prerequisites

- Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, `helm`
- `bc` optional (referenced in setup comments)

## Quick start

```bash
cd 05-canary-rollback
./setup.sh
# wait 30–60s for scrapes, then in one terminal:
./canary_watch_v1.sh   # error-rate-only monitor (rolls back after 3 strikes on 5xx rate)
# or:
./canary_watch_v2.sh   # error rate + P99 latency (either signal, 3 consecutive strikes)
# in another terminal:
./break_it.sh          # JSON-patches INJECT_LATENCY=true on canary (latency, not errors)
# restore canary env without re-applying YAML:
./reset.sh
# destroy Kind cluster and stop port-forwards:
./teardown.sh
```

- **`break_it.sh`** — JSON patch **`INJECT_LATENCY=true`** on **`deployment/myapp-canary`** (env index must match manifest order)
- **`reset.sh`** — patches **`INJECT_LATENCY=false`** and waits for rollout
- **`teardown.sh`** — stops port-forwards and deletes the **`canary-demo`** Kind cluster
- **`k8s/service-monitor.yaml`** — scrapes `/metrics` on Services labeled `app: myapp-stable` | `myapp-canary`
- **`k8s/load-generator.yaml`** — **busybox** loop: `wget` stable and canary every 500ms so scrapes stay populated
- **`check_latency.sh`** — starts port-forwards (**8081** / **8082** → service **8080**) and prints stable vs canary latency each second
- **`app/main.py`** — `/`, `/fail` (500s for testing v1), `/metrics`, `/healthz`

Manual checks: `kubectl port-forward svc/myapp-canary 8080:8080` then `curl -s localhost:8080/` and `curl -s localhost:8080/metrics`.
