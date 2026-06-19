output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "eso_identity_client_id" {
  value = azurerm_user_assigned_identity.eso.client_id
}

output "eso_identity_object_id" {
  value = azurerm_user_assigned_identity.eso.principal_id
}
