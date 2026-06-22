# Deployment Guide

This guide covers everything needed to go from a clean AWS account (or Azure subscription) to a running Sentinel cluster. It covers one-time setup, the CI/CD pipeline, day-to-day deploy flow, and how to promote to prod.

---

## Table of contents

1. [Prerequisites](#prerequisites)
2. [One-time setup](#one-time-setup)
   - [AWS](#aws-one-time)
   - [Azure](#azure-one-time)
   - [GitHub Environments and secrets](#github-environments-and-secrets)
3. [Deploying](#deploying)
   - [First deploy](#first-deploy)
   - [Day-to-day: push to main](#day-to-day)
   - [Manual deploy via workflow_dispatch](#manual-deploy)
   - [Promoting to prod](#promoting-to-prod)
4. [How the pipeline works](#how-the-pipeline-works)
5. [Rollback](#rollback)
6. [Tear-down](#tear-down)

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Terraform | >= 1.9 | `brew install terraform` or tfenv |
| AWS CLI | v2 | Needed for bootstrap only |
| Azure CLI | latest | Needed for Azure bootstrap only |
| kubectl | any | For post-deploy verification |
| helm | >= 3.15 | For local chart debugging |

You also need:
- An AWS account with admin credentials (bootstrap only; CI uses OIDC after that)
- An Azure subscription with `Owner` role (bootstrap only)
- A GitHub repo with Actions enabled
- A Route53 hosted zone (AWS) or an Azure DNS zone for TLS issuance
- A GitHub OAuth App for ArgoCD Dex SSO

---

## One-time setup

### AWS one-time

#### 1. Bootstrap state backend

```bash
cd infra/aws/bootstrap
terraform init
terraform apply
```

This creates `sentinel-tfstate` (S3) and `sentinel-tflock` (DynamoDB). These are protected by `prevent_destroy` — never run destroy on this layer.

#### 2. Create the OIDC trust for GitHub Actions

GitHub Actions authenticates to AWS using OIDC — no static credentials stored anywhere.

```bash
# Create the OIDC provider (once per account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create the deploy role (replace <org> and <repo>)
aws iam create-role \
  --role-name sentinel-github-deploy-dev \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
        "StringLike":  { "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:environment:dev-aws" }
      }
    }]
  }'

# Attach the permissions policy (AdministratorAccess for a portfolio project;
# scope down to specific services for a real production account)
aws iam attach-role-policy \
  --role-name sentinel-github-deploy-dev \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Repeat for `sentinel-github-deploy-prod` using `environment:prod-aws` in the condition.

#### 3. Seed Secrets Manager (out-of-band)

```bash
aws secretsmanager create-secret \
  --name sentinel/dev/github-oauth \
  --secret-string '{"client_secret":"<your-github-oauth-secret>"}'
```

These secrets are referenced by External Secrets Operator at runtime — they are never stored in Terraform state or Git.

---

### Azure one-time

#### 1. Bootstrap state backend

```bash
az login
cd infra/azure/bootstrap
terraform init
terraform apply
```

Note the `storage_account_name` output — you need it for every subsequent `terraform init`.

```bash
terraform output storage_account_name
# → sentineltfstateabc123
```

#### 2. Create the OIDC federation for GitHub Actions

```bash
# Create an App Registration for CI
az ad app create --display-name "sentinel-github-ci"
APP_ID=$(az ad app list --display-name sentinel-github-ci --query '[0].appId' -o tsv)

# Create a service principal
az ad sp create --id $APP_ID
SP_OID=$(az ad sp show --id $APP_ID --query id -o tsv)

# Grant Contributor on the subscription (scope down for production)
az role assignment create \
  --assignee $SP_OID \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>

# Add federated credential for dev-azure environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-dev-azure",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<org>/<repo>:environment:dev-azure",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Repeat for prod-azure
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-prod-azure",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<org>/<repo>:environment:prod-azure",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

Retrieve the values you need:
```bash
echo "AZURE_CLIENT_ID: $APP_ID"
az account show --query tenantId -o tsv   # AZURE_TENANT_ID
az account show --query id -o tsv         # AZURE_SUBSCRIPTION_ID
```

#### 3. Seed Key Vault secrets

After the first `terraform apply` creates the Key Vault:

```bash
az keyvault secret set \
  --vault-name kv-sentinel-dev \
  --name sentinel-dev-github-oauth-client-secret \
  --value "<your-github-oauth-secret>"
```

---

### GitHub Environments and secrets

#### Create four environments in GitHub

Go to **Settings → Environments** and create:

| Environment | Protection rules |
|---|---|
| `dev-aws` | None (auto-deploy on push to main) |
| `dev-azure` | None |
| `prod-aws` | Required reviewers: add yourself or your team |
| `prod-azure` | Required reviewers: add yourself or your team |

#### Set secrets and variables

**Repository secrets** (Settings → Secrets → Actions):

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN_DEV` | `arn:aws:iam::<account>:role/sentinel-github-deploy-dev` |
| `AWS_ROLE_ARN_PROD` | `arn:aws:iam::<account>:role/sentinel-github-deploy-prod` |
| `AZURE_CLIENT_ID` | App Registration client ID |
| `AZURE_CLIENT_ID_PROD` | Same or separate prod App Registration |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_STORAGE_ACCOUNT_NAME` | Bootstrap output (`sentineltfstateabc123`) |
| `AZURE_STORAGE_ACCOUNT_KEY` | Dev Function App storage key |
| `AZURE_STORAGE_ACCOUNT_KEY_PROD` | Prod Function App storage key |
| `TF_AWS_ADMIN_CIDR` | Your IP in CIDR notation (`1.2.3.4/32`) |
| `TF_AWS_ADMIN_CIDR_PROD` | Prod admin CIDR |
| `TF_ARGOCD_HOSTNAME` | `argocd.your-domain.com` |
| `TF_ARGOCD_HOSTNAME_PROD` | `argocd-prod.your-domain.com` |
| `TF_GITHUB_OAUTH_CLIENT_ID` | GitHub OAuth App client ID |
| `TF_AZURE_ADMIN_GROUP_IDS` | JSON array: `["<aad-group-object-id>"]` |
| `TF_AZURE_ADMIN_GROUP_IDS_PROD` | Prod AAD group |

**Repository variables** (Settings → Variables → Actions):

| Variable | Value |
|---|---|
| `GITOPS_REPO_URL` | `https://github.com/<org>/project-sentinel` |
| `GITHUB_ORG` | `<your-github-org>` |

---

## Deploying

### First deploy

The very first deploy must be done locally because the state backends don't exist yet and the clusters aren't running (chicken-and-egg for OIDC).

**AWS:**
```bash
# 1. Bootstrap (already done above)

# 2. Phase 1: VPC + EKS (no ArgoCD yet)
cd infra/aws/environments/dev
terraform init
terraform apply \
  -var="admin_cidr=1.2.3.4/32" \
  -var="argocd_hostname=argocd.your-domain.com" \
  -var="gitops_repo_url=https://github.com/<org>/project-sentinel" \
  -var="github_org=<org>" \
  -var="github_oauth_client_id=<client-id>"

# 3. Phase 2: ArgoCD add-ons (cluster must be running)
terraform apply -var-file=... # same vars — Terraform no-ops the infra, deploys ArgoCD
```

**Azure:**
```bash
# 1. Bootstrap (already done above)

# 2. Apply — single phase (AKS + ArgoCD in one apply)
cd infra/azure/environments/dev
terraform init -backend-config="storage_account_name=sentineltfstateabc123"
terraform apply \
  -var="argocd_hostname=argocd.your-domain.com" \
  -var="gitops_repo_url=https://github.com/<org>/project-sentinel" \
  -var="storage_account_name=sentineltfstateabc123" \
  -var="storage_account_primary_access_key=<key>"
```

After apply, ArgoCD takes over. It syncs everything in `gitops/` via the root Application. Allow 5–10 minutes for all ApplicationSets to discover and sync.

```bash
# Get the ArgoCD admin password (AWS)
aws secretsmanager get-secret-value \
  --secret-id sentinel/dev/argocd-admin \
  --query SecretString --output text

# Or from AKS (Azure)
kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath='{.data.password}' | base64 -d
```

---

### Day-to-day

Any `git push` to `main` that touches `infra/aws/**` or `infra/azure/**` triggers the deploy workflow automatically:

1. The `changes` job detects which cloud was modified
2. The relevant `deploy-<cloud>-dev` job runs: `terraform init` → `plan` → `apply`
3. The plan is posted to the job summary (visible in the Actions tab)
4. ArgoCD syncs GitOps changes (manifests in `gitops/`) automatically — no workflow needed

GitOps-only changes (anything under `gitops/`) never need a deploy run — ArgoCD polls the repo and syncs within 3 minutes.

---

### Manual deploy

Use the **workflow_dispatch** form in the Actions tab for:
- Running a plan-only dry run before a risky change
- Deploying a specific cloud without waiting for a push
- Triggering a prod deploy

```
Actions → Deploy → Run workflow
  cloud:       aws | azure | both
  environment: dev | prod
  action:      plan | apply
```

Selecting `action: plan` runs the full init + plan but skips apply — the plan output appears in the job summary. Useful for previewing destructive changes before approving.

---

### Promoting to prod

Prod deployments are manual-only and gate-protected:

1. Run the workflow with `environment: prod`, `action: plan` first
2. Review the plan in the job summary — look for unexpected destroys
3. Re-run with `action: apply`
4. The `prod-aws` / `prod-azure` GitHub Environment requires a reviewer approval before the Apply step executes

The prod job also has `needs: deploy-<cloud>-dev`, so prod can only run after a successful dev deploy in the same workflow run. This enforces the dev → prod promotion order.

---

## How the pipeline works

```
push to main (infra/aws/** changed)
  │
  ├─ changes job (paths-filter)
  │    └─ outputs: aws=true, azure=false
  │
  └─ deploy-aws-dev (environment: dev-aws)
       ├─ configure-aws-credentials (OIDC)
       ├─ terraform init
       ├─ terraform plan → job summary
       └─ terraform apply -auto-approve


workflow_dispatch (cloud=both, environment=prod, action=apply)
  │
  ├─ changes job (no-op for dispatch)
  │
  ├─ deploy-aws-dev   ──────┐
  │                         ├─ (runs in parallel, both succeed)
  └─ deploy-azure-dev ──────┘
       │
       ├─ deploy-aws-prod  (waits for approval on prod-aws environment)
       │    └─ terraform apply
       │
       └─ deploy-azure-prod (waits for approval on prod-azure environment)
            └─ terraform apply
```

**Concurrency control:** The workflow has `cancel-in-progress: false` — a second push queues behind the running deploy rather than cancelling it. This prevents mid-apply interruptions.

**Drift:** The separate `drift-detection.yml` runs daily at 07:00 UTC. If state has drifted (exit code 2), it opens a GitHub issue tagged `drift`. This is independent of the deploy workflow.

**Atlantis:** If you have a self-hosted Atlantis server, it handles PR-level `terraform plan` as a comment and `terraform apply` on merge approval. `deploy.yml` is complementary — use Atlantis for PR review workflow and `deploy.yml` for prod gates and manual triggers.

---

## Rollback

Terraform doesn't have a one-command rollback. The correct approach:

**Option 1 — Revert the commit and push**
```bash
git revert HEAD       # creates a new revert commit
git push origin main  # triggers deploy-dev, which applies the revert
```
This is the standard GitOps rollback path. It creates a clean audit trail.

**Option 2 — Pin a previous version and apply**

If you need to roll back a specific resource without reverting everything:
```bash
# Edit the relevant .tf file to pin the previous value
git commit -m "fix: roll back <resource> to previous version"
git push origin main
```

**Option 3 — Local emergency rollback**
```bash
# Only for genuine emergencies where CI is broken
cd infra/aws/environments/dev
git checkout <previous-sha> -- .
terraform apply -var-file=... # apply the previous state
git checkout main -- .        # restore current code
```

Avoid `terraform state rm` or manual state surgery unless absolutely necessary — these are hard to audit and easy to get wrong.

---

## Tear-down

To destroy a dev environment:

```bash
# AWS
cd infra/aws/environments/dev
terraform destroy -var-file=...   # prompts for confirmation

# Azure
cd infra/azure/environments/dev
terraform destroy \
  -backend-config="storage_account_name=sentineltfstateabc123" \
  -var="..."
```

**Never** run `terraform destroy` on:
- `infra/aws/bootstrap` — the S3 bucket and DynamoDB table hold all state
- `infra/azure/bootstrap` — the Storage Account holds all state

Both have `prevent_destroy = true` as a guard, but the CLI prompt would bypass it with `-target` or a forced plan. Don't.
