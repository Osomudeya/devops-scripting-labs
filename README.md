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

If you've been learning DevOps but still can't explain how everything connects — Linux, Docker, Kubernetes, CI/CD — you're not missing effort. You're missing a system.

**[DevOps Operating System — From Zero to Job-Ready](https://osomudeya.gumroad.com/l/devops-atlas)** fixes that.

Many paths hand you 12 separate topics and leave you to figure out how they relate. This one doesn't. Every phase — Linux, Docker, Kubernetes, CI/CD, Terraform, GitOps — builds on the one before it and lands in the same codebase. By the end, you have one production-style project you understand top to bottom, not a folder of disconnected exercises.

That project is what you bring to interviews. Not just a screenshot, but a real system you built, failed at, debugged, fixed, and can walk through confidently because you were there for all of it.

The path is **12 phases**, each delivered as a focused ebook. Fully self-paced, but structured so you always know what to do next. Each file is one phase in the path. The system is based on real-world DevOps workflows and is designed to help you build and explain systems the way engineers actually do in production.

**One downloadable repo:** the production-style three-tier app you build throughout the path.

### The full path you'll follow

1. Linux and Bash
2. Git and Version Control Strategies
3. Networking for DevOps
4. Docker and Containers
5. Kubernetes
6. Terraform and Infrastructure as Code
7. DevSecOps
8. CI/CD Pipelines
9. Observability and Monitoring
10. GitOps with ArgoCD
11. Job-Ready System: Resume, GitHub, LinkedIn, Interviews
12. Long-Term Growth: Platform Engineering, SRE, Cloud Architecture

### By the end of this path, you will have

- A working Kubernetes deployment you can walk through confidently in an interview
- A CI/CD pipeline you can explain step-by-step, not just show on a screenshot
- Terraform-managed infrastructure provisioned from scratch
- A real project with failure scenarios you've debugged yourself — the kind that actually comes up in interviews

### Who this is for

- Beginners who are serious about becoming DevOps engineers but don't know where to start
- Self-taught engineers stuck in tutorial loops who can deploy things but can't explain them
- Career switchers who need a structured path rather than a scattered collection of courses
- Engineers who want their projects to pass the interview question: *"Walk me through what this does."*

### Common questions

**Q: Is each phase a separate thing, or do they follow a path?**  
A: They follow a path. Each phase builds on the one before it and applies to the same project, so by the end, everything connects into one system you understand top to bottom.

**Q: Do I need prior experience?**  
A: No. The path starts from Linux fundamentals and assumes nothing. If you already know some of the early phases, you can move through them faster; there's no gate stopping you.

**Q: Is this self-paced?**  
A: Fully. You move at your own speed. No deadlines, no cohorts, no live sessions.

If you're serious about becoming job-ready in DevOps, **[start here](https://osomudeya.gumroad.com/l/devops-atlas)**.

## Newsletter

I write about DevOps weekly, covering real systems, interview, CV tips and tricks, and real incidents – [Join the newsletter](https://osomudeya.kit.com/23db7ca59f).
