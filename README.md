# APIM AI Gateway for MCP Servers

## The problem

Organizations adopting MCP face several challenges when moving from a single server prototype to production:

- **Multiple servers, one gateway.** Each team builds its own MCP server. Without a central gateway, every server must independently implement authentication, rate limiting, usage tracking, and client discovery. This leads to inconsistent security posture and duplicated effort.
- **Multiple auth methods.** Some backends use OAuth bearer tokens, others use API keys, others use client certificates. Clients should not need to know about backend auth -- they should authenticate once against the gateway.
- **User identity preservation.** When an interactive user (VS Code, web app) calls an MCP server, the backend often needs to know who the user is for authorization and data filtering. Simply forwarding the client token breaks audience validation. The gateway must exchange tokens (OBO) to preserve user identity end-to-end.
- **Client onboarding at scale.** Adding a new VS Code extension, web app, or service account should not require changes to every MCP server. Client registration and authorization should be centralized.
- **Zero-config clients.** The MCP authorization spec (2025-11-25) mandates Protected Resource Metadata (RFC 9728) so clients can auto-discover how to authenticate. Clients should only need a URL.

## The solution

This project uses Azure API Management as a centralized AI Gateway that sits in front of all MCP servers and solves these problems with reusable Terraform modules and APIM policy fragments:

- One gateway, many servers. Each MCP server is registered in APIM with a single Terraform apply. APIM handles JWT validation, scope/role checks, rate limiting, and usage logging uniformly.
- Backend auth translation. APIM converts the inbound Entra ID token into whatever the backend expects (OBO bearer, client credentials bearer, API key, or mTLS), so backends stay simple.
- User delegation via OBO. For interactive users, APIM exchanges the user's token for a backend-scoped token that carries the user's identity (oid, upn, groups). The backend validates one audience and sees the real user.
- Centralized client onboarding. Adding a new client (VS Code, web app, service) is a Terraform apply that pre-authorizes the app or assigns a role. No backend changes needed.
- PRM-based discovery. Every MCP server gets a `/.well-known/oauth-protected-resource/<name>` endpoint. Clients hit the URL, get a 401 with PRM metadata, and know exactly how to authenticate.

## Architecture

```
Client (VS Code, service app, web app)
  |
  | HTTPS + Bearer token
  v
Azure API Management
  - JWT validation (Entra ID)
  - Scope / role / group checks
  - OBO token exchange (user flows)
  - CC token exchange (service flows)
  - Rate limiting, usage logging
  - PRM discovery (RFC 9728)
  |
  | Bearer token (backend audience)
  v
MCP Server (ACA, AKS, App Service, any HTTPS endpoint)
  - Validates JWT with its own audience
  - Exposes MCP tools (JSON-RPC over Streamable HTTP)
```

Clients only need the MCP server URL. APIM returns a 401 with a PRM link, the client fetches auth metadata, acquires a token, and calls the API. No manual tenant/scope/audience config in the client.

## Repository structure

```
infra/
  01-platform/         Platform infrastructure (APIM, Entra, KV, ACA env)
  02-configuration/    APIM config (fragments, named values, PRM)
  03-server/          Per-server APIM registration
  04-client/           Per-client Entra onboarding

modules/               Shared Terraform modules
policies/fragments/    13 reusable APIM policy fragments
samples/
  src/                 Sample .NET 10 MCP server + REST API
  aca-backend/         Terraform to deploy sample apps to ACA
tests/                 PowerShell test scripts (CC + PKCE flows)
scripts/               Build and push helpers Entra app registration reference
```

## What gets deployed

| Layer | Resources | Time |
|---|---|---|
| Platform (`infra/01-platform`) | Resource group, APIM, Entra ID apps, Key Vault, VNet, ACA env, observability | ~40 min |
| Configuration (`infra/02-configuration`) | 13 policy fragments, named values, PRM API | ~2 min |
| Per server (`infra/03-server`) | APIM API + composed policy + PRM endpoint | ~1 min |
| Per client (`infra/04-client`) | Entra pre-authorization (PKCE) or role assignment (CC) | ~30 sec |

Each layer has its own Terraform state and can run independently.

For a full walkthrough from zero, see [QUICKSTART.md](QUICKSTART.md).

### Remote state (optional, recommended for teams)

```bash
az group create -n rg-terraform-state -l westeurope
az storage account create -n <staccount> -g rg-terraform-state --sku Standard_LRS
az storage container create -n tfstate --account-name <staccount>
```

Then uncomment the `backend "azurerm"` block in each layer's `main.tf`.

## Deployment steps

The infrastructure is split into 4 independent layers. Each layer has its own Terraform state and can target an existing environment or read from the previous layer's state.

