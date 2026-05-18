# Lab 03 — Cost anomaly detection (AWS Cost Explorer)

Uses **AWS Cost Explorer** (`ce:GetCostAndUsage`) with **boto3**. Run with **`--sample`** for built-in demo data (no AWS call), or without the flag against your account (requires `ce:GetCostAndUsage`).

## Prerequisites

- Python 3.10+, `pip install -r requirements.txt` (**boto3**)
- AWS CLI configured; IAM permission **`ce:GetCostAndUsage`**

## Usage

```bash
pip install -r requirements.txt
python detect_cost_anomaly.py --sample
python detect_cost_anomaly.py   # live — excludes today (billing lag)
```

See **`ARTICLE.md`** / root README for how to read anomalies and cost attribution caveats.
