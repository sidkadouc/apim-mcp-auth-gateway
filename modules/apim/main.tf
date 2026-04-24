# ------------------------------------------------------------------------------
# APIM – service, managed identity, logger, product, global policy
# ------------------------------------------------------------------------------

resource "azurerm_api_management" "main" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_email     = var.publisher_email
  publisher_name      = var.publisher_name
  sku_name            = var.sku
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# ---------- Application Insights logger ----------

resource "azurerm_api_management_logger" "appinsights" {
  name                = "appinsights-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  resource_id         = var.appinsights_id

  application_insights {
    instrumentation_key = var.appinsights_instrumentation_key
  }
}

# ---------- Product: MCP ----------

resource "azurerm_api_management_product" "mcp" {
  product_id            = "mcp"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "MCP Servers"
  description           = "Access to Model Context Protocol servers through the AI Gateway"
  subscription_required = false # auth is via Entra JWT, not APIM subscription keys
  published             = true
}

# ---------- Product policy (rate limit + quota) ----------

resource "azurerm_api_management_product_policy" "mcp" {
  product_id          = azurerm_api_management_product.mcp.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = file("${path.module}/../../policies/product-mcp.xml")
}

# ---------- Global policy ----------

resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.main.id
  xml_content       = file("${path.module}/../../policies/global.xml")
}
