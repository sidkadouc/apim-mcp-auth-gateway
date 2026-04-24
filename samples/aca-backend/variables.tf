# ------------------------------------------------------------------------------
# Sample ACA backend — variables
# ------------------------------------------------------------------------------

variable "use_remote_state" {
  type    = bool
  default = true
}

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

# Direct variables (when use_remote_state = false)
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

variable "backend_app_id" {
  type    = string
  default = ""
}

variable "aca_environment_id" {
  type    = string
  default = ""
}

variable "project" {
  type    = string
  default = ""
}

# Container images
variable "mcp_sample_image" {
  description = "Container image for the sample MCP server."
  type        = string
  default     = "mcr.microsoft.com/dotnet/samples:aspnetapp"
}

variable "rest_sample_image" {
  description = "Container image for the sample REST API."
  type        = string
  default     = "mcr.microsoft.com/dotnet/samples:aspnetapp"
}

variable "acr_login_server" {
  type    = string
  default = ""
}

variable "acr_username" {
  type      = string
  default   = ""
  sensitive = true
}

variable "acr_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
