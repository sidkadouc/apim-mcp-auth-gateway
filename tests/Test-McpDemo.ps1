#!/usr/bin/env pwsh
<#
.SYNOPSIS
    End-to-end test of the MCP Demo server through the APIM AI Gateway.

.DESCRIPTION
    1. Acquires a client-credentials token (test-service app → Mcp.Invoke role on gateway).
    2. Sends MCP JSON-RPC requests: initialize, tools/list, then calls echo, whoami, get-my-graph-profile.
    3. Prints a pass/fail result for each step.

.PARAMETER TestClientSecret
    Client secret for the test-service app. If omitted, read from `terraform output -raw test_service_secret`.

.NOTES
    The test-service app has the Mcp.Invoke application role on the gateway app registration.
    Client-credentials tokens are accepted by the APIM validate-entra-jwt policy when the
    roles claim contains "Mcp.Invoke".
#>
param(
    [string] $TenantId,
    [string] $GatewayAppId,
    [string] $TestClientId,
    [string] $TestClientSecret,
    [string] $ApimGatewayUrl,
    [string] $McpServerPath = "mcp/mcp-demo/"
)

# ──────────────────────────────────────────────────────────────────────────────
# Configuration – resolve from terraform output when not provided
# ──────────────────────────────────────────────────────────────────────────────
$tfDir = "$PSScriptRoot/.."

if (-not $TenantId)        { $TenantId        = (terraform -chdir:$tfDir output -raw tenant_id 2>$null) }
if (-not $GatewayAppId)    { $GatewayAppId    = (terraform -chdir:$tfDir output -raw apim_gateway_app_id 2>$null) }
if (-not $TestClientId)    { $TestClientId    = (terraform -chdir:$tfDir output -raw test_service_app_id 2>$null) }
if (-not $TestClientSecret){ $TestClientSecret = (terraform -chdir:$tfDir output -raw test_service_secret 2>$null) }
if (-not $ApimGatewayUrl)  { $ApimGatewayUrl  = (terraform -chdir:$tfDir output -raw apim_gateway_url 2>$null) }

# Validate all required values are present
@{ TenantId = $TenantId; GatewayAppId = $GatewayAppId; TestClientId = $TestClientId;
   TestClientSecret = $TestClientSecret; ApimGatewayUrl = $ApimGatewayUrl }.GetEnumerator() | ForEach-Object {
    if (-not $_.Value) { throw "Missing required parameter: -$($_.Key). Pass it explicitly or run from the repo root after terraform apply." }
}

$McpBaseUrl = "$($ApimGatewayUrl.TrimEnd('/'))/$McpServerPath"

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────
$PassCount = 0
$FailCount = 0

function Assert-Step {
    param([string]$Name, [scriptblock]$Test)
    try {
        $result = & $Test
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:PassCount++
        return $result
    } catch {
        Write-Host "  [FAIL] $Name — $_" -ForegroundColor Red
        $script:FailCount++
        return $null
    }
}

