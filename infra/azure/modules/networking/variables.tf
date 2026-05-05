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

variable "vnet_cidr" {
  type        = string
  description = "Address space for the VNet"
}

variable "aks_subnet_cidr" {
  type        = string
  description = "Subnet CIDR for AKS node pools"
}

variable "pod_subnet_cidr" {
  type        = string
  description = "Delegated subnet CIDR for AKS pod IPs (Azure CNI overlay)"
}

variable "appgw_subnet_cidr" {
  type        = string
  description = "Subnet CIDR for Application Gateway"
}

variable "tags" {
  type    = map(string)
  default = {}
}
