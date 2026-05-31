# DevOps Scripting Labs

Companion repository for the freeCodeCamp article:
**How to Use Bash and Python for Real DevOps Automation — 5 Production Use Cases**

Each use case is self-contained in its own folder. Read **`ARTICLE.md`** (overview + links) and the article on freeCodeCamp first — then run the labs.

Run **`./preflight.sh`** once from this directory to verify tools and global Python imports (for example **boto3**) before running any lab `setup.sh`.

## Use cases

| Folder | Use Case | Environment |
|---|---|---|
| [01-cost-anomaly/](01-cost-anomaly/) | [Cost Anomaly Detection](01-cost-anomaly/README.md) | AWS Cost Explorer |
| [02-log-correlation/](02-log-correlation/) | [Log Correlation Across Services](02-log-correlation/README.md) | Fully local (Docker) |
| [03-drift-detection/](03-drift-detection/) | [Infrastructure Drift Detection](03-drift-detection/README.md) | AWS free tier |
| [04-secrets-rotation/](04-secrets-rotation/) | [Secrets Rotation with Zero Downtime](04-secrets-rotation/README.md) | AWS + local Kind |
| [05-canary-rollback/](05-canary-rollback/) | [Automated Canary Rollback Trigger](05-canary-rollback/README.md) | Fully local (Kind) |

## Prerequisites (global)

- Python 3.8+ and a virtual environment: `python3 -m venv venv && source venv/bin/activate`
- Terraform: `brew install terraform` (needed for use case 3)
- AWS CLI configured for use cases 1, 3, and 4
- Docker for use cases 2, 4, and 5
- Kind and kubectl for use cases 4 and 5
- Helm for use case 5
- `bc` for use case 5: `brew install bc` (macOS) / `apt install bc` (Ubuntu)

Each folder has its own `README.md` with specific prerequisites and instructions.

## How to start

```bash
git clone https://github.com/Osomudeya/devops-scripting-labs.git
cd devops-scripting-labs
./preflight.sh

# Use case 2 is the best starting point — no AWS or Kubernetes needed
cd 02-log-correlation
docker compose up -d
./trigger_request.sh
python correlate.py <trace_id>
```

## Deep dive: DevOps Operating System

If you can follow DevOps tutorials but still struggle to explain how Linux, Docker, Kubernetes, and CI/CD fit together, the gap is usually structure rather than effort. **[DevOps Operating System: From Zero to Job-Ready](https://osomudeya.gumroad.com/l/devops-atlas)** is a 12-phase, self-paced path where each ebook builds on the last and applies to the same production-style three-tier project, so you finish with one system you understand end to end instead of a folder of unrelated exercises.

The path runs from Linux and Bash through Git, networking, Docker, Kubernetes, Terraform, DevSecOps, CI/CD, observability, GitOps with ArgoCD, interview readiness, and long-term growth in platform engineering, SRE, and cloud architecture. You work from one downloadable repo throughout, and by the end you can walk through a Kubernetes deployment, a CI/CD pipeline, and Terraform-managed infrastructure with the confidence that comes from having built and debugged it yourself.

Whether you are starting from zero, stuck in tutorial loops, or switching careers and need one coherent project for your GitHub and interviews, **[start here](https://osomudeya.gumroad.com/l/devops-atlas)**.

## Newsletter

I write about DevOps weekly, covering real systems, interview, CV tips and tricks, and real incidents – [Join the newsletter](https://osomudeya.kit.com/23db7ca59f).
