# ------------------------------------------------------------------------------
# ACA container app – variables
# ------------------------------------------------------------------------------

variable "resource_group_name" { type = string }
variable "name" { type = string }
variable "environment_id" { type = string }
variable "tags" { type = map(string) }

variable "image" {
  description = "Container image reference."
  type        = string
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 0.25
}

variable "memory" {
  type    = string
  default = "0.5Gi"
}

variable "env_vars" {
  description = "Map of environment variables."
  type        = map(string)
  default     = {}
}

variable "external_ingress" {
  type    = bool
  default = true
}

variable "min_replicas" {
  type    = number
  default = 0
}

variable "max_replicas" {
  type    = number
  default = 2
}

variable "registry_server" {
  description = "Container registry server (e.g., myacr.azurecr.io)."
  type        = string
  default     = ""
}

variable "registry_username" {
  type      = string
  default   = ""
  sensitive = true
}

variable "registry_password" {
  type      = string
  default   = ""
  sensitive = true
}
