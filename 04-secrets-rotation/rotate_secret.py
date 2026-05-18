"""
rotate_secret.py — Use Case 2: Secrets Rotation with Zero Downtime

Full rotation order:
  1. Generate a new cryptographically random password
  2. Update AWS Secrets Manager with the new credential
  3. Run ALTER USER on PostgreSQL via kubectl exec — this is the moment
     the database starts requiring the new password for new connections
  4. Update the Kubernetes Secret object
  5. Trigger a rolling restart so new pods read the new credential
  6. Wait for rollout to complete (readiness probe passes)
  7. Verify — open a fresh connection using new credentials and run SELECT 1

Step 7 is what the readiness probe skips.
The readiness probe validates Step 6 (HTTP reachability).
Step 7 validates the actual contract your users care about.
"""

from __future__ import annotations

import base64
import json
import secrets
import subprocess
import sys
import time

import boto3
from kubernetes import client, config


def get_current_secret(secret_name):
    sm = boto3.client("secretsmanager")
    response = sm.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])


def update_secrets_manager(secret_name, username, new_password):
    """Write the new credential to AWS Secrets Manager."""
    sm = boto3.client("secretsmanager")
    sm.put_secret_value(
        SecretId=secret_name,
        SecretString=json.dumps({"username": username, "password": new_password}),
    )
    print("  [AWS] Secrets Manager updated.")


def _pg_password_literal(password: str) -> str:
    """SQL string literal for use inside single-quoted ALTER USER ... PASSWORD '...'."""
    return "'" + password.replace("'", "''") + "'"


def rotate_postgres_password(namespace, new_password):
    """
    Run ALTER USER on the live PostgreSQL pod via kubectl exec.
    """
    print("  [DB]  Running ALTER USER on PostgreSQL...")
    sql = f"ALTER USER appuser PASSWORD {_pg_password_literal(new_password)};"
    result = subprocess.run(
        [
            "kubectl",
            "exec",
            "deployment/postgres",
            "-n",
            namespace,
            "--",
            "env",
            "PGPASSWORD=postgres-admin",
            "psql",
            "-U",
            "postgres",
            "-d",
            "appdb",
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            sql,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"ALTER USER failed: {result.stderr}\n"
            "Check that the postgres deployment is running and the superuser password is correct."
        )
    print("  [DB]  Password changed at the database level.")
    print("        New connections now require the new password.")
    print("        Existing pool connections remain valid until they close.")


def update_kubernetes_secret(namespace, k8s_secret_name, username, new_password):
    """Patch the Kubernetes Secret so new pods receive the new credential."""
    config.load_kube_config()
    v1 = client.CoreV1Api()
    v1.patch_namespaced_secret(
        name=k8s_secret_name,
        namespace=namespace,
        body={
            "data": {
                "username": base64.b64encode(username.encode()).decode(),
                "password": base64.b64encode(new_password.encode()).decode(),
            }
        },
    )
    print("  [K8s] Kubernetes Secret updated.")


def rolling_restart(namespace, deployment_name):
    result = subprocess.run(
        [
            "kubectl",
            "rollout",
            "restart",
            f"deployment/{deployment_name}",
            "-n",
            namespace,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Rolling restart failed: {result.stderr}")
    print(f"  [K8s] Rolling restart triggered for '{deployment_name}'.")


def wait_for_rollout(namespace, deployment_name, timeout=120):
    print(f"  [K8s] Waiting for rollout (timeout: {timeout}s)...")
    result = subprocess.run(
        [
            "kubectl",
            "rollout",
            "status",
            f"deployment/{deployment_name}",
            "-n",
            namespace,
            f"--timeout={timeout}s",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Rollout did not complete: {result.stderr}")
    print("  [K8s] Rollout complete. All pods report Ready.")


def verify_credential(namespace, deployment_name, attempts=5, delay_seconds=3):
    """Hit /healthz/db on a Running pod from the deployment (not a Terminating one)."""
    print("  [Verify] Opening fresh database connection via /healthz/db...")

    for attempt in range(1, attempts + 1):
        verify = subprocess.run(
            [
                "kubectl",
                "exec",
                f"deployment/{deployment_name}",
                "-n",
                namespace,
                "--",
                "curl",
                "-sf",
                "http://localhost:8000/healthz/db",
            ],
            capture_output=True,
            text=True,
        )
        if verify.returncode == 0:
            print("  [Verify] PASSED. Fresh connection authenticated successfully.")
            return True

        if attempt < attempts:
            print(
                f"  [Verify] Attempt {attempt}/{attempts} failed; "
                f"retrying in {delay_seconds}s..."
            )
            time.sleep(delay_seconds)

    print("  [Verify] FAILED.")
    print("           Pod is Running. Readiness probe passed.")
    print("           Fresh database connection failed authentication.")
    if verify.stderr.strip():
        print(f"           curl: {verify.stderr.strip()}")
    print("           The readiness probe validated HTTP reachability only.")
    print("           These are two different contracts.")
    return False


def rotate(secret_name, namespace, k8s_secret_name, deployment_name):
    new_password = secrets.token_urlsafe(16)
    print(f"\n  Generated new credential (not logged in full): {new_password[:4]}...")

    print("\n[Step 1/6] Reading current secret from AWS Secrets Manager...")
    current = get_current_secret(secret_name)
    username = current["username"]

    print("[Step 2/6] Updating AWS Secrets Manager...")
    update_secrets_manager(secret_name, username, new_password)

    print("[Step 3/6] Rotating password at the database level (ALTER USER)...")
    rotate_postgres_password(namespace, new_password)

    print("[Step 4/6] Updating Kubernetes Secret...")
    update_kubernetes_secret(namespace, k8s_secret_name, username, new_password)

    print("[Step 5/6] Triggering rolling restart...")
    rolling_restart(namespace, deployment_name)
    wait_for_rollout(namespace, deployment_name)

    print("[Step 6/6] Verifying new credential at the application level...")
    success = verify_credential(namespace, deployment_name)

    print("\n" + "=" * 60)
    if success:
        print("Rotation complete. Credential verified end-to-end.")
        print("  AWS Secrets Manager: updated")
        print("  PostgreSQL:          updated (ALTER USER)")
        print("  Kubernetes Secret:   updated")
        print("  Application pod:     restarted, authenticated")
    else:
        print("Rotation incomplete. See FAILED message above.")
        print("Recommended: check PostgreSQL logs and pod environment variables.")
        sys.exit(1)


if __name__ == "__main__":
    rotate(
        secret_name="myapp/db-credentials",
        namespace="default",
        k8s_secret_name="db-credentials",
        deployment_name="myapp",
    )
