# Lab 01 — Infrastructure drift detection (AWS)

Creates a real **EC2 security group**, runs terraform apply and writes a real **`terraform.tfstate`** that tracks it, and uses **`detect_drift.py`** to compare state file ingress rules with **live AWS** via **boto3**.

## Prerequisites

- AWS CLI configured (`aws configure`)
- Python 3.10+ and `pip install -r requirements.txt` (installs **boto3**)

## Quick start

```bash
./setup.sh
python detect_drift.py terraform.tfstate   # expect: OK — No drift detected
./break_it.sh
python detect_drift.py terraform.tfstate   # expect: DRIFT — Port 22-22 ...
./break_it.sh --invisible             # optional: coverage gap demo
./teardown.sh
```

## Files

| File | Role |
|------|------|
| `setup.sh` | runs terraform apply, write `terraform.tfstate`, install deps |
| `detect_drift.py` | Compare `terraform.tfstate` ingress vs AWS `describe-security-groups` |
| `break_it.sh` | Add SSH rule, or `--invisible` extra SG |
| `teardown.sh` | `terraform destroy` (SG + VPC), clean hidden SGs |
