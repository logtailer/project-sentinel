# Networking
output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "pod_subnet_ids" {
  value = module.networking.pod_subnet_ids
}

output "nat_gateway_ids" {
  value = module.networking.nat_gateway_ids
}

# EKS
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "kms_key_arn" {
  value = module.eks.kms_key_arn
}
