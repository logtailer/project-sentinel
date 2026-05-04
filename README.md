# Project Sentinel

A production-grade, self-healing EKS platform built with Terraform and ArgoCD GitOps. Sentinel provisions a fully automated Kubernetes environment on AWS — from VPC and cluster creation through runtime security, observability, FinOps, and chaos engineering — with every layer managed as code.

## What it builds

```
AWS Account
└── VPC (10.0.0.0/16 + 100.64.0.0/16 pod CIDR, 3 AZs, per-AZ NAT)
    └── EKS 1.30 (KMS etcd encryption, API auth mode, Pod Identity)
        ├── Karpenter          — spot + on-demand node provisioning with SQS interruption handling
        ├── ArgoCD             — GitOps engine with GitHub Dex SSO, sync waves, ApplicationSets
        ├── cert-manager       — automated TLS via Let's Encrypt DNS-01 (Route53)
        ├── External Secrets   — runtime secret injection from AWS Secrets Manager
        ├── Falco              — eBPF runtime threat detection routed to Alertmanager via Falcosidekick
        ├── Trivy Operator     — in-cluster image vulnerability scanning with CVE alerting
        ├── Kyverno            — policy engine (default-deny NetworkPolicy, PDB generation, CVE blocking)
        ├── VPA + Goldilocks   — right-sizing recommendations
        ├── KEDA               — event-driven pod autoscaling (SQS, CloudWatch)
        ├── kube-prometheus-stack — metrics, alerting, Grafana dashboards
        ├── Loki               — log aggregation with Promtail (node logs + kube-audit)
        ├── Tempo              — distributed tracing
        ├── OpenTelemetry      — unified traces + metrics pipeline
        ├── Kubecost           — cost allocation federated to existing Prometheus
        └── AWS FIS            — chaos experiments (spot termination, memory pressure)
```

Self-healing is wired end-to-end: Karpenter replaces spot nodes, three Lambda functions handle node remediation, scaling advice, and weekly cost reporting, and AWS FIS experiments validate recovery automatically.

## Repository layout

```
.
├── infra/
│   ├── aws/
│   │   ├── bootstrap/          # S3 state bucket + DynamoDB lock (run once)
│   │   ├── modules/            # Reusable Terraform modules
│   │   │   ├── networking/     # VPC, subnets, NAT, VPC endpoints
│   │   │   ├── eks/            # Cluster, node groups, KMS, Karpenter IAM
│   │   │   ├── add-ons/        # ArgoCD Helm release + root Application
│   │   │   ├── lambda/         # IAM, packaging, EventBridge for all three Lambdas
│   │   │   ├── security/       # GuardDuty, Secrets Manager shell resources
│   │   │   └── fis/            # AWS FIS IAM + experiment templates
│   │   └── environments/
│   │       ├── dev/            # Dev environment (wires all modules, ECR, FIS)
│   │       └── prod/           # Prod skeleton (HA Prometheus, 90d retention)
│   └── azure/
│       ├── bootstrap/          # Azure Storage Account + resource group for state (run once)
│       ├── modules/            # Reusable Terraform modules
│       │   ├── networking/     # VNet, subnets, NSGs
│       │   ├── aks/            # AKS cluster, node pools, Workload Identity
│       │   ├── add-ons/        # ArgoCD Helm release + root Application
│       │   ├── key-vault/      # Key Vault, access policies, ESO integration
│       │   └── function-app/   # Azure Functions, Service Bus triggers
│       └── environments/
│           ├── dev/            # Dev environment
│           └── prod/           # Prod environment
│
├── gitops/
│   ├── bootstrap/          # ArgoCD root Application + ApplicationSets + Helm app manifests
│   ├── apps/system/        # Plain YAML discovered by ApplicationSet (Kyverno policies,
│   │                       #   monitoring rules, storage, security CronJobs, etc.)
│   ├── apps/workloads/     # Tenant workload Applications
│   └── clusters/
│       ├── dev/            # Dev cluster values overrides
│       └── prod/           # Prod cluster registration secret + monitoring values
│
├── lambda/
│   ├── node_remediation/   # EKS NodeNotReady → rolling nodegroup update
│   ├── scaling_advisor/    # CloudWatch ALARM → SSM scaling recommendation
│   ├── spot_savings/       # Weekly Cost Explorer report → SSM parameter
│   └── tests/              # pytest + moto unit tests for all three functions
│
└── .github/workflows/
    ├── ci.yml              # terraform fmt/validate, checkov, kubeconform, helm lint, pytest
    ├── pre-commit.yml      # pre-commit hook validation on PRs
    └── drift-detection.yml # scheduled Terraform plan diff with GitHub issue creation
```

## Tech stack

