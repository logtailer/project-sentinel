resource "azurerm_eventgrid_system_topic" "aks" {
  name                   = "egt-${var.project}-aks-${var.environment}"
  resource_group_name    = var.resource_group_name
  location               = var.location
  source_arm_resource_id = var.aks_cluster_id
  topic_type             = "Microsoft.ContainerService.ManagedClusters"

  tags = var.tags
}

resource "azurerm_eventgrid_system_topic_event_subscription" "node_not_ready" {
  name                = "evs-node-not-ready-${var.environment}"
  system_topic        = azurerm_eventgrid_system_topic.aks.name
  resource_group_name = var.resource_group_name

  included_event_types = ["Microsoft.ContainerService.NodePoolRollingStarted"]

  webhook_endpoint {
    url = var.node_remediation_function_url
  }

  retry_policy {
    max_delivery_attempts = 3
    event_time_to_live    = 60
  }
}
