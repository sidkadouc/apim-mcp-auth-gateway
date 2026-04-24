<#
.SYNOPSIS
  Tests the Client Credentials flow against the APIM MCP Gateway.

.DESCRIPTION
  1. Fetches PRM document (unauthenticated) to discover auth requirements
  2. Acquires an app-only token using client credentials grant
  3. Calls the MCP endpoint with the token
  4. Validates the response

.PARAMETER ApimGatewayUrl
  APIM gateway base URL (e.g., https://apim-<project>-<env>.azure-api.net)

.PARAMETER TenantId
  Entra ID tenant ID

.PARAMETER ClientId
  Test service app client ID (from terraform output test_service_app_id)

.PARAMETER ClientSecret
  Test service app client secret (from terraform output -raw test_service_secret)

.PARAMETER McpServerName
  MCP server name as registered in APIM (default: mcp-demo)

.EXAMPLE
  .\Test-ClientCredentials.ps1 `
    -ApimGatewayUrl "https://apim-<project>-<env>.azure-api.net" `
    -TenantId "00000000-..." `
    -ClientId "11111111-..." `
    -ClientSecret "secret..."
#>

param(
    [Parameter(Mandatory)] [string] $ApimGatewayUrl,
    [Parameter(Mandatory)] [string] $TenantId,
    [Parameter(Mandatory)] [string] $ClientId,
    [Parameter(Mandatory)] [string] $ClientSecret,
    [string] $McpServerName = "mcp-demo",
    # Gateway app registration client ID -- used to build the CC scope (api://<id>/.default).
    [Parameter(Mandatory)] [string] $GatewayAppId
)

$ErrorActionPreference = "Stop"
$ApimGatewayUrl = $ApimGatewayUrl.TrimEnd("/")

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " MCP Client Credentials Flow Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ---- Step 1: PRM Discovery ----
Write-Host "`n[1/4] Fetching PRM document (RFC 9728)..." -ForegroundColor Yellow
$prmUrl = "$ApimGatewayUrl/.well-known/oauth-protected-resource/$McpServerName"
Write-Host "  GET $prmUrl"
try {
    $prmResponse = Invoke-RestMethod -Uri $prmUrl -Method Get
    Write-Host "  OK - resource: $($prmResponse.resource)" -ForegroundColor Green
    Write-Host "  authorization_servers: $($prmResponse.authorization_servers -join ', ')"
    Write-Host "  scopes_supported: $($prmResponse.scopes_supported -join ', ')"
    $audience = $prmResponse.resource
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    exit 1
}

# ---- Step 2: 401 Challenge (verify WWW-Authenticate) ----
Write-Host "`n[2/4] Verifying 401 + WWW-Authenticate challenge..." -ForegroundColor Yellow
$mcpUrl = "$ApimGatewayUrl/mcp/$McpServerName/"
Write-Host "  POST $mcpUrl (no token)"
try {
    $null = Invoke-WebRequest -Uri $mcpUrl -Method Post -Body '{}' -ContentType "application/json" -ErrorAction Stop
    Write-Host "  UNEXPECTED: Got 200 without token (should be 401)" -ForegroundColor Red
    exit 1
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        $wwwAuth = $_.Exception.Response.Headers.GetValues("WWW-Authenticate") -join ""
        if ($wwwAuth -match "resource_metadata") {
            Write-Host "  OK - 401 with resource_metadata in WWW-Authenticate" -ForegroundColor Green
            Write-Host "  $wwwAuth"
        } else {
            Write-Host "  WARNING: 401 but no resource_metadata in challenge" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  UNEXPECTED status: $statusCode" -ForegroundColor Red
    }
}

# ---- Step 3: Acquire token via Client Credentials ----
Write-Host "`n[3/4] Acquiring token (client_credentials)..." -ForegroundColor Yellow
$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
# For CC, scope must target the gateway app registration (api://<appId>/.default).
# The PRM `resource` is the APIM endpoint URL, not the Entra app ID URI.
$scope = "api://$GatewayAppId/.default"
Write-Host "  POST $tokenUrl"
Write-Host "  scope=$scope"

$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = $scope
}

