# ------------------------------------------------------------------------------
# APIM MCP API – variables
# ------------------------------------------------------------------------------

variable "api_management_name" { type = string }
variable "resource_group_name" { type = string }
variable "apim_id" { type = string }

variable "name" {
  description = "Short name for this MCP server (used in URL path and PRM)."
  type        = string
}

variable "display_name" {
  type    = string
  default = ""
}

variable "backend_url" {
  description = "URL of the MCP server backend."
  type        = string
}

variable "backend_audience" {
  description = "Entra audience of the backend (for OBO). Empty for apikey/cert."
  type        = string
  default     = ""
}

variable "required_scope" {
  type    = string
  default = "Mcp.Access"
}

variable "required_role" {
  type    = string
  default = "Mcp.Invoke"
}

variable "auth_mode" {
  description = "obo | client_credentials | apikey | cert"
  type        = string
  default     = "obo"
  validation {
    condition     = contains(["obo", "client_credentials", "apikey", "cert"], var.auth_mode)
    error_message = "auth_mode must be one of: obo, client_credentials, apikey, cert"
  }
}

variable "expose_prm" {
  description = "Create a PRM (RFC 9728) discovery operation for this MCP server."
  type        = bool
  default     = true
}

variable "allowed_groups" {
  description = "List of Entra ID group object IDs allowed to access this MCP server. Empty list = no group check (open to all authenticated users)."
  type        = list(string)
  default     = []
}

variable "product_id" {
  description = "APIM product ID to associate with."
  type        = string
}

variable "gateway_audience" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "obo_client_id" {
  description = "Application (client) ID of the OBO client app (used in PRM scopes_supported)."
  type        = string
  default     = ""
}

variable "prm_api_name" {
  description = "Name of the shared PRM API in APIM."
  type        = string
  default     = "prm"
}
