# local_ci.ps1 — <PROJECT NAME>
# Runs full local CI. Loads .ci/config.ps1 then invokes _XAC/ci/local_ci/core.ps1 (or sibling XAC).
# Usage: .\local_ci.ps1

$ErrorActionPreference = "Continue"
$ROOT = $PSScriptRoot
if (-not $ROOT) { $ROOT = $PWD.Path }

# Load project config
. (Join-Path $ROOT ".ci\config.ps1")

# Bootstrap: prefer _XAC in repo root, else .ci/bootstrap-helper.ps1, else sibling XAC
$XacPath = Join-Path $ROOT "_XAC"
if (Test-Path (Join-Path $XacPath "ci\scripts\bootstrap.ps1")) {
    . (Join-Path $XacPath "ci\scripts\bootstrap.ps1")
} elseif (Test-Path (Join-Path $ROOT ".ci\bootstrap-helper.ps1")) {
    . (Join-Path $ROOT ".ci\bootstrap-helper.ps1")
} else {
    $ParentDir = Split-Path $ROOT -Parent
    $XacClonePath = Join-Path $ParentDir "XAC"
    if (-not (Test-Path $XacClonePath)) {
        Write-Host "Neither _XAC nor XAC found. Create _XAC or clone XAC as sibling." -ForegroundColor Red
        exit 1
    }
    $coreInCi = Test-Path (Join-Path $XacClonePath "ci\local_ci\core.ps1")
    $CI_SHARED_PATH = if ($coreInCi) { Join-Path $XacClonePath "ci" } else { $XacClonePath }
}
# After bootstrap, $CI_SHARED_PATH is set (to _XAC/ci or XAC/ci)

# Run shared CI engine (core.ps1 under CI_SHARED_PATH/local_ci/)
. (Join-Path $CI_SHARED_PATH "local_ci\core.ps1")
