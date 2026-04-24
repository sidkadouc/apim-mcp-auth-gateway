# ------------------------------------------------------------------------------
# Sample ACA backend — outputs
# ------------------------------------------------------------------------------

output "mcp_server_fqdn" {
  description = "FQDN of the sample MCP server. Use this as backend_url in 03-server."
  value       = module.mcp_server.fqdn
}

output "mcp_server_url" {
  description = "Full URL for the MCP server backend (use as backend_url in 03-server)."
  value       = "https://${module.mcp_server.fqdn}/mcp"
}

output "rest_api_fqdn" {
  value = module.rest_api.fqdn
}

output "rest_api_url" {
  value = "https://${module.rest_api.fqdn}"
}
