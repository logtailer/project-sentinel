# Lambda Functions

Three Python 3.12 functions that provide the self-healing and FinOps automation layer. All are packaged by Terraform (`archive_file`), triggered by EventBridge, and write results to SSM Parameter Store.

| Function | Trigger | What it does |
|---|---|---|
| `node_remediation` | EKS NodeNotReady event | Triggers a rolling nodegroup update and records the event to SSM |
| `scaling_advisor` | CloudWatch ALARM state change | Writes a `scale_out` recommendation to SSM for the alarming cluster |
| `spot_savings` | EventBridge Scheduler (Mon 08:00 UTC) | Queries Cost Explorer for 7-day spot vs on-demand spend and writes a savings report to SSM |

## Environment variables

| Variable | Function | Description |
|---|---|---|
| `CLUSTER_NAME` | all | EKS cluster name |
| `NODE_GROUP_NAME` | node_remediation | Managed node group to update |
| `SSM_REMEDIATION_KEY` | node_remediation | SSM path prefix for remediation records |
| `SSM_ADVICE_KEY` | scaling_advisor | SSM path prefix for scaling advice |
| `SSM_SAVINGS_KEY` | spot_savings | SSM path prefix for weekly cost reports |

## Running tests locally

```bash
cd lambda
pip install -r tests/requirements-test.txt

# Run all tests
pytest tests/ -v

# Run one function's tests
pytest tests/test_node_remediation.py -v
```

Tests use `moto` (`@mock_aws`) to mock AWS APIs — no real AWS calls are made. `test_spot_savings.py` uses `unittest.mock` to patch the Cost Explorer client directly since moto does not support `ce.get_cost_and_usage`.

## IAM path prefix

All Lambda execution roles are created under `/sentinel/` in IAM. This groups every remediation role together for audit and policy scoping without requiring individual ARN enumeration.
