# ------------------------------------------------------------------------------
# 01-platform — outputs (consumed by 02-configuration, 03-server, 04-client)
# ------------------------------------------------------------------------------

output "resource_group_name" { value = azurerm_resource_group.main.name }
output "location"            { value = var.location }
output "tenant_id"           { value = var.tenant_id }
output "subscription_id"     { value = var.subscription_id }
output "project"             { value = var.project }
output "environment"         { value = var.environment }

# APIM
output "apim_id"          { value = module.apim.apim_id }
output "apim_name"        { value = module.apim.apim_name }
output "apim_gateway_url" { value = module.apim.gateway_url }
output "apim_product_id"  { value = module.apim.product_id }

# Entra
output "gateway_app_id"        { value = module.entra.gateway_app_id }
output "gateway_object_id"     { value = module.entra.gateway_object_id }
output "gateway_identifier_uri" { value = module.entra.gateway_identifier_uri }
output "backend_app_id"        { value = module.entra.backend_app_id }
output "backend_identifier_uri" { value = module.entra.backend_identifier_uri }
output "obo_client_app_id"     { value = module.entra.obo_client_app_id }
output "mcp_access_scope_id"   { value = module.entra.mcp_access_scope_id }
output "test_service_app_id"   { value = module.entra.test_service_app_id }
output "test_service_secret" {
  value     = module.entra.test_service_secret
  sensitive = true
}

# Key Vault
output "keyvault_obo_client_id_uri"     { value = module.keyvault.obo_client_id_secret_uri }
output "keyvault_obo_client_secret_uri" { value = module.keyvault.obo_client_secret_secret_uri }

# ACA
output "aca_environment_id" { value = module.aca.environment_id }

# Observability
output "appinsights_connection_string" {
  value     = module.observability.appinsights_connection_string
  sensitive = true
}
