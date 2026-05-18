variable "cluster_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "argocd_hostname" {
  type = string
}

variable "gitops_repo_url" {
  type = string
}

variable "eso_identity_client_id" {
  description = "Client ID of the user-assigned identity for External Secrets Operator"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
