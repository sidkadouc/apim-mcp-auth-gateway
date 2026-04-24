<#
.SYNOPSIS
  Tests the Authorization Code + PKCE flow (user-delegated) against the APIM MCP Gateway.

.DESCRIPTION
  1. Fetches PRM document to discover auth requirements
  2. Opens a browser for interactive sign-in (auth code + PKCE)
  3. Exchanges code for user token
  4. Calls MCP endpoint – proves OBO user delegation end-to-end

.PARAMETER ApimGatewayUrl
  APIM gateway base URL

.PARAMETER TenantId
  Entra ID tenant ID

.PARAMETER ClientId
  Interactive client app ID (VS Code or custom test client).
  For VS Code: aebc6443-996d-45c2-90f0-388ff96faa56

.PARAMETER McpServerName
  MCP server name (default: mcp-demo)

.EXAMPLE
  .\Test-AuthCodePKCE.ps1 `
    -ApimGatewayUrl "https://apim-<project>-<env>.azure-api.net" `
    -TenantId "00000000-..." `
    -ClientId "aebc6443-996d-45c2-90f0-388ff96faa56"
#>

param(
    [Parameter(Mandatory)] [string] $ApimGatewayUrl,
    [Parameter(Mandatory)] [string] $TenantId,
    [Parameter(Mandatory)] [string] $ClientId,
    [string] $McpServerName = "mcp-demo"
)

$ErrorActionPreference = "Stop"
$ApimGatewayUrl = $ApimGatewayUrl.TrimEnd("/")

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " MCP Auth Code + PKCE Flow Test (User)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ---- Step 1: PRM Discovery ----
Write-Host "`n[1/5] Fetching PRM document..." -ForegroundColor Yellow
$prmUrl = "$ApimGatewayUrl/.well-known/oauth-protected-resource/$McpServerName"
$prmResponse = Invoke-RestMethod -Uri $prmUrl -Method Get
Write-Host "  resource: $($prmResponse.resource)" -ForegroundColor Green
$audience = $prmResponse.resource
$scope = "$audience/Mcp.Access"

# ---- Step 2: Generate PKCE ----
Write-Host "`n[2/5] Generating PKCE challenge..." -ForegroundColor Yellow
$codeVerifier = -join ((65..90) + (97..122) + (48..57) + 45, 46, 95, 126 | Get-Random -Count 64 | ForEach-Object { [char]$_ })
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($codeVerifier))
$codeChallenge = [Convert]::ToBase64String($hash).Replace("+", "-").Replace("/", "_").TrimEnd("=")
Write-Host "  code_challenge: $codeChallenge"

# ---- Step 3: Start local listener & open browser ----
$redirectPort = 8400
$redirectUri = "http://localhost:$redirectPort/"
$state = [guid]::NewGuid().ToString()

$authorizeUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize?" +
    "client_id=$ClientId" +
    "&response_type=code" +
    "&redirect_uri=$([Uri]::EscapeDataString($redirectUri))" +
    "&scope=$([Uri]::EscapeDataString("$scope offline_access openid profile"))" +
    "&code_challenge=$codeChallenge" +
    "&code_challenge_method=S256" +
    "&state=$state"

Write-Host "`n[3/5] Opening browser for sign-in..." -ForegroundColor Yellow
Write-Host "  $authorizeUrl`n"

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($redirectUri)
$listener.Start()

Start-Process $authorizeUrl

Write-Host "  Waiting for redirect on $redirectUri ..." -ForegroundColor DarkYellow
$context = $listener.GetContext()
$query = $context.Request.Url.Query
$params = [System.Web.HttpUtility]::ParseQueryString($query)
$code = $params["code"]
$returnedState = $params["state"]

# Send success page
$response = $context.Response
$html = "<html><body><h2>Authentication successful!</h2><p>You can close this tab.</p></body></html>"
$buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
$response.ContentLength64 = $buffer.Length
$response.OutputStream.Write($buffer, 0, $buffer.Length)
$response.Close()
$listener.Stop()

