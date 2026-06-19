# Azure Bootstrap

Creates the Azure Storage Account and container that all other Terraform environments use for remote state. Uses a **local** backend — it has no remote state of its own.

## Run once, before anything else

```bash
cd infra/azure/bootstrap
terraform init
terraform apply
```

After apply, a Storage Account named `sentineltfstate<suffix>` will exist in the `rg-sentinel-tfstate` resource group. Every other Azure environment references it via:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-sentinel-tfstate"
    storage_account_name = "<output from bootstrap>"
    container_name       = "tfstate"
    key                  = "<env>/terraform.tfstate"
  }
}
```

## Never run `terraform destroy` on this layer

Both the Storage Account and container have `prevent_destroy = true`. The account holds state for every Azure environment — destroying it requires a manual state migration.

## Re-running is safe

`terraform apply` is idempotent. If the resources already exist, it will no-op.
