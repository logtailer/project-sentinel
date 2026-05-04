variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.30"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

# Restrict the public API endpoint to this CIDR — never leave it 0.0.0.0/0
variable "admin_cidr" {
  type = string
}
