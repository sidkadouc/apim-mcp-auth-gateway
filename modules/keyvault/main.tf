# ------------------------------------------------------------------------------
# Key Vault – vault, secrets, APIM access
# ------------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = var.keyvault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  rbac_authorization_enabled = false
  tags                       = var.tags

  # Deployer access
  access_policy {
    tenant_id = var.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete"
    ]
  }

  # APIM managed identity access (read-only)
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.apim_principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }
}

# ---------- Secrets ----------

resource "azurerm_key_vault_secret" "obo_client_id" {
  name         = "obo-client-id"
  value        = var.obo_client_id
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "obo_client_secret" {
  name         = "obo-client-secret"
  value        = var.obo_client_secret
  key_vault_id = azurerm_key_vault.main.id
}
