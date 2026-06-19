resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  sku_tier = var.environment == "prod" ? "Standard" : "Free"

  default_node_pool {
    name           = "system"
    node_count     = var.system_node_count
    vm_size        = var.system_vm_size
    vnet_subnet_id = var.aks_subnet_id
    pod_subnet_id  = var.pod_subnet_id

    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    ebpf_data_plane     = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
    duration    = 4
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
      kubernetes_version,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_vm_sizes[0]
  vnet_subnet_id        = var.aks_subnet_id
  pod_subnet_id         = var.pod_subnet_id

  auto_scaling_enabled = true
  min_count            = var.user_node_min
  max_count            = var.user_node_max

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1

  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
    "workload-type"                          = "general"
  }

  node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}
