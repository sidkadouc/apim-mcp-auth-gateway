# ------------------------------------------------------------------------------
# 03-server — variables
# ------------------------------------------------------------------------------

# ── Input mode ───────────────────────────────────────────────────────────────

variable "use_remote_state" {
  description = "true = read from 01-platform state; false = provide variables directly."
  type        = bool
  default     = true
}

# ── Remote state config ──────────────────────────────────────────────────────

variable "state_resource_group_name" {
  type    = string
  default = "rg-terraform-state"
}

variable "state_storage_account_name" {
  type    = string
  default = ""
}

variable "state_container_name" {
  type    = string
  default = "tfstate"
}

variable "platform_state_key" {
  type    = string
  default = "01-platform.tfstate"
}

# ── Direct variables (when use_remote_state = false) ─────────────────────────

variable "subscription_id" {
  type    = string
  default = ""
}

variable "tenant_id" {
  type    = string
  default = ""
}

variable "resource_group_name" {
  type    = string
  default = ""
}

variable "apim_id" {
  type    = string
  default = ""
}

variable "apim_name" {
  type    = string
  default = ""
}

variable "apim_gateway_url" {
  type    = string
  default = ""
}

variable "apim_product_id" {
  type    = string
  default = ""
}

variable "gateway_identifier_uri" {
  type    = string
  default = ""
}

variable "backend_identifier_uri" {
  type    = string
  default = ""
}

variable "obo_client_app_id" {
  type    = string
  default = ""
}

# ── MCP server config ───────────────────────────────────────────────────────

variable "name" {
  description = "Short name for this MCP server (URL path: /mcp/<name>/)."
  type        = string
}

variable "display_name" {
  type    = string
  default = ""
}

variable "backend_url" {
  description = "Full URL of the MCP server backend (e.g., https://my-server.azurecontainerapps.io/mcp). The server must already be deployed."
  type        = string
}

variable "backend_audience" {
  description = "Entra audience the backend validates. If empty, uses the shared backend app from the platform layer."
  type        = string
  default     = ""
}

variable "auth_mode" {
  type    = string
  default = "obo"
  validation {
    condition     = contains(["obo", "client_credentials", "apikey", "cert"], var.auth_mode)
    error_message = "Must be: obo, client_credentials, apikey, or cert"
  }
}

variable "required_scope" {
  type    = string
  default = "Mcp.Access"
}

variable "required_role" {
  type    = string
  default = "Mcp.Invoke"
}

variable "expose_prm" {
  type    = bool
  default = true
}

variable "allowed_groups" {
  description = "List of Entra group object IDs allowed to access this server. Empty = no group check."
  type        = list(string)
  default     = []
}
