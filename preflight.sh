#!/usr/bin/env bash
# preflight.sh
# Checks every prerequisite for all five use cases before you run any setup script.
# Run this first. Fix everything it flags. Then run the individual setup scripts.

PASS=0
FAIL=0

check() {
    local name=$1
    local cmd=$2
    local hint=$3

    if eval "$cmd" &>/dev/null; then
        printf "  %-20s  OK\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "  %-20s  MISSING  →  %s\n" "$name" "$hint"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== DevOps Scripting Labs — Preflight Check ==="
echo ""

echo "Core tools:"
check "python3"     "python3 --version"          "Install from python.org"
check "pip"         "python3 -m pip --version"   "python3 -m ensurepip --upgrade  or  brew install python"
check "docker"      "docker info"                "Install from docker.com"
check "git"         "git --version"              "brew install git / apt install git"
check "terraform"    "terraform version"    "brew install terraform"

echo ""
echo "AWS (use cases 1, 2, 3):"
check "aws CLI"     "aws --version"              "brew install awscli / pip install awscli"
check "aws auth"    "aws sts get-caller-identity" "Run: aws configure"

echo ""
echo "Kubernetes (use cases 2, 5):"
check "kind"        "kind version"               "brew install kind  /  go install sigs.k8s.io/kind@latest"
check "kubectl"     "kubectl version --client"   "brew install kubectl"
check "helm"        "helm version"               "brew install helm"

echo ""
echo "Docker Compose (use case 4):"
check "docker compose" "docker compose version"  "Included with Docker Desktop"

echo ""
echo "Utilities (use case 5):"
check "bc"          "bc --version"               "brew install bc  /  apt install bc"

echo ""
echo "Python packages (checked globally — use a venv in each folder):"
check "boto3"       "python3 -c 'import boto3'"  "pip install boto3"

echo ""
echo "========================================"
echo "Passed: ${PASS}   Failed: ${FAIL}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "All prerequisites met. You are ready to run any use case."
    echo ""
    echo "Recommended starting point (no AWS or Kubernetes needed):"
    echo "  cd 02-log-correlation && docker compose up -d && ./trigger_request.sh"
else
    echo "Fix the items above, then re-run this script."
    echo "You only need all prerequisites if you plan to run all five use cases."
    echo ""
    echo "Minimum for use case 4 (no AWS, no Kubernetes):"
    echo "  python3, docker, docker compose"
    exit 1
fi
