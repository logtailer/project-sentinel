resource "azurerm_service_plan" "functions" {
  name                = "asp-${var.project}-functions-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "functions" {
  name                = "mi-functions-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_linux_function_app" "node_remediation" {
  name                       = "func-${var.project}-node-remediation-${var.environment}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_primary_access_key

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.functions.id]
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    CLUSTER_NAME    = var.cluster_name
    KEY_VAULT_URI   = var.key_vault_uri
    FUNCTIONS_WORKER_RUNTIME = "python"
  }

  tags = var.tags
}

resource "azurerm_linux_function_app" "scaling_advisor" {
  name                       = "func-${var.project}-scaling-advisor-${var.environment}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_primary_access_key

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.functions.id]
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    CLUSTER_NAME    = var.cluster_name
    KEY_VAULT_URI   = var.key_vault_uri
    FUNCTIONS_WORKER_RUNTIME = "python"
  }

  tags = var.tags
}

resource "azurerm_linux_function_app" "cost_advisor" {
  name                       = "func-${var.project}-cost-advisor-${var.environment}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_primary_access_key

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.functions.id]
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    CLUSTER_NAME    = var.cluster_name
    KEY_VAULT_URI   = var.key_vault_uri
    FUNCTIONS_WORKER_RUNTIME = "python"
  }

  tags = var.tags
}
