variable "location" {
  type    = string
  default = "eastus"
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs for AKS cluster admin"
  type        = list(string)
  default     = []
}

variable "storage_account_name" {
  description = "Name of the bootstrap Storage Account (from infra/azure/bootstrap output)"
  type        = string
}

variable "storage_account_primary_access_key" {
  description = "Access key for the Function App runtime storage (populated out-of-band)"
  type        = string
  sensitive   = true
}
