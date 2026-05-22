# Azure Functions

Three Python 3.12 Azure Functions that provide the self-healing and FinOps automation layer on Azure. Direct port of the AWS Lambda functions — same logic, Azure SDK instead of boto3.

| Function | Trigger | What it does |
|---|---|---|
| `node_remediation` | Event Grid (NodeNotReady alert) | Triggers AKS node image upgrade and records event to Key Vault |
| `scaling_advisor` | Event Grid (Azure Monitor alert) | Writes a `scale_out` recommendation to Key Vault |
| `cost_advisor` | Timer (Mon 08:00 UTC) | Queries Azure Cost Management for 7-day spot vs pay-as-you-go spend and writes report to Key Vault |

## AWS → Azure equivalents

| AWS | Azure |
|---|---|
| EventBridge rule | Event Grid subscription |
| EventBridge Scheduler | Timer trigger (cron expression) |
| SSM Parameter Store | Key Vault secrets |
| boto3 | azure-identity, azure-keyvault-secrets, azure-mgmt-* |
| EKS rolling nodegroup update | AKS node pool image upgrade |
| Cost Explorer | Azure Cost Management (costmanagement SDK) |

## Environment variables

| Variable | Function | Description |
|---|---|---|
| `CLUSTER_NAME` | all | AKS cluster name |
| `AZURE_SUBSCRIPTION_ID` | node_remediation, cost_advisor | Azure subscription ID |
| `CLUSTER_RESOURCE_GROUP` | node_remediation | Resource group containing the AKS cluster |
| `NODE_POOL_NAME` | node_remediation | Node pool to trigger image upgrade on (default: `user`) |
| `KEY_VAULT_URI` | all | URI of the Key Vault for writing results |

## Running tests locally

```bash
cd azure-functions
pip install -r tests/requirements-test.txt

# Run all tests
pytest tests/ -v

# Run one function's tests
pytest tests/test_scaling_advisor.py -v
```

Tests use `unittest.mock` to patch Azure SDK clients — no real Azure calls are made.

## Identity

All functions share a single user-assigned managed identity (`mi-functions-<env>`). The identity has:
- `Key Vault Secrets Officer` on the Key Vault (write secrets)
- `Azure Kubernetes Service Cluster User Role` on the AKS cluster (trigger node upgrades)
- `Cost Management Reader` on the subscription (query spend data)
