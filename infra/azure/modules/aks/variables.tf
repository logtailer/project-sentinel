variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "aks_subnet_id" {
  type = string
}

variable "pod_subnet_id" {
  type = string
}

variable "system_node_count" {
  type    = number
  default = 2
}

variable "system_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "user_node_min" {
  type    = number
  default = 0
}

variable "user_node_max" {
  type    = number
  default = 10
}

variable "user_vm_sizes" {
  type    = list(string)
  default = ["Standard_D4s_v3", "Standard_D4as_v4"]
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs for cluster admin access"
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
