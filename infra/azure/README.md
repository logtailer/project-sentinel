# Azure Infrastructure

Terraform modules and environments for running Project Sentinel on Azure. Mirrors the AWS layout — same GitOps layer, same ArgoCD bootstrap, same observability stack — with cloud-native Azure services replacing their AWS equivalents.

## AWS → Azure mapping

| AWS | Azure |
|---|---|
| VPC | Virtual Network (VNet) |
| EKS | AKS (Azure Kubernetes Service) |
| IRSA / Pod Identity | Workload Identity + Federated Credentials |
| Secrets Manager + ESO | Key Vault + CSI Secret Store |
| Lambda | Azure Functions (Python 3.12) |
| EventBridge | Event Grid |
| CloudWatch | Azure Monitor |
| Cost Explorer | Azure Cost Management |
| S3 (tfstate) | Azure Storage Account (Blob) |
| DynamoDB (tflock) | Azure Storage Account (Blob lease locking) |

## Structure

```
infra/azure/
├── bootstrap/          # Storage Account + container for remote state (run once)
├── modules/
│   ├── networking/     # VNet, subnets (AKS + pod + AppGW), NSG
│   ├── aks/            # AKS cluster, Cilium CNI, spot node pool, Workload Identity
│   ├── add-ons/        # ArgoCD Helm release + root Application
│   ├── key-vault/      # Key Vault, RBAC, ESO federated identity
│   └── function-app/   # Azure Functions (node remediation, scaling advisor, cost advisor)
└── environments/
    ├── dev/            # Dev environment (10.0.0.0/16, Standard_D2s_v3 system nodes)
    └── prod/           # Prod environment (10.1.0.0/16, Standard_D4s_v3, HA counts)
```

## Deploying

### 1 — Bootstrap state backend (once)

```bash
cd infra/azure/bootstrap
terraform init
terraform apply
```

Note the `storage_account_name` output — you'll need it for the backend config in each environment.

### 2 — Create `infra/azure/environments/dev/dev.tfvars` (gitignored)

```hcl
argocd_hostname    = "argocd.your-domain.com"
gitops_repo_url    = "https://github.com/<org>/project-sentinel"
storage_account_name               = "<bootstrap output>"
storage_account_primary_access_key = "<from azure portal, never commit>"
```

### 3 — Apply

```bash
cd infra/azure/environments/dev
terraform init -backend-config="storage_account_name=<bootstrap output>"
terraform apply -var-file=dev.tfvars
```

## Key differences from AWS

- **No KMS key to pre-create** — AKS disk encryption uses platform-managed keys by default; bring-your-own-key is a Key Vault reference on the node pool
- **No aws-auth ConfigMap** — AKS uses Azure RBAC natively (`azure_rbac_enabled = true`)
- **Spot nodes via VMSS priority** — Karpenter not available on AKS; spot is a node pool property, eviction handled by Azure
- **Secret rotation** — Key Vault CSI driver polls on `secret_rotation_interval` (default 2min); no ESO polling loop needed for mounted secrets
