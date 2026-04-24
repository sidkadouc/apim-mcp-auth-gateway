# ------------------------------------------------------------------------------
# Observability – variables
# ------------------------------------------------------------------------------

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "law_name" { type = string }
variable "appinsights_name" { type = string }
variable "tags" { type = map(string) }
