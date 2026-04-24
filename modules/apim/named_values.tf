# ------------------------------------------------------------------------------
# APIM – named values (plain config – KV-backed values created in root main.tf)
# ------------------------------------------------------------------------------

resource "azurerm_api_management_named_value" "tenant_id" {
  name                = "tenant-id"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "tenant-id"
  value               = var.tenant_id
}

resource "azurerm_api_management_named_value" "gateway_audience" {
  name                = "gateway-audience"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "gateway-audience"
  value               = var.gateway_audience
}

resource "azurerm_api_management_named_value" "user_audience" {
  name                = "user-audience"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "user-audience"
  # When not set, uses a placeholder that will never match a real token audience.
  # The validate-entra-jwt fragment always references this named value.
  value               = var.user_audience != "" ? var.user_audience : "not-configured"
}
