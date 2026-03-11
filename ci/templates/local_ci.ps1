# local_ci.ps1 — <PROJECT NAME>
# Runs full local CI. Loads .ci/config.ps1 then invokes _XAC/ci/local_ci/core.ps1 (or sibling IAC).
# Usage: .\local_ci.ps1

$ErrorActionPreference = "Continue"
$ROOT = $PSScriptRoot
if (-not $ROOT) { $ROOT = $PWD.Path }

# Load project config
. (Join-Path $ROOT ".ci\config.ps1")

# Bootstrap: prefer _XAC in repo root, else .ci/bootstrap-helper.ps1, else sibling IAC (or SharedWorkflows)
$XacPath = Join-Path $ROOT "_XAC"
if (Test-Path (Join-Path $XacPath "ci\scripts\bootstrap.ps1")) {
    . (Join-Path $XacPath "ci\scripts\bootstrap.ps1")
} elseif (Test-Path (Join-Path $ROOT ".ci\bootstrap-helper.ps1")) {
    . (Join-Path $ROOT ".ci\bootstrap-helper.ps1")
} else {
    $ParentDir = Split-Path $ROOT -Parent
    $IacPath = Join-Path $ParentDir "IAC"
    $LegacyPath = Join-Path $ParentDir "SharedWorkflows"
    $SharedPath = if (Test-Path $IacPath) { $IacPath } else { $LegacyPath }
    if (-not (Test-Path $SharedPath)) {
        Write-Host "Neither _XAC nor IAC found. Create _XAC or clone IAC as sibling." -ForegroundColor Red
        exit 1
    }
    $coreInCi = Test-Path (Join-Path $SharedPath "ci\local_ci\core.ps1")
    $CI_SHARED_PATH = if ($coreInCi) { Join-Path $SharedPath "ci" } else { $SharedPath }
}
# After bootstrap, $CI_SHARED_PATH is set (to _XAC/ci or IAC/ci or legacy clone root)

# Run shared CI engine (core.ps1 under CI_SHARED_PATH/local_ci/)
. (Join-Path $CI_SHARED_PATH "local_ci\core.ps1")
