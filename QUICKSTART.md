# Quickstart

Deploy the full stack from scratch in 8 steps.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) >= 2.50
- [.NET SDK](https://dot.net) 10.0+ (for building samples)
- [Docker](https://docs.docker.com/get-docker/) (for building container images)
- An Azure subscription (Owner or Contributor + User Access Administrator)
- An Entra ID tenant (Application Administrator role)
- An Azure Container Registry (ACR)

## Step 1: Clone and authenticate

```bash
git clone <repo-url> && cd ApimAIGW

az login --tenant <your-tenant-id>
az account set --subscription <your-subscription-id>
```

## Step 2: Deploy platform infrastructure

```bash
cd infra/01-platform
cp terraform.tfvars.example terraform.tfvars
# Edit: tenant_id, subscription_id, apim_publisher_email, project, environment

terraform init
terraform apply
```

This takes around 30-45 minutes (APIM provisioning). Creates: resource group, APIM, Entra ID apps, Key Vault, VNet, ACA environment, observability.

## Step 3: Configure APIM policies

```bash
cd ../02-configuration
cp terraform.tfvars.example terraform.tfvars
# Set use_remote_state = false and fill in values from step 2 output

terraform init
terraform apply
```

Creates: 13 policy fragments, KV-backed named values, PRM discovery API.

## Step 4: Build and push sample apps

```bash
ACR_NAME="<your-acr-name>"

docker build -t $ACR_NAME.azurecr.io/sample-mcp-server:latest ./samples/src/SampleMcpServer
docker build -t $ACR_NAME.azurecr.io/sample-rest-api:latest   ./samples/src/SampleRestApi

az acr login --name $ACR_NAME
docker push $ACR_NAME.azurecr.io/sample-mcp-server:latest
docker push $ACR_NAME.azurecr.io/sample-rest-api:latest
```

## Step 5: Deploy sample backends to ACA

```bash
cd ../samples/aca-backend
cp terraform.tfvars.example terraform.tfvars
# Set state_storage_account_name, mcp_sample_image, rest_sample_image, acr_login_server

terraform init
terraform apply

# Note the MCP server URL for the next step
terraform output mcp_server_url
```

## Step 6: Register the demo server in APIM

```bash
cd ../../infra/03-server
cp terraform.tfvars.example terraform.tfvars
# Set: name = "mcp-demo"
#      backend_url = <mcp_server_url from step 5>

terraform init
terraform apply
```

## Step 7: Test

```powershell
# Client Credentials flow
./tests/Test-ClientCredentials.ps1 `
  -ApimGatewayUrl "<apim-gateway-url>" `
  -TenantId       "<tenant-id>" `
  -ClientId       "<test-service-app-id>" `
  -ClientSecret   "<test-service-secret>" `
  -GatewayAppId   "<gateway-app-id>"

# Auth Code + PKCE flow (opens browser)
./tests/Test-AuthCodePKCE.ps1 `
  -ApimGatewayUrl "<apim-gateway-url>" `
  -TenantId       "<tenant-id>" `
  -ClientId       "aebc6443-996d-45c2-90f0-388ff96faa56"
```

Get the parameter values from `terraform output` in `infra/01-platform`.

### Test with VS Code

The repo includes a ready-to-use `.vscode/mcp.json`. Edit it with your APIM gateway URL:

```json
{
  "servers": {
    "mcp-demo": {
      "type": "http",
      "url": "https://<your-apim-name>.azure-api.net/mcp/mcp-demo"
    }
  }
}
```

Then in VS Code:

1. Open this repo as a workspace.
2. Open Copilot Chat (Ctrl+Shift+I) and switch to Agent mode.
3. The `mcp-demo` server appears in the tool list. Click it to connect.
4. VS Code gets a 401, fetches the PRM document, opens a browser for sign-in (Auth Code + PKCE), and caches the token automatically.
5. Try asking Copilot: "Use the echo tool to say hello" or "Who am I?" (calls the `whoami` tool).
6. The `whoami` tool response shows the signed-in user's identity, proving the full OBO chain works end-to-end.

No manual tenant, scope, or audience configuration needed. PRM handles everything.

## Next steps

- Register another MCP server: see [README.md](README.md#step-3-register-a-server-infra03-server)
- Onboard a client app: see [README.md](README.md#step-4-onboard-a-client-infra04-client)
- Auth flow diagrams: [docs/auth-flows.md](docs/auth-flows.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
