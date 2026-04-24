# ------------------------------------------------------------------------------
# APIM – variables
# ------------------------------------------------------------------------------

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "apim_name" { type = string }
variable "sku" { type = string }
variable "publisher_email" { type = string }
variable "publisher_name" { type = string }
variable "tags" { type = map(string) }

variable "appinsights_id" { type = string }
variable "appinsights_instrumentation_key" {
  type      = string
  sensitive = true
}

variable "tenant_id" { type = string }
variable "gateway_audience" { type = string }
variable "user_audience" {
  description = "Application (client) ID of the OBO client app. Interactive users (VS Code, PKCE) get tokens with this as the audience. Set to empty string to skip."
  type        = string
  default     = ""
}
