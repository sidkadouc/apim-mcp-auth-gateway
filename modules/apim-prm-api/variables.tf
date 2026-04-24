# ------------------------------------------------------------------------------
# APIM PRM API – variables
# ------------------------------------------------------------------------------

variable "apim_id" {
  description = "ARM resource ID of the APIM service (parent for azapi resources)."
  type        = string
}

variable "apim_name" {
  description = "Name of the APIM service instance (used in PRM resource URL)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name (informational; parent_id drives placement)."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID – embedded in authorization_servers in PRM response."
  type        = string
}

variable "obo_client_id" {
  description = "OBO client application (client) ID – embedded in scopes_supported in PRM response."
  type        = string
}
