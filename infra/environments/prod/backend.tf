# Remote state in S3 with DynamoDB locking.
# Prerequisite: run infra/bootstrap/ first to create the bucket and table.
terraform {
  backend "s3" {
    bucket         = "sentinel-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "sentinel-tflock"
  }
}
