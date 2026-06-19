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

variable "storage_account_name" {
  type        = string
  description = "Storage account for Function App runtime (not tfstate)"
}

variable "storage_account_primary_access_key" {
  type      = string
  sensitive = true
}

variable "cluster_name" {
  type = string
}

variable "key_vault_uri" {
  type = string
}

variable "subscription_id" {
  description = "Azure subscription ID — used for cost management role scope"
  type        = string
}

variable "aks_cluster_id" {
  description = "Resource ID of the AKS cluster — used for RBAC role assignment"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
