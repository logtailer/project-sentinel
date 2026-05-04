variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key used to encrypt Secrets Manager secrets — reuse the EKS key"
}
