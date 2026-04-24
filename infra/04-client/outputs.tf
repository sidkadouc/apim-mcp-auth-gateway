# ------------------------------------------------------------------------------
# 04-client — outputs
# ------------------------------------------------------------------------------

output "client_type" { value = var.client_type }
output "client_name" { value = var.client_name }

# PKCE
output "pkce_preauthorized" {
  value = var.client_type == "pkce" ? true : null
}

# CC
output "cc_app_id" {
  value = var.client_type == "cc" ? azuread_application.cc_client[0].client_id : null
}

output "cc_client_secret" {
  value     = var.client_type == "cc" && var.create_secret ? azuread_application_password.cc_client[0].value : null
  sensitive = true
}

# Connection info
output "gateway_url" {
  value = local.apim_gateway_url
}

output "token_endpoint" {
  value = "https://login.microsoftonline.com/${local.tenant_id}/oauth2/v2.0/token"
}

output "scope" {
  value = var.client_type == "pkce" ? "api://${local.gateway_app_id}/Mcp.Access" : "api://${local.gateway_app_id}/.default"
}
