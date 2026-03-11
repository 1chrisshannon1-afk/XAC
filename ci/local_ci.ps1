<#
.SYNOPSIS
    Canonical local CI entry point. Lives in _XAC_Base; repo root local_ci.ps1 is a one-line stub that calls this.
.DESCRIPTION
    Loads .ci/config.ps1 from repo root, bootstraps _XAC_Base path, runs _XAC_Base/ci/local_ci/core.ps1.
    Repo root is two levels up from this script (_XAC_Base/ci/local_ci.ps1).
#>
$ErrorActionPreference = "Continue"
$ROOT = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $ROOT) { $ROOT = $PWD.Path }
$configPath = Join-Path $ROOT ".ci\config.ps1"
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: .ci\config.ps1 not found. Run the XAC onboarding script from your repo root first." -ForegroundColor Red
    Write-Host "  One command: irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 | iex" -ForegroundColor Yellow
    exit 1
}
. $configPath
$XacPath = Join-Path $ROOT "_XAC_Base"
if (Test-Path (Join-Path $XacPath "ci\scripts\bootstrap.ps1")) { . (Join-Path $XacPath "ci\scripts\bootstrap.ps1") }
elseif (Test-Path (Join-Path $ROOT ".ci\bootstrap-helper.ps1")) { . (Join-Path $ROOT ".ci\bootstrap-helper.ps1") }
else {
    $XacClonePath = Join-Path (Split-Path $ROOT -Parent) "XAC"
    if (-not (Test-Path $XacClonePath)) { Write-Host "Neither _XAC_Base nor XAC found." -ForegroundColor Red; exit 1 }
    $CI_SHARED_PATH = if (Test-Path (Join-Path $XacClonePath "ci\local_ci\core.ps1")) { Join-Path $XacClonePath "ci" } else { $XacClonePath }
}
$corePath = Join-Path $CI_SHARED_PATH "local_ci\core.ps1"
if (-not (Test-Path $corePath)) { Write-Host "ERROR: CI core not found: $corePath" -ForegroundColor Red; exit 1 }
. $corePath
