# ==============================================================================
# 01-platform — Heavy infrastructure
#
# Creates: Resource Group, Entra ID apps, APIM service, Key Vault, networking,
#          observability (Log Analytics + App Insights), ACA environment.
#
# Run once per environment by the platform team.
# Does NOT configure APIM policies/fragments — that's 02-configuration.
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment and set your storage account for remote state:
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "<your-storage-account>"
  #   container_name       = "tfstate"
  #   key                  = "01-platform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# ---------- Locals ----------

locals {
  prefix = "${var.project}-${var.environment}"
  tags = merge(var.tags, {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    layer       = "01-platform"
  })

  resource_group_name = "rg-${local.prefix}"
  apim_name           = "apim-${local.prefix}"
  keyvault_name       = substr("kv-${replace(local.prefix, "-", "")}", 0, 24)
  law_name            = "law-${local.prefix}"
  appinsights_name    = "ai-${local.prefix}"
  vnet_name           = "vnet-${local.prefix}"
  aca_env_name        = "cae-${local.prefix}"
}

# ── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

# ── 1. Entra ID — app registrations, scopes, roles, OBO client ───────────────

module "entra" {
  source = "../../modules/entra"

  tenant_id                           = var.tenant_id
  project                             = var.project
  vscode_client_id                    = var.vscode_client_id
  additional_preauthorized_client_ids = var.additional_preauthorized_client_ids
}

# ── 2. Networking ─────────────────────────────────────────────────────────────

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  vnet_name           = local.vnet_name
  tags                = local.tags
}

# ── 3. Observability ──────────────────────────────────────────────────────────

module "observability" {
  source = "../../modules/observability"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  law_name            = local.law_name
  appinsights_name    = local.appinsights_name
  tags                = local.tags
}

# ── 4. APIM service ──────────────────────────────────────────────────────────

module "apim" {
  source = "../../modules/apim"

  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location
  apim_name                       = local.apim_name
  sku                             = var.apim_sku
  publisher_email                 = var.apim_publisher_email
  publisher_name                  = var.apim_publisher_name
  tags                            = local.tags
  appinsights_id                  = module.observability.appinsights_id
  appinsights_instrumentation_key = module.observability.appinsights_instrumentation_key
  tenant_id                       = var.tenant_id
  gateway_audience                = module.entra.gateway_identifier_uri
  user_audience                    = module.entra.obo_client_app_id
}

# ── 5. Key Vault ─────────────────────────────────────────────────────────────

module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  keyvault_name       = local.keyvault_name
  tenant_id           = var.tenant_id
  tags                = local.tags
  apim_principal_id   = module.apim.principal_id
  obo_client_id       = module.entra.obo_client_app_id
  obo_client_secret   = module.entra.obo_client_secret
}

# ── 6. ACA environment ───────────────────────────────────────────────────────

module "aca" {
  source = "../../modules/aca"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  aca_env_name        = local.aca_env_name
  law_id              = module.observability.law_id
  tags                = local.tags
}
