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
