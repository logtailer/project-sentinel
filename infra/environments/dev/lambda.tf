module "lambda" {
  source = "../../modules/lambda"

  project     = local.project
  environment = local.environment
  cluster_name    = local.cluster_name
  node_group_name = "${local.cluster_name}-general"
  kms_key_arn     = module.eks.kms_key_arn
}
