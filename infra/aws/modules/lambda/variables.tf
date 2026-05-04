variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "node_group_name" {
  type        = string
  description = "Managed node group name — remediation Lambda targets this group"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for SSM parameter encryption"
}
