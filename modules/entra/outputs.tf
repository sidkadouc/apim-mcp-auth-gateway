# ------------------------------------------------------------------------------
# Entra ID – outputs
# ------------------------------------------------------------------------------

output "gateway_app_id" {
  description = "Application (client) ID of the APIM gateway resource app."
  value       = azuread_application.gateway.client_id
}

output "gateway_object_id" {
  value = azuread_application.gateway.object_id
}

output "gateway_identifier_uri" {
  value = azuread_application.gateway.client_id
}

output "backend_app_id" {
  description = "Application (client) ID of the MCP backend resource app."
  value       = azuread_application.backend.client_id
}

output "backend_identifier_uri" {
  value = "api://${azuread_application.backend.client_id}"
}

output "obo_client_app_id" {
  description = "Application (client) ID of the OBO confidential client."
  value       = azuread_application.obo_client.client_id
}

output "obo_client_secret" {
  description = "Client secret value for the OBO client (store in Key Vault)."
  value       = azuread_application_password.obo_client.value
  sensitive   = true
}

output "obo_client_identifier_uri" {
  description = "Identifier URI of the OBO client app (used as PRM scopes_supported prefix)."
  value       = "api://${azuread_application.obo_client.client_id}"
}

output "obo_client_scope_value" {
  description = "Full delegated scope URI for VS Code to request (PRM scopes_supported)."
  value       = "api://${azuread_application.obo_client.client_id}/Mcp.Access"
}

output "tenant_id" {
  value = var.tenant_id
}

output "mcp_access_scope_id" {
  value = random_uuid.mcp_access_scope.result
}

output "backend_access_scope_value" {
  value = "api://${azuread_application.backend.client_id}/Backend.Access"
}

# ---------- Test service app (CC flow) ----------

output "test_service_app_id" {
  description = "Application (client) ID of the CC test service app."
  value       = azuread_application.test_service.client_id
}

output "test_service_secret" {
  description = "Client secret for the CC test service app."
  value       = azuread_application_password.test_service.value
  sensitive   = true
}
