#!/usr/bin/env bash
# teardown.sh — Use Case 1: Infrastructure Drift Detection

set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

SG_NAME="devops-lab-drift-demo"
VPC_TAG="devops-lab-drift-demo"

if [ -f "${ROOT}/invisible_sgs.txt" ]; then
    while IFS= read -r hid; do
        [ -z "$hid" ] && continue
        aws ec2 delete-security-group --group-id "$hid" 2>/dev/null && echo "Deleted hidden SG ${hid}" || true
    done < "${ROOT}/invisible_sgs.txt"
    rm -f "${ROOT}/invisible_sgs.txt"
fi

if command -v terraform &>/dev/null && [ -f "${ROOT}/main.tf" ]; then
    terraform init -input=false >/dev/null
    if [ -f "${ROOT}/terraform.tfstate" ]; then
        echo "Running terraform destroy (security group + VPC)..."
        terraform destroy -auto-approve -input=false
        echo "Destroyed Terraform-managed resources."
    fi
fi

# Fallback if state is missing or destroy left orphans
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SG_NAME}" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null \
        && echo "Deleted security group ${SG_ID}" \
        || echo "Could not delete security group ${SG_ID}"
fi

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${VPC_TAG}" \
    --query "Vpcs[0].VpcId" \
    --output text 2>/dev/null || echo "None")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null \
        && echo "Deleted VPC ${VPC_ID}" \
        || echo "Could not delete VPC ${VPC_ID} (check for remaining ENIs or dependencies)"
fi

echo "Teardown complete."
