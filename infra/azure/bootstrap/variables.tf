variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Project name — used in resource naming"
  type        = string
  default     = "sentinel"
}
