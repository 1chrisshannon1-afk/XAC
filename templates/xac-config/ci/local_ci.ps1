<#
.SYNOPSIS
    Run full CI locally using _XAC_Base.
.DESCRIPTION
    Loads project config from .ci/config.ps1, then invokes the shared CI core
    from _XAC_Base/ci (preferred) or a sibling XAC clone.
.EXAMPLE
    .\local_ci.ps1
#>

$ErrorActionPreference = "Continue"
$ROOT = $PSScriptRoot
if (-not $ROOT) { $ROOT = $PWD.Path }
$parent = Split-Path (Split-Path $ROOT -Parent) -Leaf
if ((Split-Path $ROOT -Leaf) -eq "ci" -and ($parent -eq "_Config_Project" -or $parent -eq "_XAC_Config")) {
    $ROOT = (Split-Path (Split-Path $ROOT -Parent) -Parent)
}

$configPath = Join-Path $ROOT ".ci\config.ps1"
if (-not (Test-Path $configPath)) { $configPath = Join-Path $ROOT "config.ps1" }
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Config not found. Expected .ci\config.ps1 or config.ps1 next to this script." -ForegroundColor Red
    exit 1
}
. $configPath

$XacPath = Join-Path $ROOT "_XAC_Base"
if (Test-Path (Join-Path $XacPath "ci\scripts\bootstrap.ps1")) {
    . (Join-Path $XacPath "ci\scripts\bootstrap.ps1")
} elseif (Test-Path (Join-Path $ROOT ".ci\bootstrap-helper.ps1")) {
    . (Join-Path $ROOT ".ci\bootstrap-helper.ps1")
} else {
    $XacClonePath = Join-Path (Split-Path $ROOT -Parent) "XAC"
    if (-not (Test-Path $XacClonePath)) {
        Write-Host "Neither _XAC_Base nor XAC found. Create _XAC_Base at repo root or clone XAC as sibling." -ForegroundColor Red
        exit 1
    }
    $coreInCi = Test-Path (Join-Path $XacClonePath "ci\local_ci\core.ps1")
    $CI_SHARED_PATH = if ($coreInCi) { Join-Path $XacClonePath "ci" } else { $XacClonePath }
}

$corePath = Join-Path $CI_SHARED_PATH "local_ci\core.ps1"
if (-not (Test-Path $corePath)) {
    Write-Host "ERROR: Shared CI core not found at: $corePath" -ForegroundColor Red
    exit 1
}
. $corePath