### Step 1: Platform (`infra/01-platform`)

Deploys the shared infrastructure that all MCP servers and clients depend on. Run once per environment.

Creates: resource group, 4 Entra ID app registrations (gateway, backend, OBO client, test service), APIM instance, Key Vault with OBO secrets, VNet, ACA environment, Log Analytics + Application Insights.

| Variable | Required | Description |
|---|---|---|
| `tenant_id` | Yes | Entra ID tenant ID |
| `subscription_id` | Yes | Azure subscription ID |
| `apim_publisher_email` | Yes | Email shown in APIM portal |
| `project` | Yes | Short name used as prefix for all resource names |
| `environment` | Yes | Environment name (dev, staging, prod) |
| `apim_sku` | No | APIM SKU. Default: `Developer_1` |
| `location` | No | Azure region. Default: `westeurope` |

```bash
cd infra/01-platform
cp terraform.tfvars.example terraform.tfvars
# Edit with your values
terraform init
terraform apply
```

### Step 2: Configuration (`infra/02-configuration`)

Configures the APIM instance with the policy framework. Can run against the platform from step 1 or against any existing APIM instance.

Creates: 13 policy fragments (JWT validation, OBO exchange, rate limiting, usage logging, etc.), KV-backed named values, PRM discovery API.

**How secrets work:** The OBO token exchange requires a client ID and secret. These are stored in Azure Key Vault as secrets. APIM reads them at runtime through named values that reference Key Vault, using its system-assigned managed identity. No secrets are stored in APIM itself or in Terraform state -- APIM is granted read-only access to Key Vault automatically by step 1.

**Input modes:** This layer can read all values from step 1's remote state, or you can point it at any existing APIM instance by providing the values directly.

| Variable | Mode | Required | Description |
|---|---|---|---|
| `use_remote_state` | Both | No | `true` (default) = read from step 1 state. `false` = provide values below. |
| `state_storage_account_name` | Remote | Yes | Storage account holding the Terraform state from step 1 |
| `subscription_id` | Direct | Yes | Azure subscription ID |
| `tenant_id` | Direct | Yes | Entra ID tenant ID |
| `resource_group_name` | Direct | Yes | Resource group containing the APIM instance |
| `apim_name` | Direct | Yes | Name of the APIM instance |
| `apim_id` | Direct | Yes | Full ARM resource ID of the APIM instance |
| `obo_client_app_id` | Direct | Yes | Application (client) ID of the OBO client app registration. Used in the PRM discovery response. |
| `keyvault_obo_client_id_uri` | Direct | Yes | Key Vault secret URI for the OBO client ID (e.g., `https://my-kv.vault.azure.net/secrets/obo-client-id`) |
| `keyvault_obo_client_secret_uri` | Direct | Yes | Key Vault secret URI for the OBO client secret. APIM reads this at runtime via managed identity. |

From step 1 state:

```bash
cd infra/02-configuration
cat > terraform.tfvars <<'EOF'
use_remote_state           = true
state_storage_account_name = "<staccount>"
EOF
terraform init && terraform apply
```

Against existing APIM (no step 1):

```bash
cd infra/02-configuration
cat > terraform.tfvars <<'EOF'
use_remote_state               = false
subscription_id                = "..."
tenant_id                      = "..."
resource_group_name            = "rg-my-existing-apim"
apim_id                        = "/subscriptions/.../providers/Microsoft.ApiManagement/service/my-apim"
apim_name                      = "my-apim"
obo_client_app_id              = "..."
keyvault_obo_client_id_uri     = "https://my-kv.vault.azure.net/secrets/obo-client-id"
keyvault_obo_client_secret_uri = "https://my-kv.vault.azure.net/secrets/obo-client-secret"
EOF
terraform init && terraform apply
```

### Step 3: Register a server (`infra/03-server`)

Registers an already-deployed MCP server in APIM. The server must be accessible via HTTPS. This step only creates the APIM routing and policies -- it does not deploy the server itself.

Creates: APIM API at `/mcp/<name>/`, composed policy (uses all fragments from step 2), PRM operation, product link.

| Variable | Required | Default | Description |
|---|---|---|---|
| `name` | Yes | | Short name for the URL path (`/mcp/<name>/`) |
| `backend_url` | Yes | | Full URL of the deployed MCP server |
| `display_name` | No | `MCP: <name>` | Name shown in APIM portal |
| `auth_mode` | No | `obo` | Backend auth: `obo`, `client_credentials`, `apikey`, `cert` |
| `backend_audience` | No | Shared backend app | Entra audience the backend validates |
| `required_scope` | No | `Mcp.Access` | Delegated scope checked for user tokens |
| `required_role` | No | `Mcp.Invoke` | App role checked for service tokens |
| `allowed_groups` | No | `[]` | Entra group IDs. If set, only these groups can access the server (user flows only) |
| `expose_prm` | No | `true` | Create a PRM discovery endpoint |

