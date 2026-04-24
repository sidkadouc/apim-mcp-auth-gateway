# ------------------------------------------------------------------------------
# 04-client — variables
# ------------------------------------------------------------------------------

# ── Input mode ───────────────────────────────────────────────────────────────

variable "use_remote_state" {
  type    = bool
  default = true
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

variable "tenant_id" {
  type    = string
  default = ""
}

variable "subscription_id" {
  type    = string
  default = ""
}

variable "gateway_app_id" {
  description = "Gateway app client ID."
  type        = string
  default     = ""
}

variable "obo_client_app_id" {
  type    = string
  default = ""
}

variable "mcp_access_scope_id" {
  description = "UUID of Mcp.Access scope."
  type        = string
  default     = ""
}

variable "apim_gateway_url" {
  type    = string
  default = ""
}

variable "project" {
  type    = string
  default = ""
}

# ── Client config ────────────────────────────────────────────────────────────

variable "client_type" {
  description = "pkce = interactive app, cc = new service app, existing_cc = existing service."
  type        = string
  validation {
    condition     = contains(["pkce", "cc", "existing_cc"], var.client_type)
    error_message = "Must be: pkce, cc, or existing_cc"
  }
}

variable "client_name" {
  description = "Short name for the client."
  type        = string
}

variable "client_display_name" {
  type    = string
  default = ""
}

variable "client_app_id" {
  description = "Existing app client ID (required for pkce and existing_cc)."
  type        = string
  default     = ""
}

variable "create_secret" {
  type    = bool
  default = true
}

variable "secret_expiry" {
  type    = string
  default = "8760h"
}
