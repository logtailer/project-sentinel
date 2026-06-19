resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  storage_account_name = "${var.project}tfstate${random_string.suffix.result}"
  resource_group_name  = "rg-${var.project}-tfstate"
}

resource "azurerm_resource_group" "tfstate" {
  name     = local.resource_group_name
  location = var.location

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
  }

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}
