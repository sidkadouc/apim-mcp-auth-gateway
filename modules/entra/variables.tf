# ------------------------------------------------------------------------------
# Entra ID – variables
# ------------------------------------------------------------------------------

variable "tenant_id" {
  type = string
}

variable "project" {
  type = string
}

variable "gateway_identifier_uri" {
  description = "Identifier URI for the APIM gateway app."
  type        = string
  default     = "api://apim-ai-gateway"
}

variable "backend_identifier_uri" {
  description = "Identifier URI for the MCP backend app."
  type        = string
  default     = "api://mcp-backend"
}

variable "vscode_client_id" {
  description = "VS Code built-in OAuth client ID to pre-authorize."
  type        = string
}

variable "additional_preauthorized_client_ids" {
  description = "Extra client IDs to pre-authorize on the gateway."
  type        = list(string)
  default     = []
}

variable "emit_groups_claim" {
  description = "If true, configures the gateway app to emit group object IDs in access tokens. Required for group-based authorization at the APIM level."
  type        = bool
  default     = false
}
