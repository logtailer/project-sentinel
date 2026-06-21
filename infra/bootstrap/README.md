# Bootstrap

Creates the S3 bucket and DynamoDB table that all other Terraform environments use for remote state. This layer uses a **local** backend — it has no remote state of its own.

## Run once, before anything else

```bash
cd infra/bootstrap
terraform init
terraform apply
```

After apply, `sentinel-tfstate` (S3) and `sentinel-tflock` (DynamoDB) will exist in `us-east-1`. Every other environment references them via:

```hcl
terraform {
  backend "s3" {
    bucket         = "sentinel-tfstate"
    key            = "<env>/terraform.tfstate"
    dynamodb_table = "sentinel-tflock"
  }
}
```

## Never run `terraform destroy` on this layer

The S3 bucket has `prevent_destroy = true` and holds the state for every other environment. Destroying it would make all other workspaces unrecoverable without a manual state migration.

## Re-running is safe

`terraform apply` is idempotent. If the bucket or table already exists, it will no-op.
