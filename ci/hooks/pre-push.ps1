# XAC Pre-Push Hook — fast safety checks before every push.
# Heavy tests (integration, E2E, frontends) run in GitHub Actions.
# This hook only runs fast checks (~30-60 seconds).
# Install via: _XAC/ci/hooks/install.ps1

param(
    [string]$RemoteName = $args[0],
    [string]$RemoteUrl = $args[1]
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PRE-PUSH SAFETY CHECKS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:HasErrors = $false
$script:HasWarnings = $false
$script:Failures = @()
$script:Warnings = @()

function Report-Check {
    param(
        [string]$CheckName,
        [string]$Message,
        [ValidateSet("pass","fail","warn")]
        [string]$Status = "pass"
    )

    switch ($Status) {
        "fail" {
            Write-Host "  FAIL  $CheckName" -ForegroundColor Red
            Write-Host "        $Message" -ForegroundColor Red
            $script:HasErrors = $true
            $script:Failures += "  [FAIL] ${CheckName}: ${Message}"
        }
        "warn" {
            Write-Host "  WARN  $CheckName" -ForegroundColor Yellow
            Write-Host "        $Message" -ForegroundColor Yellow
            $script:HasWarnings = $true
            $script:Warnings += "  [WARN] ${CheckName}: ${Message}"
        }
        "pass" {
            Write-Host "  OK    $CheckName" -ForegroundColor Green
        }
    }
}

# Load project config for compile targets and ruff excludes
$configPath = Join-Path $PSScriptRoot "..\..\..\.ci\config.ps1"
# When run from source (_XAC/ci/hooks/): go up 3 levels to repo root
# When run from .git/hooks/ (installed): $PSScriptRoot is .git/hooks, go up 2 levels
if (-not (Test-Path $configPath)) {
    $configPath = Join-Path $PSScriptRoot "..\..\.ci\config.ps1"
}
if (Test-Path $configPath) { . $configPath }

$compileDirs = if ($CI_COMPILEALL_TARGETS) { $CI_COMPILEALL_TARGETS } else { @("modules", "entrypoint_backend\backend") }
$ruffExcludes = if ($CI_RUFF_EXCLUDES) { $CI_RUFF_EXCLUDES } else { @("_archive/**", "_ARCHIVE/**") }
$ruffTargets = @("modules/", "entrypoint_backend/backend/")

# Load secret patterns if available
$secretPatternsFile = Join-Path $PSScriptRoot "secret_patterns.ps1"
if (Test-Path $secretPatternsFile) { . $secretPatternsFile }

# -------------------------------------------------------------------
# 1. Uncommitted changes
# -------------------------------------------------------------------
Write-Host "[1/6] Checking for uncommitted changes..." -ForegroundColor Yellow
$ErrorActionPreference = "SilentlyContinue"
$uncommitted = git status --porcelain 2>&1 | Where-Object { $_ -match '^\s' }
$ErrorActionPreference = "Stop"

if ($uncommitted) {
    Report-Check "Uncommitted changes" "You have uncommitted changes. Commit or stash them first." "fail"
} else {
    Report-Check "Uncommitted changes" "" "pass"
}

# -------------------------------------------------------------------
# 2. Force push guard
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Checking for force push..." -ForegroundColor Yellow
$isForcePush = $false
if ($env:GIT_PUSH_OPTION_COUNT) {
    for ($i = 0; $i -lt $env:GIT_PUSH_OPTION_COUNT; $i++) {
        $option = (Get-Item "env:GIT_PUSH_OPTION_$i").Value
        if ($option -eq "force" -or $option -eq "no-verify") { $isForcePush = $true; break }
    }
}
$commandLine = $MyInvocation.Line
if ($commandLine -match '--force|-f') { $isForcePush = $true }

if ($isForcePush) {
    Report-Check "Force push" "Force push detected. Use 'git pull --rebase' instead." "fail"
} else {
    Report-Check "Force push" "" "pass"
}

# -------------------------------------------------------------------
# 3. Fetch remote + behind check
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[3/6] Checking remote sync..." -ForegroundColor Yellow
$ErrorActionPreference = "SilentlyContinue"
$currentBranch = git rev-parse --abbrev-ref HEAD
$remoteBranch = "origin/$currentBranch"
git fetch origin $currentBranch 2>&1 | Out-Null
$localCommit = git rev-parse HEAD 2>&1
$remoteCommit = git rev-parse $remoteBranch 2>&1
$ErrorActionPreference = "Stop"

if ($remoteCommit -and $remoteCommit -ne $localCommit) {
    $ErrorActionPreference = "SilentlyContinue"
    $behind = git rev-list --count "$localCommit..$remoteCommit" 2>&1
    $ErrorActionPreference = "Stop"
    if ($behind -and [int]$behind -gt 0) {
        Report-Check "Remote sync" "Local is $behind commit(s) behind. Run: git pull --rebase origin $currentBranch" "fail"
    } else {
        Report-Check "Remote sync" "" "pass"
    }
} else {
    Report-Check "Remote sync" "" "pass"
}

# -------------------------------------------------------------------
# 4. Merge conflicts
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[4/6] Checking for merge conflicts..." -ForegroundColor Yellow
$ErrorActionPreference = "SilentlyContinue"
$conflictMarkers = git diff --check 2>&1
$ErrorActionPreference = "Stop"

if ($conflictMarkers -match '<<<<<<<|=======|>>>>>>>') {
    Report-Check "Merge conflicts" "Conflict markers found. Resolve before pushing." "fail"
} else {
    Report-Check "Merge conflicts" "" "pass"
}

# -------------------------------------------------------------------
# 5. Fast code checks (compile + lint)
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[5/6] Running fast code checks (compile + lint)..." -ForegroundColor Yellow

$compileErrors = @()
foreach ($dir in $compileDirs) {
    if (Test-Path $dir) {
        $ErrorActionPreference = "SilentlyContinue"
        python -m compileall -q $dir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $compileErrors += $dir }
        $ErrorActionPreference = "Stop"
    }
}

