#!/usr/bin/env python3
# detect_drift.py — Use Case 1: Infrastructure Drift Detection
# Full explanation of every function is in the article.
import json
import sys
from pathlib import Path

import boto3
from botocore.exceptions import ClientError


def load_tfstate(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def get_security_groups_from_state(tfstate):
    resources = {}
    for resource in tfstate.get("resources", []):
        if resource["type"] == "aws_security_group":
            for instance in resource.get("instances", []):
                sg_id = instance["attributes"]["id"]
                resources[sg_id] = {
                    "ingress": instance["attributes"].get("ingress", []),
                }
    return resources


def get_security_group_from_aws(sg_id):
    ec2 = boto3.client("ec2")
    response = ec2.describe_security_groups(GroupIds=[sg_id])
    sg = response["SecurityGroups"][0]
    return {"ingress": sg.get("IpPermissions", [])}


def normalize_state_rules(rules):
    normalized = set()
    for rule in rules:
        for cidr in rule.get("cidr_blocks", []):
            fp = rule.get("from_port")
            tp = rule.get("to_port")
            normalized.add(
                (
                    int(fp) if fp is not None else 0,
                    int(tp) if tp is not None else 0,
                    str(rule.get("protocol", "-1")),
                    cidr,
                )
            )
    return normalized


def normalize_aws_rules(rules):
    normalized = set()
    for rule in rules:
        from_port = rule.get("FromPort")
        to_port = rule.get("ToPort")
        protocol = str(rule.get("IpProtocol", "-1"))
        for ip_range in rule.get("IpRanges", []):
            normalized.add(
                (
                    int(from_port) if from_port is not None else 0,
                    int(to_port) if to_port is not None else 0,
                    protocol,
                    ip_range["CidrIp"],
                )
            )
    return normalized


def detect_drift(tfstate_path):
    print(f"Loading Terraform state from: {tfstate_path}")
    tfstate = load_tfstate(tfstate_path)
    state_sgs = get_security_groups_from_state(tfstate)

    if not state_sgs:
        print("No security groups found in state file. Nothing to compare.")
        return

    drift_found = False

    for sg_id, state_data in state_sgs.items():
        print(f"\nChecking: {sg_id}")

        try:
            aws_data = get_security_group_from_aws(sg_id)

        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            if error_code == "InvalidGroup.NotFound":
                drift_found = True
                print("  DRIFT — Resource deleted from AWS but still in state file.")
                print("          Terraform believes this security group exists.")
                print("          It does not. It was deleted manually.")
            else:
                print(f"  ERROR: AWS API returned: {e}")
                print("  Check IAM permissions: ec2:DescribeSecurityGroups is required.")
            continue

        except Exception as e:
            print(f"  ERROR: Could not fetch {sg_id} from AWS — {e}")
            continue

        state_rules = normalize_state_rules(state_data["ingress"])
        aws_rules = normalize_aws_rules(aws_data["ingress"])

        added_in_aws = aws_rules - state_rules
        removed_from_aws = state_rules - aws_rules

        if added_in_aws:
            drift_found = True
            print("  DRIFT — Rules present in AWS but missing from state file:")
            for rule in added_in_aws:
                print(f"    Port {rule[0]}-{rule[1]} | Protocol: {rule[2]} | CIDR: {rule[3]}")

        if removed_from_aws:
            drift_found = True
            print("  DRIFT — Rules in state file but removed from AWS:")
            for rule in removed_from_aws:
                print(f"    Port {rule[0]}-{rule[1]} | Protocol: {rule[2]} | CIDR: {rule[3]}")

        if not added_in_aws and not removed_from_aws:
            print("  OK — No drift detected.")

    print("\n" + "=" * 60)
    if drift_found:
        print("Drift detected. See above for details.")
    else:
        print("No drift detected in monitored resources.")

    print("\nIMPORTANT: This script only checks resources tracked in your state file.")
    print("Resources created manually in AWS without Terraform are invisible to this check.")
    print("A clean output here does not mean your AWS account is clean — it means")
    print("the resources you are watching match what Terraform last recorded.")


if __name__ == "__main__":
    default_path = Path(__file__).resolve().parent / "terraform.tfstate"
    tfstate_path = sys.argv[1] if len(sys.argv) > 1 else str(default_path)
    detect_drift(tfstate_path)
