# ------------------------------------------------------------------------------
# ACA environment – outputs
# ------------------------------------------------------------------------------

output "environment_id" {
  value = azurerm_container_app_environment.main.id
}

output "default_domain" {
  value = azurerm_container_app_environment.main.default_domain
}
