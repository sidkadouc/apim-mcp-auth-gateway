# ------------------------------------------------------------------------------
# APIM policy fragment – generic module (one fragment per call)
# ------------------------------------------------------------------------------

variable "api_management_id" { type = string }
variable "name" { type = string }
variable "description" { type = string }
variable "policy_file" { type = string }

resource "azurerm_api_management_policy_fragment" "this" {
  api_management_id = var.api_management_id
  name              = var.name
  description       = var.description
  format            = "rawxml"
  value             = file(var.policy_file)
}

output "fragment_id" {
  value = azurerm_api_management_policy_fragment.this.name
}
