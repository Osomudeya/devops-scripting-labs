# correlate.py — see the article for full explanation of every function
import json
import os
import sys

SERVICES = ["auth", "ledger", "notification"]
LOG_DIR = "./logs"


def load_logs(log_dir):
    all_lines = []
    for service in SERVICES:
        log_file = os.path.join(log_dir, f"{service}.log")
        if not os.path.exists(log_file):
            print(f"  WARNING: No log file for '{service}' at {log_file}")
            continue
        with open(log_file) as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    parsed = json.loads(line)
                    parsed["_source"] = service
                    all_lines.append(parsed)
                except json.JSONDecodeError:
                    print(f"  WARNING: {service}.log line {line_num} is not structured JSON:")
                    print(f"           {line[:100]}")
                    print(f"           This line will NOT appear in any trace-based search.")
    return all_lines


def correlate(trace_id, all_lines):
    matched = [line for line in all_lines if line.get("trace_id") == trace_id]
    matched.sort(key=lambda x: x.get("timestamp", ""))
    return matched


def find_missing_services(matched):
    services_seen = {line["_source"] for line in matched}
    return [s for s in SERVICES if s not in services_seen]


def print_timeline(trace_id, matched, missing):
    print(f"\n{'=' * 60}")
    print(f"Trace ID: {trace_id}")
    print(f"{'=' * 60}")
    if not matched:
        print("\nNo structured log lines found with this trace ID.")
        print("Either the trace ID is wrong, or no service emitted")
        print("a structured log line for this request.")
        return
    services_count = len({line["_source"] for line in matched})
    print(f"\nTimeline — {len(matched)} events across {services_count} service(s):\n")
    for line in matched:
        ts = line.get("timestamp", "unknown")
        service = line.get("_source", "unknown").upper()
        event = line.get("event", "unknown event")
        level = line.get("level", "INFO")
        extras = {k: v for k, v in line.items()
                  if k not in ("timestamp", "trace_id", "event", "level", "_source")}
        print(f"  [{ts}] [{service}] [{level}] {event}")
        for k, v in extras.items():
            print(f"    {k}: {v}")
    if missing:
        print(f"\n{'=' * 60}")
        print("MISSING TELEMETRY")
        print(f"{'=' * 60}")
        print(f"These services produced no trace-tagged events for trace {trace_id}:\n")
        for s in missing:
            print(f"  - {s}")
        print()
        print("This means one of three things:")
        print("  1. The request never reached this service.")
        print("  2. The service received it but an error path swallowed the trace ID,")
        print("     leaving a plain-text log line that trace correlation cannot find.")
        print("  3. This service's log file was not included in this run.")
        print()
        print("Check the raw log file for a plain-text error line around the same timestamp.")
        print("If one exists, that is your root cause — and a structured logging gap to fix.")


def run(trace_id):
    print(f"Loading logs from {LOG_DIR}/...")
    all_lines = load_logs(LOG_DIR)
    print(f"Loaded {len(all_lines)} structured log lines.\n")
    matched = correlate(trace_id, all_lines)
    missing = find_missing_services(matched)
    print_timeline(trace_id, matched, missing)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python correlate.py <trace_id>")
        print("Example: python correlate.py pay-abc123")
        sys.exit(1)
    run(sys.argv[1])
