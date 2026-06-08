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

variable "aks_cluster_id" {
  type = string
}

variable "action_group_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = "platform@sentinel.example.com"
}

variable "tags" {
  type    = map(string)
  default = {}
}
