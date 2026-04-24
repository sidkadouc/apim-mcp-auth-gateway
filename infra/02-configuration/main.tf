# ==============================================================================
# 02-configuration — APIM policies, fragments, named values, PRM API
#
# Configures an APIM instance with the AI Gateway policy framework.
# Can run against APIM created by 01-platform (via remote state) or against
# any existing APIM instance (by setting variables directly).
#
# Input modes:
#   A) From 01-platform state: set use_remote_state = true (default)
#   B) Existing APIM:          set use_remote_state = false + provide variables
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }

  # Uncomment for remote state:
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "<your-storage-account>"
  #   container_name       = "tfstate"
  #   key                  = "02-configuration.tfstate"
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

# ── Resolve inputs: remote state or direct variables ─────────────────────────

locals {
  p = var.use_remote_state ? data.terraform_remote_state.platform[0].outputs : {}

  subscription_id     = var.use_remote_state ? local.p.subscription_id     : var.subscription_id
  tenant_id           = var.use_remote_state ? local.p.tenant_id           : var.tenant_id
  resource_group_name = var.use_remote_state ? local.p.resource_group_name : var.resource_group_name
  apim_id             = var.use_remote_state ? local.p.apim_id             : var.apim_id
  apim_name           = var.use_remote_state ? local.p.apim_name           : var.apim_name
  obo_client_app_id   = var.use_remote_state ? local.p.obo_client_app_id   : var.obo_client_app_id

  keyvault_obo_client_id_uri     = var.use_remote_state ? local.p.keyvault_obo_client_id_uri     : var.keyvault_obo_client_id_uri
  keyvault_obo_client_secret_uri = var.use_remote_state ? local.p.keyvault_obo_client_secret_uri : var.keyvault_obo_client_secret_uri
}

provider "azurerm" {
  features {}
  subscription_id = local.subscription_id
}

provider "azapi" {
  subscription_id = local.subscription_id
  tenant_id       = local.tenant_id
}

# ==========================================================================
# 1. KV-backed named values (OBO client credentials)
# ==========================================================================

resource "azurerm_api_management_named_value" "obo_client_id" {
  name                = "obo-client-id"
  api_management_name = local.apim_name
  resource_group_name = local.resource_group_name
  display_name        = "obo-client-id"
  secret              = true

  value_from_key_vault {
    secret_id = local.keyvault_obo_client_id_uri
  }
}

resource "azurerm_api_management_named_value" "obo_client_secret" {
  name                = "obo-client-secret"
  api_management_name = local.apim_name
  resource_group_name = local.resource_group_name
  display_name        = "obo-client-secret"
  secret              = true

  value_from_key_vault {
    secret_id = local.keyvault_obo_client_secret_uri
  }
}

# ==========================================================================
# 2. Policy fragments (all 12)
# ==========================================================================

locals {
  policy_fragments = {
    "correlation-id"              = "Adds x-correlation-id for distributed tracing"
    "cors"                        = "Shared CORS configuration"
    "validate-entra-jwt"          = "Validates Entra ID v2.0 JWT + sets auth context vars"
    "require-scope"               = "Checks delegated scope (403 on miss)"
    "require-app-role"            = "Checks application role (403 on miss)"
    "require-group"               = "Checks user group membership (optional, 403 on miss)"
    "rate-limit-by-user"          = "Rate-limits by user OID or app client ID"
    "obo-exchange"                = "OBO token exchange for user delegation (cached)"
    "client-credentials-exchange" = "Client credentials token acquisition (cached)"
    "attach-backend-bearer"       = "Sets Authorization: Bearer on backend request"
    "attach-backend-apikey"       = "Sets x-api-key header from named value"
    "attach-backend-cert"         = "mTLS client certificate authentication"
    "mcp-usage-log"               = "Parses JSON-RPC and logs MCP usage to App Insights"
  }
}

module "fragment" {
  source   = "../../modules/apim-fragment"
  for_each = local.policy_fragments

  api_management_id = local.apim_id
  name              = each.key
  description       = each.value
  policy_file       = "${path.root}/../../policies/fragments/${each.key}.xml"

  depends_on = [
    azurerm_api_management_named_value.obo_client_id,
    azurerm_api_management_named_value.obo_client_secret,
  ]
}

# ==========================================================================
# 3. PRM API — RFC 9728 discovery + OIDC proxy
# ==========================================================================

module "prm_api" {
  source = "../../modules/apim-prm-api"

  apim_id             = local.apim_id
  apim_name           = local.apim_name
  resource_group_name = local.resource_group_name
  tenant_id           = local.tenant_id
  obo_client_id       = local.obo_client_app_id
}
