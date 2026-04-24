# ------------------------------------------------------------------------------
# ACA environment – variables
# ------------------------------------------------------------------------------

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "aca_env_name" { type = string }
variable "law_id" { type = string }
variable "tags" { type = map(string) }
