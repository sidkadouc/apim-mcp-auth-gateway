# ------------------------------------------------------------------------------
# 01-platform — variables
# ------------------------------------------------------------------------------

variable "project" {
  description = "Short project name (naming prefix)."
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "tenant_id" {
  description = "Entra ID tenant ID."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "apim_publisher_email" {
  description = "APIM publisher email."
  type        = string
}

variable "apim_publisher_name" {
  type    = string
  default = "AI Platform Team"
}

variable "apim_sku" {
  type    = string
  default = "Developer_1"
}

variable "vscode_client_id" {
  type    = string
  default = "aebc6443-996d-45c2-90f0-388ff96faa56"
}

variable "additional_preauthorized_client_ids" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
