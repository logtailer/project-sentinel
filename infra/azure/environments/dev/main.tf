locals {
  project      = "sentinel"
  environment  = "dev"
  location     = var.location
  cluster_name = "sentinel-aks-dev"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    Team        = "platform"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project}-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

module "networking" {
  source = "../../modules/networking"

  project             = local.project
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name

  vnet_cidr         = "10.0.0.0/16"
  aks_subnet_cidr   = "10.0.0.0/22"
  pod_subnet_cidr   = "10.0.64.0/18"
  appgw_subnet_cidr = "10.0.200.0/24"

  tags = local.common_tags
}

module "aks" {
  source = "../../modules/aks"

  project             = local.project
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  cluster_name        = local.cluster_name

  kubernetes_version     = "1.30"
  aks_subnet_id          = module.networking.aks_subnet_id
  pod_subnet_id          = module.networking.pod_subnet_id
  admin_group_object_ids = var.admin_group_object_ids

  system_node_count = 2
  system_vm_size    = "Standard_D2s_v3"
  user_node_min     = 0
  user_node_max     = 10

  tags = local.common_tags
}

module "key_vault" {
  source = "../../modules/key-vault"

  project             = local.project
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  aks_oidc_issuer_url = module.aks.oidc_issuer_url

  tags = local.common_tags
}

module "function_app" {
  source = "../../modules/function-app"

  project             = local.project
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  cluster_name        = local.cluster_name
  key_vault_uri       = module.key_vault.key_vault_uri
  subscription_id     = data.azurerm_client_config.current.subscription_id
  aks_cluster_id      = module.aks.cluster_id

  storage_account_name               = var.storage_account_name
  storage_account_primary_access_key = var.storage_account_primary_access_key

  tags = local.common_tags
}

module "service_bus" {
  source = "../../modules/service-bus"

  project             = local.project
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name

  workload_identity_principal_id = module.aks.kubelet_identity_object_id

  tags = local.common_tags
}

module "add_ons" {
  source = "../../modules/add-ons"

  cluster_name           = local.cluster_name
  resource_group_name    = azurerm_resource_group.main.name
  argocd_hostname        = var.argocd_hostname
  gitops_repo_url        = var.gitops_repo_url
  eso_identity_client_id = module.key_vault.eso_identity_client_id

  tags = local.common_tags

  depends_on = [module.aks]
}
