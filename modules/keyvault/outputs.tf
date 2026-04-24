# ------------------------------------------------------------------------------
# Key Vault – outputs
# ------------------------------------------------------------------------------

output "vault_id" {
  value = azurerm_key_vault.main.id
}

output "vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "obo_client_id_secret_uri" {
  value = azurerm_key_vault_secret.obo_client_id.versionless_id
}

output "obo_client_secret_secret_uri" {
  value = azurerm_key_vault_secret.obo_client_secret.versionless_id
}
