# ------------------------------------------------------------------------------
# APIM – outputs
# ------------------------------------------------------------------------------

output "apim_id" {
  value = azurerm_api_management.main.id
}

output "apim_name" {
  value = azurerm_api_management.main.name
}

output "gateway_url" {
  value = azurerm_api_management.main.gateway_url
}

output "principal_id" {
  description = "Object ID of APIM system-assigned managed identity."
  value       = azurerm_api_management.main.identity[0].principal_id
}

output "product_id" {
  value = azurerm_api_management_product.mcp.product_id
}

output "logger_id" {
  value = azurerm_api_management_logger.appinsights.id
}

output "resource_group_name" {
  value = var.resource_group_name
}
