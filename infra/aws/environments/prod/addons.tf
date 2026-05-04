module "addons" {
  source = "../../modules/add-ons"

  project     = local.project
  environment = local.environment

  gitops_repo_url        = var.gitops_repo_url
  github_org             = var.github_org
  argocd_hostname        = var.argocd_hostname
  github_oauth_client_id = var.github_oauth_client_id

  github_oauth_secret_arn = module.security.github_oauth_secret_arn
}
