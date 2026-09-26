output "azure_client_id" {
  description = "The Client ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.cicd.client_id
}

output "azure_tenant_id" {
  description = "The Azure Tenant ID."
  value       = azurerm_user_assigned_identity.cicd.tenant_id
}

output "azure_subscription_id" {
  description = "The Azure Subscription ID."
  value       = data.azurerm_subscription.current.subscription_id
}
