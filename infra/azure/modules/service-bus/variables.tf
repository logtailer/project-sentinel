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

variable "workload_identity_principal_id" {
  description = "Principal ID of the workload identity that KEDA uses to authenticate"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
