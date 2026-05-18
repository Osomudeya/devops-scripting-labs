#!/usr/bin/env bash
# setup.sh — Use Case 1: Infrastructure Drift Detection
#
# Provisions the demo security group with Terraform and writes terraform.tfstate.

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

echo "=== Use Case 3: Infrastructure Drift Detection Setup ==="
echo ""

if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS CLI is not configured or credentials are invalid."
    echo "Run: aws configure"
    exit 1
fi

if ! command -v terraform &>/dev/null; then
    echo "ERROR: Terraform is not installed."
    echo "Run: brew install terraform"
    exit 1
fi

echo "[1/2] Running terraform init and apply..."
terraform init -input=false
terraform apply -auto-approve -input=false

echo ""
echo "[2/2] Installing Python dependencies..."
python3 -m pip install -r requirements.txt -q

echo ""
echo "=== Setup complete ==="
echo ""
echo "Run the script to confirm everything is in sync:"
echo "  python detect_drift.py terraform.tfstate"
echo ""
echo "You should see: OK — No drift detected"
echo ""
echo "Then inject drift:"
echo "  ./break_it.sh"
echo "  python detect_drift.py terraform.tfstate"
echo ""
echo "When finished:"
echo "  ./teardown.sh"