| Layer | Tools |
|---|---|
| IaC | Terraform 1.9, tflint, Checkov |
| Cluster | EKS 1.30, Karpenter 1.0, Pod Identity |
| GitOps | ArgoCD 7.4, ApplicationSets, sync waves |
| Security | Kyverno, Falco, Trivy Operator, GuardDuty, ESO, cert-manager |
| Observability | Prometheus, Grafana, Loki, Tempo, OpenTelemetry Collector |
| FinOps | Kubecost, Sloth SLOs, spot savings Lambda |
| Autoscaling | Karpenter, KEDA, VPA (recommendation mode), Goldilocks |
| Chaos | AWS FIS (spot termination, memory pressure) |
| CI | GitHub Actions, Atlantis (PR plans), drift detection |
| Runtime | Python 3.12 Lambdas, moto-tested, EventBridge triggers |

## Prerequisites

- AWS account with credentials configured
- Terraform >= 1.9
- A Route53 hosted zone (for cert-manager DNS-01 challenge)
- A GitHub OAuth App (for ArgoCD Dex SSO)

## Deploying

### 1 — Bootstrap state backend (once)

```bash
cd infra/aws/bootstrap
terraform init && terraform apply
```

### 2 — Populate secrets out-of-band

```bash
aws secretsmanager create-secret \
  --name sentinel/dev/github-oauth \
  --secret-string '{"client_secret":"<your-github-oauth-secret>"}'
```

### 3 — Create `infra/environments/dev/dev.tfvars` (gitignored)

```hcl
admin_cidr             = "1.2.3.4/32"          # your VPN or home IP — never 0.0.0.0/0
gitops_repo_url        = "https://github.com/<org>/project-sentinel"
github_org             = "<org>"
argocd_hostname        = "argocd.your-domain.com"
github_oauth_client_id = "<oauth-client-id>"
```

### 4 — Two-phase apply

```bash
cd infra/aws/environments/dev

# Phase 1: VPC + EKS cluster
terraform init
terraform apply -var-file=dev.tfvars

# Phase 2: ArgoCD + add-ons (requires cluster to be running)
terraform apply -var-file=dev.tfvars
```

ArgoCD then takes over and syncs everything in `gitops/` automatically via the root Application.

### 5 — Update placeholder values

Before ArgoCD syncs, update these files with real values:

| File | What to set |
|---|---|
| `gitops/apps/system/cert-manager/cluster-issuer.yaml` | Email address, Route53 IAM role ARN |
| `gitops/apps/system/cert-manager/argocd-ingress.yaml` | Real ArgoCD hostname |
| `gitops/bootstrap/app-argocd-image-updater.yaml` | AWS account ID for ECR URL |
| `gitops/clusters/prod/cluster-secret.yaml` | Prod cluster endpoint + CA data (after prod apply) |
| `gitops/apps/system/keda/scaledobject-sqs.yaml` | Real SQS queue name |

## CI

Every push and pull request runs:

- `terraform fmt -check` + `terraform validate` across all environments
- `checkov` security scan against `.checkov.yml`
- `kubeconform` manifest validation against Kubernetes schemas + CRD catalog
- `helm lint` against all bootstrap ArgoCD Applications
- `pytest` with `moto` mocks for all four Lambda packages

Pull requests also trigger Atlantis for live `terraform plan` output as a PR comment, with Checkov as a plan gate. A scheduled workflow runs daily at 07:00 UTC and opens a GitHub issue if Terraform state has drifted from the live environment.

## Self-healing flow

```
Spot interruption notice
  → EventBridge → SQS (Karpenter interruption queue)
  → Karpenter cordons + drains node, provisions replacement

EKS NodeNotReady event
  → EventBridge → node_remediation Lambda
  → triggers rolling nodegroup update
  → records event to SSM Parameter Store

CloudWatch alarm (high CPU)
  → EventBridge → scaling_advisor Lambda
  → writes scale_out recommendation to SSM
  → Karpenter picks up increased pod pressure and provisions nodes

Weekly (Monday 08:00 UTC)
  → EventBridge Scheduler → spot_savings Lambda
  → queries Cost Explorer for spot vs on-demand spend
  → writes weekly savings report to SSM
```

AWS FIS validates this loop: the spot termination experiment terminates a random node and the recovery test asserts the Lambda fires and SSM is updated within the expected window.

## Security model

- EKS public endpoint restricted to `admin_cidr` — never `0.0.0.0/0`
- KMS encryption for etcd secrets, set at cluster creation
- `authentication_mode = API` — no `aws-auth` ConfigMap
- Pod Identity for all service accounts (no IRSA, no static credentials)
- All IAM roles under `/sentinel/` path prefix for audit grouping
- Secrets Manager values populated out-of-band — never in Terraform state or Git
- Kyverno enforces: default-deny NetworkPolicy, resource limits, no privileged containers, team labels, no unauthenticated API mutations
- Falco detects: cryptomining, K8s API abuse, host path writes at runtime
- Trivy scans every image; critical CVEs block deployment via Kyverno admission
- kube-bench runs weekly CIS benchmark; failures alert via Prometheus
