# ------------------------------------------------------------------------------
# Networking – variables
# ------------------------------------------------------------------------------

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "tags" { type = map(string) }

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "apim_subnet_prefix" {
  type    = string
  default = "10.0.1.0/24"
}

variable "aca_subnet_prefix" {
  type    = string
  default = "10.0.16.0/20"
}
