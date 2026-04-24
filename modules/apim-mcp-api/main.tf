# ------------------------------------------------------------------------------
# APIM MCP API – reusable module: creates API, operations, composed policy, PRM
# ------------------------------------------------------------------------------

locals {
  display_name = var.display_name != "" ? var.display_name : "MCP: ${var.name}"
}

# ==========================================================================
# 1. MCP API – Streamable HTTP
# ==========================================================================

resource "azurerm_api_management_api" "mcp" {
  name                = "mcp-${var.name}"
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  revision            = "1"
  display_name          = local.display_name
  path                  = "mcp/${var.name}"
  protocols             = ["https"]
  service_url           = var.backend_url
  subscription_required = false
}

# POST / – main MCP endpoint (JSON-RPC over Streamable HTTP)
resource "azurerm_api_management_api_operation" "mcp_post" {
  operation_id        = "mcp-post"
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "MCP Streamable HTTP (POST)"
  method              = "POST"
  url_template        = "/"
}

# GET / – SSE stream for server-initiated messages
resource "azurerm_api_management_api_operation" "mcp_get" {
  operation_id        = "mcp-get"
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "MCP SSE Stream (GET)"
  method              = "GET"
  url_template        = "/"
}

# DELETE / – close session
resource "azurerm_api_management_api_operation" "mcp_delete" {
  operation_id        = "mcp-delete"
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "MCP Close Session (DELETE)"
  method              = "DELETE"
  url_template        = "/"
}

# ---------- API-level policy (composed from fragments) ----------

resource "azurerm_api_management_api_policy" "mcp" {
  api_name            = azurerm_api_management_api.mcp.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name

  xml_content = templatefile("${path.module}/policy.tftpl.xml", {
    required_scope = var.required_scope
    required_role  = var.required_role
    backend_audience = var.backend_audience
    auth_mode        = var.auth_mode
    mcp_server_name  = var.name
    allowed_groups   = join(",", var.allowed_groups)
  })
}

# ---------- Product link ----------

resource "azurerm_api_management_product_api" "mcp" {
  api_name            = azurerm_api_management_api.mcp.name
  product_id          = var.product_id
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
}

# ==========================================================================
# 2. PRM operations – added to the shared PRM API (created in root main.tf)
# ==========================================================================

resource "azurerm_api_management_api_operation" "prm_get" {
  count               = var.expose_prm ? 1 : 0
  operation_id        = "prm-${var.name}"
  api_name            = var.prm_api_name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "PRM Discovery (${var.name})"
  method              = "GET"
  url_template        = "/${var.name}"
}

resource "azurerm_api_management_api_operation_policy" "prm" {
  count               = var.expose_prm ? 1 : 0
  operation_id        = azurerm_api_management_api_operation.prm_get[0].operation_id
  api_name            = var.prm_api_name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name

  xml_content = templatefile("${path.module}/prm-policy.tftpl.xml", {
    tenant_id        = var.tenant_id
    mcp_server_name  = var.name
    apim_name        = var.api_management_name
    obo_client_id    = var.obo_client_id
  })
}
