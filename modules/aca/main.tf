# ------------------------------------------------------------------------------
# ACA environment
# ------------------------------------------------------------------------------

resource "azurerm_container_app_environment" "main" {
  name                       = var.aca_env_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.law_id
  tags                       = var.tags
}
