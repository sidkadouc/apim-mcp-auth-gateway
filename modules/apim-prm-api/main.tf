# ------------------------------------------------------------------------------
# APIM PRM API – Protected Resource Metadata (RFC 9728)
#
# Uses azapi because azurerm_api_management_api_operation rejects URL templates
# containing ".well-known" path segments.
#
# Manages:
#   • "prm" API  (path = "", subscriptionRequired = false)
#   • prm-mcp-demo  operation + policy  (PRM JSON for MCP Demo Server)
#   • prm-rest-demo operation + policy  (PRM JSON for REST API Demo)
#   • oauth-as-meta  operation + policy  (proxies to Entra OIDC metadata)
#   • oidc-config    operation + policy  (proxies to Entra OIDC metadata)
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

locals {
  # Servers that get a PRM discovery endpoint.
  prm_servers = {
    "mcp-demo"  = "mcp-demo"
    "rest-demo" = "rest-demo"
  }

  # Shared OIDC proxy policy used for oauth-as-meta and oidc-config.
  oidc_proxy_policy = <<-XML
    <policies>
      <inbound>
        <base />
        <send-request mode="new" response-variable-name="oidc" timeout="10" ignore-error="false">
          <set-url>https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration</set-url>
          <set-method>GET</set-method>
        </send-request>
        <return-response response-variable-name="oidc" />
      </inbound>
      <backend><base /></backend>
      <outbound><base /></outbound>
      <on-error><base /></on-error>
    </policies>
  XML
}

# ==========================================================================
# PRM Discovery API  (empty path so all .well-known/* routes match)
# ==========================================================================

resource "azapi_resource" "prm_api" {
  type      = "Microsoft.ApiManagement/service/apis@2023-05-01-preview"
  name      = "prm"
  parent_id = var.apim_id

  body = {
    properties = {
      displayName          = "PRM Discovery"
      path                 = ""
      protocols            = ["https"]
      subscriptionRequired = false
    }
  }
}

# ==========================================================================
# PRM operations – /.well-known/oauth-protected-resource/{name}
# ==========================================================================

resource "azapi_resource" "prm_op" {
  for_each  = local.prm_servers
  type      = "Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview"
  name      = "prm-${each.key}"
  parent_id = azapi_resource.prm_api.id

  body = {
    properties = {
      displayName = "PRM Discovery (${each.key})"
      method      = "GET"
      urlTemplate = "/.well-known/oauth-protected-resource/${each.value}"
      responses   = []
    }
  }
}

resource "azapi_resource" "prm_policy" {
  for_each  = local.prm_servers
  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview"
  name      = "policy"
  parent_id = azapi_resource.prm_op[each.key].id

  body = {
    properties = {
      format = "rawxml"
      value = templatefile("${path.module}/../apim-mcp-api/prm-policy.tftpl.xml", {
        tenant_id       = var.tenant_id
        apim_name       = var.apim_name
        mcp_server_name = each.key
        obo_client_id   = var.obo_client_id
      })
    }
  }

  lifecycle {
    # Azure normalizes XML whitespace on storage; suppress perpetual diff.
    ignore_changes = [body]
  }
}

# ==========================================================================
# OAuth AS Metadata – proxies to Entra OIDC endpoint
# ==========================================================================

resource "azapi_resource" "oauth_as_meta_op" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview"
  name      = "oauth-as-meta"
  parent_id = azapi_resource.prm_api.id

  body = {
    properties = {
      displayName = "OAuth AS Metadata"
      method      = "GET"
      urlTemplate = "/.well-known/oauth-authorization-server"
      responses   = []
    }
  }
}

resource "azapi_resource" "oauth_as_meta_policy" {
  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview"
  name      = "policy"
  parent_id = azapi_resource.oauth_as_meta_op.id

  body = {
    properties = {
      format = "rawxml"
      value  = local.oidc_proxy_policy
    }
  }

  lifecycle {
    ignore_changes = [body]
  }
}

# ==========================================================================
# OIDC Configuration – proxies to Entra OIDC endpoint
# ==========================================================================

resource "azapi_resource" "oidc_config_op" {
  type      = "Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview"
  name      = "oidc-config"
  parent_id = azapi_resource.prm_api.id

  body = {
    properties = {
      displayName = "OIDC Configuration"
      method      = "GET"
      urlTemplate = "/.well-known/openid-configuration"
      responses   = []
    }
  }
}

resource "azapi_resource" "oidc_config_policy" {
  type      = "Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview"
  name      = "policy"
  parent_id = azapi_resource.oidc_config_op.id

  body = {
    properties = {
      format = "rawxml"
      value  = local.oidc_proxy_policy
    }
  }

  lifecycle {
    ignore_changes = [body]
  }
}