if ($returnedState -ne $state) {
    Write-Host "  ERROR: State mismatch – possible CSRF" -ForegroundColor Red
    exit 1
}
if (-not $code) {
    Write-Host "  ERROR: No authorization code received" -ForegroundColor Red
    Write-Host "  Error: $($params['error']) - $($params['error_description'])" -ForegroundColor Red
    exit 1
}
Write-Host "  OK - authorization code received" -ForegroundColor Green

# ---- Step 4: Exchange code for token ----
Write-Host "`n[4/5] Exchanging code for token..." -ForegroundColor Yellow
$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$tokenBody = @{
    grant_type    = "authorization_code"
    client_id     = $ClientId
    code          = $code
    redirect_uri  = $redirectUri
    code_verifier = $codeVerifier
    scope         = "$scope offline_access openid profile"
}

$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
$accessToken = $tokenResponse.access_token

# Decode JWT
$parts = $accessToken.Split(".")
$payload = $parts[1].Replace("-", "+").Replace("_", "/")
while ($payload.Length % 4) { $payload += "=" }
$claims = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json

Write-Host "  OK - token acquired" -ForegroundColor Green
Write-Host "  aud: $($claims.aud)"
Write-Host "  oid: $($claims.oid)"
Write-Host "  upn: $($claims.upn ?? $claims.preferred_username)"
Write-Host "  name: $($claims.name)"
Write-Host "  scp: $($claims.scp)"

# ---- Step 5: Call MCP endpoint ----
Write-Host "`n[5/5] Calling MCP endpoint with user token..." -ForegroundColor Yellow
$mcpUrl = "$ApimGatewayUrl/mcp/$McpServerName/"
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json, text/event-stream"
}

# tools/call whoami – should return THE USER's identity (OBO proof)
$jsonRpcWhoami = @{
    jsonrpc = "2.0"
    method  = "tools/call"
    id      = 1
    params  = @{
        name      = "whoami"
        arguments = @{}
    }
} | ConvertTo-Json -Depth 3

Write-Host "  Calling tools/call (whoami) – should return YOUR identity via OBO..."
try {
    $whoamiResponse = Invoke-RestMethod -Uri $mcpUrl -Method Post -Headers $headers -Body $jsonRpcWhoami
    Write-Host "  OK - whoami response:" -ForegroundColor Green
    Write-Host ($whoamiResponse | ConvertTo-Json -Depth 5)
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "  FAILED (HTTP $statusCode): $_" -ForegroundColor Red
    if ($statusCode -eq 502) {
        Write-Host "  Check: OBO exchange likely failed. Verify:" -ForegroundColor DarkYellow
        Write-Host "    - obo-client-id/secret named values are correct" -ForegroundColor DarkYellow
        Write-Host "    - OBO client has Backend.Access delegated consent" -ForegroundColor DarkYellow
    }
}

# tools/call get-my-graph-profile
$jsonRpcProfile = @{
    jsonrpc = "2.0"
    method  = "tools/call"
    id      = 2
    params  = @{
        name      = "get-my-graph-profile"
        arguments = @{}
    }
} | ConvertTo-Json -Depth 3

Write-Host "`n  Calling tools/call (get-my-graph-profile)..."
try {
    $profileResponse = Invoke-RestMethod -Uri $mcpUrl -Method Post -Headers $headers -Body $jsonRpcProfile
    Write-Host "  OK - profile response:" -ForegroundColor Green
    Write-Host ($profileResponse | ConvertTo-Json -Depth 5)
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "  FAILED (HTTP $statusCode): $_" -ForegroundColor Red
}

# tools/call echo
$jsonRpcEcho = @{
    jsonrpc = "2.0"
    method  = "tools/call"
    id      = 3
    params  = @{
        name      = "echo"
        arguments = @{ message = "Hello from user: $($claims.name)!" }
    }
} | ConvertTo-Json -Depth 3

Write-Host "`n  Calling tools/call (echo)..."
try {
    $echoResponse = Invoke-RestMethod -Uri $mcpUrl -Method Post -Headers $headers -Body $jsonRpcEcho
    Write-Host "  OK - echo response:" -ForegroundColor Green
    Write-Host ($echoResponse | ConvertTo-Json -Depth 5)
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "  FAILED (HTTP $statusCode): $_" -ForegroundColor Red
}

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " Test Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