try {
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
    $accessToken = $tokenResponse.access_token

    # Decode JWT payload (base64url) to inspect claims
    $parts = $accessToken.Split(".")
    $payload = $parts[1].Replace("-", "+").Replace("_", "/")
    while ($payload.Length % 4) { $payload += "=" }
    $claims = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json

    Write-Host "  OK - token acquired" -ForegroundColor Green
    Write-Host "  aud: $($claims.aud)"
    Write-Host "  iss: $($claims.iss)"
    Write-Host "  roles: $($claims.roles -join ', ')"
    Write-Host "  appid: $($claims.appid)"
    Write-Host "  exp: $(([DateTimeOffset]::FromUnixTimeSeconds($claims.exp)).UtcDateTime)"

    if ($claims.roles -notcontains "Mcp.Invoke") {
        Write-Host "  WARNING: Token does not contain Mcp.Invoke role!" -ForegroundColor Red
        Write-Host "  Ensure the test service app has Mcp.Invoke role assigned." -ForegroundColor Red
        exit 1
    }

    # Verify no user claims (this is app-only)
    if ($claims.oid -and $claims.scp) {
        Write-Host "  WARNING: Token has both oid and scp – this looks like a delegated token, not CC" -ForegroundColor Red
    }
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
    exit 1
}

# ---- Step 4: Call MCP endpoint with token ----
Write-Host "`n[4/4] Calling MCP endpoint..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json, text/event-stream"
}

function Invoke-McpJsonRpc {
    param([hashtable]$Body, [string]$SessionId = "")
    $h = $headers.Clone()
    if ($SessionId) { $h["Mcp-Session-Id"] = $SessionId }
    $resp = Invoke-WebRequest -Uri $mcpUrl -Method Post -Headers $h `
                              -Body ($Body | ConvertTo-Json -Depth 5) -SkipHttpErrorCheck -TimeoutSec 30
    if ($resp.StatusCode -ge 400) { throw "HTTP $($resp.StatusCode): $($resp.Content)" }
    $raw = $resp.Content
    if ($raw -match '^event:') {
        $dataLine = ($raw -split "`n" | Where-Object { $_ -match '^data:' } | Select-Object -First 1)
        $raw = $dataLine -replace '^data:\s*', ''
    }
    return @{ Body = ($raw | ConvertFrom-Json); SessionId = $resp.Headers["Mcp-Session-Id"] }
}

# Step 4a: initialize (required to create session)
Write-Host "  POST $mcpUrl (initialize)"
$initResult = $null
try {
    $initResult = Invoke-McpJsonRpc -Body @{
        jsonrpc = "2.0"; id = 1; method = "initialize"
        params  = @{ protocolVersion = "2024-11-05"; capabilities = @{}
                     clientInfo = @{ name = "cc-test"; version = "1.0" } }
    }
    $sessionId = $initResult.SessionId
    Write-Host "  OK - initialized, sessionId=$sessionId" -ForegroundColor Green
    Write-Host "  server=$($initResult.Body.result.serverInfo.name) v$($initResult.Body.result.serverInfo.version)"
} catch {
    $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "?" }
    Write-Host "  FAILED (HTTP $statusCode): $_" -ForegroundColor Red
    if ($statusCode -eq 403) { Write-Host "  Check: require-app-role fragment may be rejecting Mcp.Invoke" -ForegroundColor DarkYellow }
    exit 1
}

# Step 4b: tools/list
Write-Host "`n  tools/list..."
try {
    $listResult = Invoke-McpJsonRpc -Body @{ jsonrpc = "2.0"; id = 2; method = "tools/list"; params = @{} } -SessionId $sessionId
    $tools = $listResult.Body.result.tools
    Write-Host "  OK - $($tools.Count) tools" -ForegroundColor Green
    $tools | ForEach-Object { Write-Host "    - $($_.name)" }
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
}

# Step 4c: echo
Write-Host "`n  tools/call echo..."
try {
    $echoResult = Invoke-McpJsonRpc -Body @{
        jsonrpc = "2.0"; id = 3; method = "tools/call"
        params = @{ name = "echo"; arguments = @{ message = "Hello from CC test!" } }
    } -SessionId $sessionId
    Write-Host "  OK - $($echoResult.Body.result.content[0].text)" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
}

# Step 4d: whoami (should show app identity, no user delegation)
Write-Host "`n  tools/call whoami (expect app-only, no upn)..."
try {
    $whoamiResult = Invoke-McpJsonRpc -Body @{
        jsonrpc = "2.0"; id = 4; method = "tools/call"
        params = @{ name = "whoami"; arguments = @{} }
    } -SessionId $sessionId
    Write-Host "  OK - $($whoamiResult.Body.result.content[0].text)" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $_" -ForegroundColor Red
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " Test Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
