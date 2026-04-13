module "eks" {
  source = "../../modules/eks"

  project      = local.project
  environment  = local.environment
  cluster_name = local.cluster_name

  cluster_version = "1.30"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # Restrict the public endpoint to your VPN CIDR before applying
  admin_cidr = var.admin_cidr
}
