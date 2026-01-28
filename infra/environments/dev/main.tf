locals {
  project      = "sentinel"
  environment  = "dev"
  region       = "us-east-1"
  cluster_name = "sentinel-dev"

  # Tag everything now — Kubecost allocation reports are useless without consistent coverage
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

  vpc_cidr       = "10.0.0.0/16"
  secondary_cidr = "100.64.0.0/16"

  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

  private_subnet_cidrs = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
  public_subnet_cidrs  = ["10.0.100.0/24", "10.0.101.0/24", "10.0.102.0/24"]
  pod_subnet_cidrs     = ["100.64.0.0/18", "100.64.64.0/18", "100.64.128.0/18"]
}