if ($compileErrors.Count -eq 0) {
    Report-Check "Python compile" "" "pass"
} else {
    Report-Check "Python compile" "Syntax errors in: $($compileErrors -join ', ')" "fail"
}

$ErrorActionPreference = "SilentlyContinue"
$ruffArgs = @("check")
foreach ($exc in $ruffExcludes) { $ruffArgs += "--exclude=$exc" }
$ruffArgs += $ruffTargets
$ruffOutput = & ruff @ruffArgs 2>&1
$ruffExit = $LASTEXITCODE
$ErrorActionPreference = "Stop"

if ($ruffExit -eq 0) {
    Report-Check "Ruff lint" "" "pass"
} else {
    $errorLines = ($ruffOutput | Select-String -Pattern "error" -SimpleMatch)
    if ($errorLines) {
        Report-Check "Ruff lint" "Production code has lint errors. Run 'ruff check --fix .' to auto-fix." "fail"
    } else {
        Report-Check "Ruff lint" "Warnings found (non-blocking). Run 'ruff check .' for details." "warn"
    }
}

# -------------------------------------------------------------------
# 6. Secret scan in pushed commits
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[6/6] Scanning for secrets..." -ForegroundColor Yellow
$ErrorActionPreference = "SilentlyContinue"
$commitsToPush = git rev-list "$remoteCommit..$localCommit" 2>&1
$ErrorActionPreference = "Stop"

$secretPatterns = if ($script:SecretPatterns) { $script:SecretPatterns } else {
    @(
        'password\s*=\s*["''`]([^"''`]{8,})["''`]',
        'api[_-]?key\s*=\s*["''`]([^"''`]{10,})["''`]',
        'secret[_-]?key\s*=\s*["''`]([^"''`]{10,})["''`]',
        'token\s*=\s*["''`]([^"''`]{10,})["''`]'
    )
}
$secretSkipPathPattern = if ($script:SecretSkipPatterns) {
    ($script:SecretSkipPatterns -join '|')
} else {
    '_archive/|_ARCHIVE/'
}
$secretValueSkip = if ($script:SecretValueSkipPatterns) { $script:SecretValueSkipPatterns } else { '^\$|^\{|placeholder|your_|example\.com|localhost|^test_|^mock_' }

$foundSecrets = $false
if ($commitsToPush) {
    foreach ($commit in $commitsToPush) {
        $ErrorActionPreference = "SilentlyContinue"
        $files = git diff-tree --no-commit-id --name-only -r $commit 2>&1
        $ErrorActionPreference = "Stop"

        foreach ($file in $files) {
            $file = ($file -as [string]) -replace '[\r\n]', '' -replace '^\s+|\s+$', ''
            if (-not $file) { continue }
            if ($file -match $secretSkipPathPattern) { continue }
            $exists = $false
            try { $exists = Test-Path -LiteralPath $file } catch { continue }
            if (-not $exists) { continue }
            $content = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
            if ($content) {
                foreach ($pattern in $secretPatterns) {
                    if ($content -match $pattern) {
                        $captured = $Matches[1]
                        if ($captured -match $secretValueSkip) { continue }
                        Report-Check "Secret detection" "Potential secret in $file (commit $commit)" "fail"
                        $foundSecrets = $true
                        break
                    }
                }
            }
        }
    }
}

if (-not $foundSecrets) {
    Report-Check "Secret detection" "" "pass"
}

# ===================================================================
# CONSOLIDATED ERROR SUMMARY
# ===================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($script:HasErrors) {
    Write-Host "  PUSH BLOCKED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host $f -ForegroundColor Red }
    if ($script:HasWarnings) {
        Write-Host "" -ForegroundColor Yellow
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        foreach ($w in $script:Warnings) { Write-Host $w -ForegroundColor Yellow }
    }
    Write-Host ""
    Write-Host "Fix these issues, then push again." -ForegroundColor Yellow
    Write-Host "Full CI (integration, E2E) runs in GitHub Actions on PR." -ForegroundColor Gray
    exit 1
} elseif ($script:HasWarnings) {
    Write-Host "  PUSH ALLOWED (with warnings)" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    foreach ($w in $script:Warnings) { Write-Host $w -ForegroundColor Yellow }
    exit 0
} else {
    Write-Host "  ALL PRE-PUSH CHECKS PASSED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}
