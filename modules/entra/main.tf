# ------------------------------------------------------------------------------
# Entra ID – app registrations, scopes, roles, pre-authorization
# ------------------------------------------------------------------------------

data "azuread_client_config" "current" {}

# ---------- Stable scope IDs ----------
# obo_access_scope_id: created manually during initial PoC bootstrap;
# hardcoded here so VS Code pre-authorizations (tied to this UUID) remain stable.
locals {
  obo_access_scope_id = "fc299da2-d33e-4c3d-a399-add1295dfd93"
}

# ---------- Stable UUIDs for scopes / roles ----------

resource "random_uuid" "mcp_access_scope" {}
resource "random_uuid" "mcp_invoke_role" {}
resource "random_uuid" "backend_access_scope" {}
resource "random_uuid" "backend_invoke_role" {}

# ==========================================================================
# 1. apim-ai-gateway  (resource app – audience for inbound client tokens)
# ==========================================================================

resource "azuread_application" "gateway" {
  display_name     = "${var.project}-apim-gateway"
  sign_in_audience = "AzureADMyOrg"

  api {
    requested_access_token_version = 2
    # Delegated scope – used by interactive clients (VS Code, web apps)
    oauth2_permission_scope {
      id                         = random_uuid.mcp_access_scope.result
      admin_consent_description  = "Access MCP servers through the AI Gateway on behalf of the signed-in user"
      admin_consent_display_name = "Access MCP servers"
      user_consent_description   = "Access MCP servers on your behalf"
      user_consent_display_name  = "Access MCP servers"
      value                      = "Mcp.Access"
      type                       = "User"
      enabled                    = true
    }
  }

  # Application role
  app_role {
    id                   = random_uuid.mcp_invoke_role.result
    allowed_member_types = ["Application"]
    display_name         = "MCP Invoke"
    description          = "Allows the application to invoke MCP servers (machine-to-machine)"
    value                = "Mcp.Invoke"
    enabled              = true
  }

  # Optional: emit group object IDs in access tokens for group-based authZ
  dynamic "optional_claims" {
    for_each = var.emit_groups_claim ? [1] : []
    content {
      access_token {
        name = "groups"
      }
      id_token {
        name = "groups"
      }
    }
  }

  group_membership_claims = var.emit_groups_claim ? ["SecurityGroup"] : []

  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_application_identifier_uri" "gateway" {
  application_id = azuread_application.gateway.id
  identifier_uri = "api://${azuread_application.gateway.client_id}"
}

resource "azuread_service_principal" "gateway" {
  client_id = azuread_application.gateway.client_id
}

# ---------- Pre-authorize VS Code ----------

resource "azuread_application_pre_authorized" "vscode" {
  application_id       = azuread_application.gateway.id
  authorized_client_id = var.vscode_client_id
  permission_ids       = [random_uuid.mcp_access_scope.result]
}

# ---------- Pre-authorize additional clients ----------

resource "azuread_application_pre_authorized" "extra" {
  for_each             = toset(var.additional_preauthorized_client_ids)
  application_id       = azuread_application.gateway.id
  authorized_client_id = each.value
  permission_ids       = [random_uuid.mcp_access_scope.result]
}

# ==========================================================================
# 2. mcp-backend  (resource app – audience for OBO downstream tokens)
# ==========================================================================

resource "azuread_application" "backend" {
  display_name     = "${var.project}-mcp-backend"
  sign_in_audience = "AzureADMyOrg"

  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      id                         = random_uuid.backend_access_scope.result
      admin_consent_description  = "Access the MCP backend on behalf of the signed-in user"
      admin_consent_display_name = "Access MCP backend"
      user_consent_description   = "Access the MCP backend on your behalf"
      user_consent_display_name  = "Access MCP backend"
      value                      = "Backend.Access"
      type                       = "User"
      enabled                    = true
    }
  }

  app_role {
    id                   = random_uuid.backend_invoke_role.result
    allowed_member_types = ["Application"]
    display_name         = "Backend Invoke"
    description          = "Allows the application to call the MCP backend (machine-to-machine)"
    value                = "Backend.Invoke"
    enabled              = true
  }

  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_application_identifier_uri" "backend" {
  application_id = azuread_application.backend.id
  identifier_uri = "api://${azuread_application.backend.client_id}"
}

resource "azuread_service_principal" "backend" {
  client_id = azuread_application.backend.client_id
}

# ==========================================================================
# 3. apim-obo-client  (confidential client used by APIM for OBO exchange)
# ==========================================================================

