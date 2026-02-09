module "security" {
  source = "../../modules/security"

  project     = local.project
  environment = local.environment
  kms_key_arn = module.eks.kms_key_arn
}
