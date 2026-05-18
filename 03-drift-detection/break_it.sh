#!/usr/bin/env bash
# break_it.sh — Use Case 1: Infrastructure Drift Detection
#
# Usage:
#   ./break_it.sh              — adds an SSH rule to the tracked SG (visible drift)
#   ./break_it.sh --invisible  — creates a new SG not in the state file (coverage gap)

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

SG_NAME="devops-lab-drift-demo"
INVISIBLE_SG_NAME="devops-lab-hidden-sg"
INVISIBLE_LOG="${ROOT}/invisible_sgs.txt"

SG_ID=$(terraform output -raw security_group_id)

if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    echo "ERROR: Security group '${SG_NAME}' not found."
    echo "Run ./setup.sh first."
    exit 1
fi

if [ "${1}" = "--invisible" ]; then
    echo "Creating a new security group NOT tracked in the state file..."
    echo "(This demonstrates the coverage gap — the script returns clean.)"
    echo ""

    HIDDEN_SG=$(aws ec2 create-security-group \
        --group-name "${INVISIBLE_SG_NAME}-$(date +%s)" \
        --description "Hidden SG - not in Terraform state" \
        --query "GroupId" \
        --output text)

    echo "$HIDDEN_SG" >> "$INVISIBLE_LOG"
    echo "Created hidden security group: ${HIDDEN_SG}"
    echo "It has been logged to ${INVISIBLE_LOG} for teardown.sh to clean up."
    echo ""
    echo "Now run:"
    echo "  python detect_drift.py terraform.tfstate"
    echo ""
    echo "The script returns clean — this SG is invisible to it."
    echo "That is the coverage gap: a clean output does not mean a clean account."

else
    echo "Adding SSH (port 22) inbound rule to ${SG_ID}..."
    echo "(Simulating a manual change made in the AWS console.)"
    echo ""

    aws ec2 authorize-security-group-ingress \
        --group-id "${SG_ID}" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --query "Return" \
        --output text > /dev/null

    echo "Rule added. Now run:"
    echo "  python detect_drift.py terraform.tfstate"
    echo ""
    echo "You should see: DRIFT — Port 22-22 | Protocol: tcp | CIDR: 0.0.0.0/0"
fi
