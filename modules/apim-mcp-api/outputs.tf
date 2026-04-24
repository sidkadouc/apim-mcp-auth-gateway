# ------------------------------------------------------------------------------
# APIM MCP API – outputs
# ------------------------------------------------------------------------------

output "api_id" {
  value = azurerm_api_management_api.mcp.id
}

output "api_path" {
  value = azurerm_api_management_api.mcp.path
}

output "prm_path" {
  value = var.expose_prm ? ".well-known/oauth-protected-resource/${var.name}" : null
}
