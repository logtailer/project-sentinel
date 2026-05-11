output "cluster_name" {
  value = module.aks.cluster_name
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "key_vault_uri" {
  value = module.key_vault.key_vault_uri
}

output "eso_identity_client_id" {
  value = module.key_vault.eso_identity_client_id
}