function Invoke-McpRequest {
    param([string]$Method, [hashtable]$Params, [string]$Token, [int]$Id = 1, [string]$SessionId = "")
    $body = @{
        jsonrpc = "2.0"
        id      = $Id
        method  = $Method
        params  = if ($Params) { $Params } else { @{} }
    } | ConvertTo-Json -Depth 10

    $headers = @{
        Authorization  = "Bearer $Token"
        "Content-Type" = "application/json"
        Accept         = "text/event-stream, application/json"
    }
    if ($SessionId) { $headers["Mcp-Session-Id"] = $SessionId }

    $resp = Invoke-WebRequest -Uri $McpBaseUrl -Method POST -Headers $headers `
                              -Body $body -SkipHttpErrorCheck -TimeoutSec 30

    if ($resp.StatusCode -ne 200) {
        throw "HTTP $($resp.StatusCode): $($resp.Content)"
    }

    # Streamable HTTP: response may be SSE (event: message\ndata: {...}) or plain JSON
    $raw = $resp.Content
    if ($raw -match '^event:') {
        $dataLine = ($raw -split "`n" | Where-Object { $_ -match '^data:' } | Select-Object -First 1)
        $raw = $dataLine -replace '^data:\s*', ''
    }

    return @{
        Body      = ($raw | ConvertFrom-Json)
        SessionId = $resp.Headers["Mcp-Session-Id"]
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 1 – Acquire token via client credentials
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 1: Acquire token (client credentials) ===" -ForegroundColor Cyan

$token = Assert-Step "Token acquisition" {
    $tokenResp = Invoke-RestMethod `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Method POST `
        -Body @{
            grant_type    = "client_credentials"
            client_id     = $TestClientId
            client_secret = $TestClientSecret
            scope         = "api://$GatewayAppId/.default"
        }
    if (-not $tokenResp.access_token) { throw "No access_token in response" }
    $tokenResp.access_token
}

if (-not $token) {
    Write-Host "`nCannot continue without a token." -ForegroundColor Red
    exit 1
}

# Decode and show key token claims (no signature verification needed here)
$payload = $token.Split('.')[1]
$pad = 4 - ($payload.Length % 4); if ($pad -ne 4) { $payload += '=' * $pad }
$claims = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
Write-Host "    aud=$($claims.aud)  roles=$($claims.roles -join ',')" -ForegroundColor DarkGray

# ──────────────────────────────────────────────────────────────────────────────
# Step 2 – MCP initialize
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 2: MCP initialize ===" -ForegroundColor Cyan

$sessionId = $null
$initResult = Assert-Step "initialize handshake" {
    $r = Invoke-McpRequest -Method "initialize" -Token $token -Params @{
        protocolVersion = "2025-11-25"
        capabilities    = @{}
        clientInfo      = @{ name = "ps-test"; version = "1.0" }
    }
    if ($r.Body.result.protocolVersion -ne "2025-11-25") {
        throw "Unexpected protocolVersion: $($r.Body.result.protocolVersion)"
    }
    $script:sessionId = $r.SessionId
    $r.Body.result
}
if ($initResult) {
    Write-Host "    server=$($initResult.serverInfo.name) v$($initResult.serverInfo.version)" -ForegroundColor DarkGray
    Write-Host "    sessionId=$sessionId" -ForegroundColor DarkGray
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 3 – tools/list
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 3: tools/list ===" -ForegroundColor Cyan

$toolsResult = Assert-Step "tools/list returns tools" {
    $r = Invoke-McpRequest -Method "tools/list" -Token $token -Id 2 -SessionId $sessionId
    if ($r.Body.result.tools.Count -eq 0) { throw "No tools returned" }
    $r.Body.result.tools
}
if ($toolsResult) {
    $toolsResult | ForEach-Object { Write-Host "    tool: $($_.name) — $($_.description)" -ForegroundColor DarkGray }
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 4 – tools/call: echo
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 4: tools/call echo ===" -ForegroundColor Cyan

$echoResult = Assert-Step "echo tool returns message" {
    $r = Invoke-McpRequest -Method "tools/call" -Token $token -Id 3 -SessionId $sessionId -Params @{
        name      = "echo"
        arguments = @{ message = "Hello from PowerShell test!" }
    }
    $content = $r.Body.result.content[0].text | ConvertFrom-Json
    if ($content.echo -ne "Hello from PowerShell test!") { throw "Echo mismatch: $($content.echo)" }
    $content
}
if ($echoResult) {
    Write-Host "    echo=$($echoResult.echo)  server=$($echoResult.server)" -ForegroundColor DarkGray
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 5 – tools/call: whoami
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 5: tools/call whoami ===" -ForegroundColor Cyan

$whoamiResult = Assert-Step "whoami returns identity" {
    $r = Invoke-McpRequest -Method "tools/call" -Token $token -Id 4 -SessionId $sessionId -Params @{
        name      = "whoami"
        arguments = @{}
    }
    $content = $r.Body.result.content[0].text | ConvertFrom-Json
    if (-not $content.isAuthenticated) { throw "isAuthenticated is false" }
    $content
}
if ($whoamiResult) {
    Write-Host "    upn=$($whoamiResult.userPrincipalName)  aud=$($whoamiResult.audience)" -ForegroundColor DarkGray
    Write-Host "    roles=$($whoamiResult.roles -join ',')  scopes=$($whoamiResult.scopes)" -ForegroundColor DarkGray
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 6 – tools/call: get-my-graph-profile
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n=== Step 6: tools/call get-my-graph-profile ===" -ForegroundColor Cyan

$profileResult = Assert-Step "get-my-graph-profile returns profile object" {
    $r = Invoke-McpRequest -Method "tools/call" -Token $token -Id 5 -SessionId $sessionId -Params @{
        name      = "get-my-graph-profile"
        arguments = @{}
    }
    $content = $r.Body.result.content[0].text | ConvertFrom-Json
    # CC (app-only) tokens have no user; a userPrincipalName or source field is sufficient proof
    if (-not $content.source -and -not $content.userPrincipalName -and -not $content.displayName) {
        throw "Profile response has no recognisable fields: $($r.Body.result.content[0].text)"
    }
    $content
}
if ($profileResult) {
    Write-Host "    displayName=$($profileResult.displayName)  upn=$($profileResult.userPrincipalName)" -ForegroundColor DarkGray
}

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
Write-Host "`n════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Results: $PassCount passed, $FailCount failed" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Yellow" })
Write-Host "════════════════════════════════════════`n" -ForegroundColor Cyan

exit $FailCount
