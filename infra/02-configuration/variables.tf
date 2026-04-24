# ------------------------------------------------------------------------------
# 02-configuration — variables
# ------------------------------------------------------------------------------

# ── Input mode ───────────────────────────────────────────────────────────────

variable "use_remote_state" {
  description = "true = read from 01-platform state; false = provide variables directly."
  type        = bool
  default     = true
}

# ── Remote state config (when use_remote_state = true) ───────────────────────

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
  description = "Azure subscription ID (required when use_remote_state = false)."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Entra ID tenant ID (required when use_remote_state = false)."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Resource group containing APIM (required when use_remote_state = false)."
  type        = string
  default     = ""
}

variable "apim_id" {
  description = "ARM resource ID of existing APIM (required when use_remote_state = false)."
  type        = string
  default     = ""
}

variable "apim_name" {
  description = "Name of existing APIM instance (required when use_remote_state = false)."
  type        = string
  default     = ""
}

variable "obo_client_app_id" {
  description = "OBO client application (client) ID (required when use_remote_state = false)."
  type        = string
  default     = ""
}

variable "keyvault_obo_client_id_uri" {
  description = "Key Vault secret URI for OBO client ID (required when use_remote_state = false)."
  type        = string
  default     = ""
}

variable "keyvault_obo_client_secret_uri" {
  description = "Key Vault secret URI for OBO client secret (required when use_remote_state = false)."
  type        = string
  default     = ""
}
