# ------------------------------------------------------------------------------
# Networking – outputs
# ------------------------------------------------------------------------------

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "apim_subnet_id" {
  value = azurerm_subnet.apim.id
}

output "aca_subnet_id" {
  value = azurerm_subnet.aca.id
}
