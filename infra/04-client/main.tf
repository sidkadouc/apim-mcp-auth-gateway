# ==============================================================================
# 04-client — Onboard a new client app (PKCE or Client Credentials)
#
# Run per client from Azure DevOps pipeline.
#
# Input modes:
#   A) From 01-platform state: set use_remote_state = true
#   B) Existing env:           set use_remote_state = false + provide variables
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
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
  #   key                  = "04-client-<name>.tfstate"
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

  tenant_id            = var.use_remote_state ? local.p.tenant_id            : var.tenant_id
  subscription_id      = var.use_remote_state ? local.p.subscription_id      : var.subscription_id
  gateway_app_id       = var.use_remote_state ? local.p.gateway_app_id       : var.gateway_app_id
  obo_client_app_id    = var.use_remote_state ? local.p.obo_client_app_id    : var.obo_client_app_id
  mcp_access_scope_id  = var.use_remote_state ? local.p.mcp_access_scope_id  : var.mcp_access_scope_id
  apim_gateway_url     = var.use_remote_state ? local.p.apim_gateway_url     : var.apim_gateway_url
  project_prefix       = var.use_remote_state ? local.p.project              : var.project
}

provider "azuread" {
  tenant_id = local.tenant_id
}

provider "azurerm" {
  features {}
  subscription_id = local.subscription_id
}

# ── Entra data sources ───────────────────────────────────────────────────────

data "azuread_application" "gateway" {
  client_id = local.gateway_app_id
}

data "azuread_service_principal" "gateway" {
  client_id = local.gateway_app_id
}

# ==========================================================================
# PKCE client — pre-authorize existing app on gateway + OBO
# ==========================================================================

resource "azuread_application_pre_authorized" "pkce_on_gateway" {
  count = var.client_type == "pkce" ? 1 : 0

  application_id       = data.azuread_application.gateway.id
  authorized_client_id = var.client_app_id
  permission_ids       = [local.mcp_access_scope_id]
}

data "azuread_application" "obo_client" {
  count     = var.client_type == "pkce" ? 1 : 0
  client_id = local.obo_client_app_id
}

resource "azuread_application_pre_authorized" "pkce_on_obo" {
  count = var.client_type == "pkce" ? 1 : 0

  application_id       = data.azuread_application.obo_client[0].id
  authorized_client_id = var.client_app_id
  permission_ids       = [data.azuread_application.obo_client[0].oauth2_permission_scope_ids["Mcp.Access"]]
}

# ==========================================================================
# CC client — create new service app + assign Mcp.Invoke role
# ==========================================================================

resource "azuread_application" "cc_client" {
  count = var.client_type == "cc" ? 1 : 0

  display_name     = var.client_display_name != "" ? var.client_display_name : "${local.project_prefix}-${var.client_name}"
  sign_in_audience = "AzureADMyOrg"

  required_resource_access {
    resource_app_id = local.gateway_app_id
    resource_access {
      id   = data.azuread_application.gateway.app_role_ids["Mcp.Invoke"]
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "cc_client" {
  count     = var.client_type == "cc" ? 1 : 0
  client_id = azuread_application.cc_client[0].client_id
}

resource "azuread_application_password" "cc_client" {
  count             = var.client_type == "cc" && var.create_secret ? 1 : 0
  application_id    = azuread_application.cc_client[0].id
  display_name      = "${var.client_name}-secret"
  end_date_relative = var.secret_expiry
}

resource "azuread_app_role_assignment" "cc_mcp_invoke" {
  count = var.client_type == "cc" ? 1 : 0

  app_role_id         = data.azuread_application.gateway.app_role_ids["Mcp.Invoke"]
  principal_object_id = azuread_service_principal.cc_client[0].object_id
  resource_object_id  = data.azuread_service_principal.gateway.object_id
}

# ==========================================================================
# Existing CC client — assign Mcp.Invoke role to existing service principal
# ==========================================================================

data "azuread_service_principal" "existing_cc" {
  count     = var.client_type == "existing_cc" ? 1 : 0
  client_id = var.client_app_id
}

resource "azuread_app_role_assignment" "existing_cc_mcp_invoke" {
  count = var.client_type == "existing_cc" ? 1 : 0

  app_role_id         = data.azuread_application.gateway.app_role_ids["Mcp.Invoke"]
  principal_object_id = data.azuread_service_principal.existing_cc[0].object_id
  resource_object_id  = data.azuread_service_principal.gateway.object_id
}
