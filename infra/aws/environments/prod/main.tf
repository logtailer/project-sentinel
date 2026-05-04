locals {
  project      = "sentinel"
  environment  = "prod"
  region       = "us-east-1"
  cluster_name = "sentinel-prod"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    Team        = "platform"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}

module "networking" {
  source = "../../modules/networking"

  project      = local.project
  environment  = local.environment
  cluster_name = local.cluster_name

  # 10.1.x.x block — non-overlapping with dev (10.0.x.x)
  vpc_cidr       = "10.1.0.0/16"
  secondary_cidr = "100.65.0.0/16"

  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

  private_subnet_cidrs = ["10.1.0.0/22", "10.1.4.0/22", "10.1.8.0/22"]
  public_subnet_cidrs  = ["10.1.100.0/24", "10.1.101.0/24", "10.1.102.0/24"]
  pod_subnet_cidrs     = ["100.65.0.0/18", "100.65.64.0/18", "100.65.128.0/18"]
}
