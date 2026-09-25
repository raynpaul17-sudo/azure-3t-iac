output "vault_uri" {
  description = "URI of the key vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "secret_name" {
  description = "Name of the database password secret"
  value       = var.secret_name
}
