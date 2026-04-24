# ==============================================================================
# 03-server — Register an MCP server in APIM
#
# Creates: APIM API + composed policy + PRM operation.
# The MCP server itself is deployed separately (ACA, AKS, VM, external).
# This layer only configures the APIM gateway to route and secure traffic.
#
# Input modes:
#   A) From 01-platform state: set use_remote_state = true
#   B) Existing APIM:          set use_remote_state = false + provide variables
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Uncomment for remote state:
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "<your-storage-account>"
  #   container_name       = "tfstate"
  #   key                  = "03-server-<name>.tfstate"
  # }
}

# ── Optional: read 01-platform state ─────────────────────────────────────────

data "terraform_remote_state" "platform" {
  count   = var.use_remote_state ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = var.platform_state_key
  }
}

# ── Resolve inputs ───────────────────────────────────────────────────────────

locals {
  p = var.use_remote_state ? data.terraform_remote_state.platform[0].outputs : {}

  subscription_id        = var.use_remote_state ? local.p.subscription_id        : var.subscription_id
  tenant_id              = var.use_remote_state ? local.p.tenant_id              : var.tenant_id
  resource_group_name    = var.use_remote_state ? local.p.resource_group_name    : var.resource_group_name
  apim_id                = var.use_remote_state ? local.p.apim_id                : var.apim_id
  apim_name              = var.use_remote_state ? local.p.apim_name              : var.apim_name
  apim_gateway_url       = var.use_remote_state ? local.p.apim_gateway_url       : var.apim_gateway_url
  apim_product_id        = var.use_remote_state ? local.p.apim_product_id        : var.apim_product_id
  gateway_identifier_uri = var.use_remote_state ? local.p.gateway_identifier_uri : var.gateway_identifier_uri
  backend_identifier_uri = var.use_remote_state ? local.p.backend_identifier_uri : var.backend_identifier_uri
  obo_client_app_id      = var.use_remote_state ? local.p.obo_client_app_id      : var.obo_client_app_id
}

provider "azurerm" {
  features {}
  subscription_id = local.subscription_id
}

# ==========================================================================
# APIM MCP API + composed policy
# ==========================================================================

module "mcp_api" {
  source = "../../modules/apim-mcp-api"

  api_management_name = local.apim_name
  resource_group_name = local.resource_group_name
  apim_id             = local.apim_id

  name             = var.name
  display_name     = var.display_name
  backend_url      = var.backend_url
  backend_audience = var.backend_audience != "" ? var.backend_audience : local.backend_identifier_uri
  required_scope   = var.required_scope
  required_role    = var.required_role
  auth_mode        = var.auth_mode
  expose_prm       = var.expose_prm
  allowed_groups   = var.allowed_groups
  product_id       = local.apim_product_id
  gateway_audience = local.gateway_identifier_uri
  tenant_id        = local.tenant_id
  obo_client_id    = local.obo_client_app_id
}
