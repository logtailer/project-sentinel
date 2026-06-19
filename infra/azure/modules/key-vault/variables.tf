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

variable "tenant_id" {
  type = string
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL from the AKS cluster — used to federate ESO workload identity"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
