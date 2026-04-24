# ------------------------------------------------------------------------------
# 03-server — outputs
# ------------------------------------------------------------------------------

output "mcp_endpoint_url" {
  description = "Full MCP server URL through APIM."
  value       = "${local.apim_gateway_url}/${module.mcp_api.api_path}/"
}

output "prm_url" {
  description = "PRM discovery URL."
  value       = var.expose_prm ? "${local.apim_gateway_url}/${module.mcp_api.prm_path}" : null
}

output "vscode_mcp_json" {
  value = jsonencode({
    servers = {
      (var.name) = {
        type = "http"
        url  = "${local.apim_gateway_url}/${module.mcp_api.api_path}/"
      }
    }
  })
}
