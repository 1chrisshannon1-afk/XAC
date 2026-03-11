<#
.SYNOPSIS
    Bootstrap _XAC or IAC: ensure path exists, warn if stale. Sets $CI_SHARED_PATH in caller scope.
.DESCRIPTION
    Called by each project's local_ci.ps1. Prefers _XAC in project root; else sibling IAC (or SharedWorkflows).
    Clones IAC if missing; warns if last commit is older than 7 days. Does not block on staleness.
    IAC repo mirrors _XAC (ci/, iac/, monitoring/, docs/). CI_SHARED_PATH is set to .../ci when that layout exists.
#>

$ErrorActionPreference = "Stop"

if (-not $ROOT) { $ROOT = $PWD.Path }
$XacPath = Join-Path $ROOT "_XAC"
$ParentDir = Split-Path $ROOT -Parent
$IacPath = Join-Path $ParentDir "IAC"
$LegacyPath = Join-Path $ParentDir "SharedWorkflows"
$SharedPath = if (Test-Path $XacPath) { $XacPath } elseif (Test-Path $IacPath) { $IacPath } else { $LegacyPath }

if (-not (Test-Path $SharedPath)) {
    if ($SharedPath -eq $XacPath) {
        Write-Host "_XAC not found at $XacPath. Create _XAC or clone IAC as sibling." -ForegroundColor Red
        exit 1
    }
    Write-Host "IAC not found - cloning..." -ForegroundColor Yellow
    $cloneTarget = $IacPath
    if (-not (Test-Path $ParentDir)) { New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null }
    try {
        git clone https://github.com/1chrisshannon1-afk/IAC.git $cloneTarget
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Clone failed. Run manually: git clone https://github.com/1chrisshannon1-afk/IAC.git $cloneTarget" -ForegroundColor Red
            exit 1
        }
        $SharedPath = $cloneTarget
    } catch {
        Write-Host "Clone failed: $_" -ForegroundColor Red
        exit 1
    }
} else {
    $lastCommit = git -C $SharedPath log -1 --format=%ci 2>$null
    if ($lastCommit) {
        $firstPart = ($lastCommit -split ' ')[0]
        $lastDate = [DateTime]::Parse($firstPart)
        $daysOld = (Get-Date) - $lastDate
        if ($daysOld.TotalDays -gt 7) {
            $name = Split-Path $SharedPath -Leaf
            Write-Host "$name is older than 7 days. Consider: git -C $SharedPath pull" -ForegroundColor Yellow
        }
    }
}

# When repo has _XAC layout (ci/local_ci/core.ps1), point to ci so core is at CI_SHARED_PATH/local_ci/core.ps1
$coreInCi = Test-Path (Join-Path $SharedPath "ci\local_ci\core.ps1")
$CI_SHARED_PATH = if ($SharedPath -and $coreInCi) {
    Join-Path $SharedPath 'ci'
} elseif ($SharedPath -and (Split-Path $SharedPath -Leaf) -eq '_XAC') {
    Join-Path $SharedPath 'ci'
} else {
    $SharedPath
}
Set-Variable -Name CI_SHARED_PATH -Value $CI_SHARED_PATH -Scope 1
