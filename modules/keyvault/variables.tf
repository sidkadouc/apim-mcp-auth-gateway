# ------------------------------------------------------------------------------
# Key Vault – variables
# ------------------------------------------------------------------------------

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "keyvault_name" { type = string }
variable "tenant_id" { type = string }
variable "tags" { type = map(string) }

variable "apim_principal_id" {
  description = "Object ID of the APIM system-assigned managed identity."
  type        = string
}

variable "obo_client_id" {
  description = "OBO client application (client) ID – stored as secret."
  type        = string
}

variable "obo_client_secret" {
  description = "OBO client secret value."
  type        = string
  sensitive   = true
}
