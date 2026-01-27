variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# Secondary CIDR reserved for pod IPs — associated now, activated when VPC CNI
# custom networking is enabled in Month 2.
variable "secondary_cidr" {
  type    = string
  default = "100.64.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# /22 per AZ = ~1022 usable node IPs. /24 exhausts under moderate load.
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.100.0/24", "10.0.101.0/24", "10.0.102.0/24"]
}

# /18 per AZ = ~16k pod IPs. Sized for Karpenter burst in Month 2.
variable "pod_subnet_cidrs" {
  type    = list(string)
  default = ["100.64.0.0/18", "100.64.64.0/18", "100.64.128.0/18"]
}
