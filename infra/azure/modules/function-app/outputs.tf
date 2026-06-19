output "node_remediation_function_id" {
  value = azurerm_linux_function_app.node_remediation.id
}

output "scaling_advisor_function_id" {
  value = azurerm_linux_function_app.scaling_advisor.id
}

output "cost_advisor_function_id" {
  value = azurerm_linux_function_app.cost_advisor.id
}

output "function_identity_client_id" {
  value = azurerm_user_assigned_identity.functions.client_id
}
