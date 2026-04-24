# ==============================================================================
# Sample: Deploy MCP server and REST API to Azure Container Apps
#
# This is a DEMO deployment for the sample apps in src/.
# In production, teams deploy their own backends independently.
# After deployment, use infra/03-server to register the backend in APIM.
#
# Reads platform state for ACA environment ID and Entra backend app ID.
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
  #   key                  = "sample-aca-backend.tfstate"
  # }
}

# ── Read 01-platform state ───────────────────────────────────────────────────

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

locals {
  p = var.use_remote_state ? data.terraform_remote_state.platform[0].outputs : {}

  subscription_id     = var.use_remote_state ? local.p.subscription_id     : var.subscription_id
  tenant_id           = var.use_remote_state ? local.p.tenant_id           : var.tenant_id
  resource_group_name = var.use_remote_state ? local.p.resource_group_name : var.resource_group_name
  backend_app_id      = var.use_remote_state ? local.p.backend_app_id      : var.backend_app_id
  aca_environment_id  = var.use_remote_state ? local.p.aca_environment_id  : var.aca_environment_id
  project             = var.use_remote_state ? local.p.project              : var.project
}

provider "azurerm" {
  features {}
  subscription_id = local.subscription_id
}

# ── Sample MCP Server ────────────────────────────────────────────────────────

module "mcp_server" {
  source = "../../modules/aca/app"

  resource_group_name = local.resource_group_name
  name                = "ca-${local.project}-mcp-server"
  environment_id      = local.aca_environment_id
  image               = var.mcp_sample_image
  target_port         = 8080
  tags                = var.tags
  registry_server     = var.acr_login_server
  registry_username   = var.acr_username
  registry_password   = var.acr_password

  env_vars = {
    "AzureAd__Instance" = "https://login.microsoftonline.com/"
    "AzureAd__TenantId" = local.tenant_id
    "AzureAd__ClientId" = local.backend_app_id
    "AzureAd__Audience" = local.backend_app_id
  }
}

# ── Sample REST API ──────────────────────────────────────────────────────────

module "rest_api" {
  source = "../../modules/aca/app"

  resource_group_name = local.resource_group_name
  name                = "ca-${local.project}-rest-api"
  environment_id      = local.aca_environment_id
  image               = var.rest_sample_image
  target_port         = 8080
  tags                = var.tags
  registry_server     = var.acr_login_server
  registry_username   = var.acr_username
  registry_password   = var.acr_password

  env_vars = {
    "AzureAd__Instance" = "https://login.microsoftonline.com/"
    "AzureAd__TenantId" = local.tenant_id
    "AzureAd__ClientId" = local.backend_app_id
    "AzureAd__Audience" = local.backend_app_id
  }
}
