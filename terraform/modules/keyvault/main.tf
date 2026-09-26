data "azurerm_client_config" "current" {}

resource "random_string" "main" {
  length  = 4
  numeric = true
  special = false
  upper   = false
}

# checkov:skip=CKV_AZURE_110:Purge protection disabled so the ephemeral vault name can be reused across destroy/apply cycles
# checkov:skip=CKV_AZURE_42:Same reason as above; the vault holds no data that must survive a destroy
# checkov:skip=CKV2_AZURE_32:Private endpoint is billed hourly and requires a private DNS zone; access is restricted by firewall and service endpoints instead
resource "azurerm_key_vault" "main" {
  name                        = "kv-${var.prefix}-${random_string.main.result}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  rbac_authorization_enabled  = true
  enabled_for_disk_encryption = false
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = [var.admin_ip]
    virtual_network_subnet_ids = var.subnet_ids
  }
}

ephemeral "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+"
}

resource "azurerm_key_vault_secret" "db_password" {
  name             = var.secret_name
  key_vault_id     = azurerm_key_vault.main.id
  value_wo         = ephemeral.random_password.db.result
  value_wo_version = 1
  content_type     = "password"
  expiration_date  = var.secret_expiration_date

  depends_on = [azurerm_role_assignment.terraform]
}

resource "azurerm_role_assignment" "terraform" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "vm" {
  for_each             = var.reader_principal_ids
  scope                = azurerm_key_vault_secret.db_password.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}
