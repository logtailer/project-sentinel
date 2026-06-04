resource "azurerm_servicebus_namespace" "main" {
  name                = "sb-${var.project}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"

  local_auth_enabled            = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  tags = var.tags
}

resource "azurerm_servicebus_queue" "work" {
  name         = "sentinel-work-queue"
  namespace_id = azurerm_servicebus_namespace.main.id

  max_delivery_count        = 10
  message_time_to_live      = "P1D"
  dead_lettering_on_message_expiration = true
  lock_duration             = "PT5M"
}

resource "azurerm_role_assignment" "keda_servicebus_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = var.workload_identity_principal_id
}