```bash
cd infra/03-server
cat > terraform.tfvars <<'EOF'
name         = "my-server"
display_name = "My MCP Server"
backend_url  = "https://my-server.azurecontainerapps.io/mcp"
auth_mode    = "obo"
EOF
terraform init -backend-config="key=03-server-my-server.tfstate"
terraform apply
```

To deploy the sample MCP server to ACA first, use `samples/aca-backend/` and pass its output URL as `backend_url`.

### Step 4: Onboard a client (`infra/04-client`)

Grants access to the gateway for a new client application. Three types:

| `client_type` | Use case | What it creates |
|---|---|---|
| `pkce` | Interactive app (VS Code, web app, SPA) | Pre-authorizes the app on gateway + OBO client. No consent prompts for users. |
| `cc` | New service / daemon / pipeline | Creates Entra app registration + secret + assigns `Mcp.Invoke` role. |
| `existing_cc` | Existing service app | Assigns `Mcp.Invoke` role only. No new app or secret. |

| Variable | Required | Description |
|---|---|---|
| `client_type` | Yes | `pkce`, `cc`, or `existing_cc` |
| `client_name` | Yes | Short name (used in app registration name for CC) |
| `client_app_id` | For pkce/existing_cc | Existing Entra app client ID |
| `client_display_name` | No (CC only) | Display name for new app registration |
| `create_secret` | No (CC only) | Create a client secret. Default: `true` |
| `secret_expiry` | No (CC only) | Secret lifetime. Default: `8760h` (1 year) |

PKCE client example:

```bash
cd infra/04-client
cat > terraform.tfvars <<'EOF'
client_type   = "pkce"
client_name   = "my-web-app"
client_app_id = "00000000-0000-0000-0000-000000000000"
EOF
terraform init -backend-config="key=04-client-my-web-app.tfstate"
terraform apply
```

CC client example:

```bash
cat > terraform.tfvars <<'EOF'
client_type         = "cc"
client_name         = "data-pipeline"
client_display_name = "Data Pipeline Service"
EOF
terraform init -backend-config="key=04-client-data-pipeline.tfstate"
terraform apply
# outputs: cc_app_id, cc_client_secret, scope, token_endpoint
```

## State dependency

```
01-platform.tfstate
    |--- 02-configuration.tfstate
    |--- 03-server-<name>.tfstate    (one per server)
    |--- 04-client-<name>.tfstate     (one per client)
```

03 and 04 are independent of each other. They only need 01 (or equivalent variables).

## Onboarding checklists

### New MCP server

- [ ] Server deployed and accessible via HTTPS
- [ ] Server validates Entra ID JWTs (correct audience)
- [ ] `terraform apply` in 03-server with name + backend_url
- [ ] PRM endpoint returns valid JSON (if `expose_prm = true`)
- [ ] Test script passes (CC and/or PKCE flow)

### New client app

- [ ] App registered in Entra ID (if PKCE: with redirect URI)
- [ ] `terraform apply` in 04-client with correct client_type
- [ ] Client can acquire token and call MCP endpoint
- [ ] 401 challenge returns PRM URL, token flow works end-to-end

## Key concepts

**Protected Resource Metadata (PRM)** -- APIM publishes a JSON document at `/.well-known/oauth-protected-resource/<server-name>` that tells clients where to authenticate and what scopes to request. MCP auth spec (2025-11-25) mandates this.

**On-Behalf-Of (OBO)** -- When a user calls an MCP server through APIM, the gateway exchanges the user's token for a backend-scoped token that preserves the user's identity. The backend sees who the user is without the client needing to know about the backend.

**Fragment-first policies** -- All APIM logic is built from 13 reusable XML policy fragments. Onboarding a new MCP server means setting 5 Terraform variables. Zero XML editing.

**Two auth flows** -- Interactive users (VS Code, web apps) use Auth Code + PKCE. Services and agents use Client Credentials. APIM detects the flow from the token claims and routes accordingly.


## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## References

- [MCP Authorization spec (2025-11-25)](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
- [RFC 9728 -- Protected Resource Metadata](https://datatracker.ietf.org/doc/html/rfc9728)
- [RFC 7636 -- PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [Microsoft Entra ID -- OBO flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
- [Azure API Management -- Policy fragments](https://learn.microsoft.com/azure/api-management/policy-fragments)
