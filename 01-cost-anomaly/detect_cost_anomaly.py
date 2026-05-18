#!/usr/bin/env python3
# detect_cost_anomaly.py — Use Case 3: Cost Anomaly Detection
# Full explanation of every function is in the article.

import statistics
import sys
from datetime import datetime, timedelta

import boto3

def build_sample_data(days=30):
    """Synthetic Cost Explorer rows for the last `days` (ending yesterday).

    The EC2 spike is placed on yesterday (device local date) so sample output
    always matches the same window as live Cost Explorer mode.
    """
    last_day = datetime.today().date() - timedelta(days=1)
    first_day = last_day - timedelta(days=days - 1)
    anomaly_day_index = days - 1
    results = []
    for i in range(days):
        day = first_day + timedelta(days=i)
        d = i + 1
        results.append(
            {
                "TimePeriod": {
                    "Start": str(day),
                    "End": str(day + timedelta(days=1)),
                },
                "Groups": [
                    {
                        "Keys": ["Amazon EC2"],
                        "Metrics": {
                            "UnblendedCost": {
                                "Amount": str(
                                    round(
                                        18.50
                                        if i == anomaly_day_index
                                        else 1.10 + (d % 3) * 0.10,
                                        2,
                                    )
                                )
                            }
                        },
                    },
                    {
                        "Keys": ["Amazon S3"],
                        "Metrics": {
                            "UnblendedCost": {
                                "Amount": str(round(0.04 + (d % 5) * 0.01, 2))
                            }
                        },
                    },
                    {
                        "Keys": ["Amazon RDS"],
                        "Metrics": {
                            "UnblendedCost": {
                                "Amount": str(round(0.85 + (d % 4) * 0.05, 2))
                            }
                        },
                    },
                ],
            }
        )
    return results, str(last_day)


def get_daily_costs(days=30):
    ce = boto3.client("ce", region_name="us-east-1")
    end = datetime.today().date() - timedelta(days=1)
    start = end - timedelta(days=days)
    response = ce.get_cost_and_usage(
        TimePeriod={"Start": str(start), "End": str(end)},
        Granularity="DAILY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )
    return response["ResultsByTime"]


def build_service_timeseries(results):
    services = {}
    for day in results:
        date_str = day["TimePeriod"]["Start"]
        for group in day["Groups"]:
            service = group["Keys"][0]
            cost = float(group["Metrics"]["UnblendedCost"]["Amount"])
            if service not in services:
                services[service] = []
            services[service].append({"date": date_str, "cost": cost})
    return services


def detect_anomalies(services, baseline_days=7, multiplier=2.0, recent_days=None):
    """Flag days where cost exceeds prior `baseline_days` average + 2σ.

    Uses a rolling baseline (each day vs the previous week). If `recent_days`
    is set, only returns anomalies on or after today - recent_days.
    """
    cutoff = None
    if recent_days is not None:
        cutoff = datetime.today().date() - timedelta(days=recent_days)

    anomalies = []
    for service, daily in services.items():
        if len(daily) < baseline_days + 1:
            continue
        for i in range(baseline_days, len(daily)):
            day = daily[i]
            day_date = datetime.strptime(day["date"], "%Y-%m-%d").date()
            if cutoff is not None and day_date < cutoff:
                continue
            baseline_costs = [d["cost"] for d in daily[i - baseline_days : i]]
            avg = statistics.mean(baseline_costs)
            if avg < 0.01:
                continue
            try:
                std = statistics.stdev(baseline_costs)
            except statistics.StatisticsError:
                continue
            threshold = avg + (multiplier * std)
            if day["cost"] > threshold:
                anomalies.append(
                    {
                        "service": service,
                        "date": day["date"],
                        "actual": round(day["cost"], 4),
                        "baseline_avg": round(avg, 4),
                        "threshold": round(threshold, 4),
                        "pct_above": round(((day["cost"] - avg) / avg) * 100, 1),
                    }
                )
    return sorted(anomalies, key=lambda x: x["date"])


def parse_args(argv):
    use_sample = "--sample" in argv
    recent_days = None
    for arg in argv[1:]:
        if arg.startswith("--recent-days="):
            recent_days = int(arg.split("=", 1)[1])
    return use_sample, recent_days


def run(use_sample=False, recent_days=None):
    if use_sample:
        results, anomaly_date = build_sample_data()
        print("Running against sample data (--sample mode).")
        print(
            f"This data represents 30 days of billing ending yesterday, "
            f"with a realistic EC2 anomaly on {anomaly_date}.\n"
        )
    else:
        print("Fetching 30 days of daily AWS costs by service...")
        print("Note: today is excluded — Cost Explorer has a 24-hour billing lag.\n")
        results = get_daily_costs(days=30)

    if recent_days is not None:
        since = datetime.today().date() - timedelta(days=recent_days)
        print(
            f"Checking for spikes in the last {recent_days} days only "
            f"(on or after {since}), each vs its prior 7-day average.\n"
        )

    services = build_service_timeseries(results)
    anomalies = detect_anomalies(services, recent_days=recent_days)

    if not anomalies:
        print("No anomalies detected.")
        print("\nNote: this script flags statistical outliers against your own baseline.")
        print("A consistently elevated spend level will not trigger — only sudden increases.")
        return

    print(f"{'=' * 60}")
    print(f"ANOMALIES DETECTED: {len(anomalies)}")
    print(f"{'=' * 60}\n")

    for a in anomalies:
        print(f"Service:      {a['service']}")
        print(f"Date:         {a['date']}")
        print(f"Actual cost:  ${a['actual']}")
        print(f"Baseline avg: ${a['baseline_avg']} (prior 7-day average)")
        print(f"Threshold:    ${a['threshold']}")
        print(f"Overage:      {a['pct_above']}% above baseline")
        print()

    print("=" * 60)
    print("A note on AWS cost attribution:")
    print("The service label in Cost Explorer is assigned by AWS, not by the resource")
    print("that caused the cost. An EC2 spike may be caused by EBS snapshot copies,")
    print("cross-region data transfer, or autoscaling events that AWS categorizes under")
    print("EC2 in billing — not a running EC2 instance you can find in the console.")
    print()
    print("Before investigating the flagged service directly, ask:")
    print("What changed in my infrastructure on or before the flagged date?")
    print("Work backward from the operational change, not forward from the billing label.")


if __name__ == "__main__":
    use_sample, recent_days = parse_args(sys.argv)
    run(use_sample=use_sample, recent_days=recent_days)
