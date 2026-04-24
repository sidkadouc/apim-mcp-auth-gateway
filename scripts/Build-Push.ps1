#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build and push sample container images to Azure Container Registry.

.PARAMETER AcrName
    ACR name (without .azurecr.io). If omitted, reads from terraform output.

.PARAMETER Tag
    Image tag. Defaults to "latest".

.EXAMPLE
    ./scripts/Build-Push.ps1 -AcrName myregistry
    ./scripts/Build-Push.ps1 -AcrName myregistry -Tag v1.0.0
#>
param(
    [string] $AcrName,
    [string] $Tag = "latest"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path

if (-not $AcrName) {
    $AcrName = (terraform -chdir:$repoRoot output -raw acr_name 2>$null)
    if (-not $AcrName) {
        Write-Error "ACR name not found. Pass -AcrName or ensure 'acr_name' terraform output exists."
        exit 1
    }
}

$acrServer = "$AcrName.azurecr.io"

Write-Host "`n=== Logging in to $acrServer ===" -ForegroundColor Cyan
az acr login --name $AcrName

$images = @(
    @{ Name = "sample-mcp-server"; Context = "$repoRoot/samples/src/SampleMcpServer" }
    @{ Name = "sample-rest-api";   Context = "$repoRoot/samples/src/SampleRestApi" }
)

foreach ($img in $images) {
    $fullTag = "$acrServer/$($img.Name):$Tag"
    Write-Host "`n=== Building $fullTag ===" -ForegroundColor Cyan
    docker build -t $fullTag $img.Context
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed for $($img.Name)"; exit 1 }

    Write-Host "=== Pushing $fullTag ===" -ForegroundColor Cyan
    docker push $fullTag
    if ($LASTEXITCODE -ne 0) { Write-Error "Push failed for $($img.Name)"; exit 1 }

    Write-Host "  [OK] $fullTag" -ForegroundColor Green
}

Write-Host "`n=== Done. Update terraform.tfvars: ===" -ForegroundColor Cyan
Write-Host @"
acr_login_server = "$acrServer"
mcp_sample_image = "$acrServer/sample-mcp-server:$Tag"
rest_sample_image = "$acrServer/sample-rest-api:$Tag"
"@