resource "azuread_application" "obo_client" {
  display_name     = "${var.project}-apim-obo-client"
  sign_in_audience = "AzureADMyOrg"

  # Expose a delegated scope so VS Code can request a token with this app as
  # audience.  APIM validates that audience then performs OBO to the backend.
  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      id                         = local.obo_access_scope_id
      admin_consent_description  = "Access MCP servers via the APIM AI Gateway on behalf of the signed-in user"
      admin_consent_display_name = "Access MCP servers (via gateway)"
      user_consent_description   = "Access MCP servers on your behalf"
      user_consent_display_name  = "Access MCP servers"
      value                      = "Mcp.Access"
      type                       = "User"
      enabled                    = true
    }
  }

  # The OBO client needs delegated permission on the backend
  required_resource_access {
    resource_app_id = azuread_application.backend.client_id

    resource_access {
      id   = random_uuid.backend_access_scope.result
      type = "Scope" # delegated
    }
  }

  # Also request User.Read on Graph for profile propagation
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_service_principal" "obo_client" {
  client_id = azuread_application.obo_client.client_id
}

# Expose the OBO client app under its own identifier URI so VS Code can request
# a token scoped to api://<obo_client_id>/Mcp.Access.
resource "azuread_application_identifier_uri" "obo_client" {
  application_id = azuread_application.obo_client.id
  identifier_uri = "api://${azuread_application.obo_client.client_id}"
}

# Pre-authorize VS Code first-party app on the OBO client resource
resource "azuread_application_pre_authorized" "vscode_on_obo" {
  application_id       = azuread_application.obo_client.id
  authorized_client_id = var.vscode_client_id
  permission_ids       = [local.obo_access_scope_id]
}

# Pre-authorize additional clients (e.g. VS Code custom app) on the OBO client resource
resource "azuread_application_pre_authorized" "extra_on_obo" {
  for_each             = toset(var.additional_preauthorized_client_ids)
  application_id       = azuread_application.obo_client.id
  authorized_client_id = each.value
  permission_ids       = [local.obo_access_scope_id]
}

resource "azuread_application_password" "obo_client" {
  application_id = azuread_application.obo_client.id
  display_name   = "apim-obo-secret"
  end_date_relative = "8760h"
}

# ---------- Pre-authorize the OBO client on the gateway ----------
# (so APIM can do OBO with tokens whose audience is the gateway)

resource "azuread_application_pre_authorized" "obo_on_gateway" {
  application_id       = azuread_application.gateway.id
  authorized_client_id = azuread_application.obo_client.client_id
  permission_ids       = [random_uuid.mcp_access_scope.result]
}

# ---------- Admin consent for the OBO client on the backend ----------

resource "azuread_service_principal_delegated_permission_grant" "obo_to_backend" {
  service_principal_object_id          = azuread_service_principal.obo_client.object_id
  resource_service_principal_object_id = azuread_service_principal.backend.object_id
  claim_values                         = ["Backend.Access"]
}

# ==========================================================================
# 4. test-service-app  (CC test client – gets Mcp.Invoke role on gateway)
# ==========================================================================

resource "azuread_application" "test_service" {
  display_name     = "${var.project}-test-service-app"
  sign_in_audience = "AzureADMyOrg"

  # Request app-level permission (Mcp.Invoke role) on the gateway
  required_resource_access {
    resource_app_id = azuread_application.gateway.client_id

    resource_access {
      id   = random_uuid.mcp_invoke_role.result
      type = "Role" # application (CC)
    }
  }
}

resource "azuread_service_principal" "test_service" {
  client_id = azuread_application.test_service.client_id
}

resource "azuread_application_password" "test_service" {
  application_id = azuread_application.test_service.id
  display_name   = "test-service-secret"
  end_date_relative = "2160h"
}

# ---------- Assign Mcp.Invoke app role to the test service SP ----------

resource "azuread_app_role_assignment" "test_service_mcp_invoke" {
  app_role_id         = random_uuid.mcp_invoke_role.result
  principal_object_id = azuread_service_principal.test_service.object_id
  resource_object_id  = azuread_service_principal.gateway.object_id
}

# ---------- Also assign Backend.Invoke to the OBO client (for CC→backend) ----------

resource "azuread_app_role_assignment" "obo_client_backend_invoke" {
  app_role_id         = random_uuid.backend_invoke_role.result
  principal_object_id = azuread_service_principal.obo_client.object_id
  resource_object_id  = azuread_service_principal.backend.object_id
}
