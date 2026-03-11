# XAC Pre-Commit Hook — ensures code quality and enforces commit message format.
# Shared hook pattern. Project-specific paths come from .ci/config.ps1.
# Install via: _XAC/ci/hooks/install.ps1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PRE-COMMIT SAFETY CHECKS" -ForegroundColor Cyan
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
$ruffExcludeArgs = ($ruffExcludes | ForEach-Object { "--exclude=$_" }) -join " "

# Load secret patterns if available
$secretPatternsFile = Join-Path $PSScriptRoot "secret_patterns.ps1"
if (Test-Path $secretPatternsFile) { . $secretPatternsFile }

# -------------------------------------------------------------------
# 1. Check for staged files
# -------------------------------------------------------------------
Write-Host "[1/6] Checking staged files..." -ForegroundColor Yellow
$stagedFiles = git diff --cached --name-only
if (-not $stagedFiles) {
    Report-Check "Staged files" "No files staged. Use 'git add' first." "fail"
} else {
    Report-Check "Staged files" "Found $($stagedFiles.Count) file(s)" "pass"
}

# -------------------------------------------------------------------
# 2. Ruff auto-fix + format
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Running Ruff auto-fix..." -ForegroundColor Yellow
$ErrorActionPreference = "SilentlyContinue"
$ruffArgs = @("check", "--fix", "--unsafe-fixes", ".")
foreach ($exc in $ruffExcludes) { $ruffArgs += "--exclude=$exc" }
$ruffOutput = & ruff @ruffArgs 2>&1
$ruffExitCode = $LASTEXITCODE
ruff format . 2>&1 | Out-Null
$ErrorActionPreference = "Stop"

if ($ruffExitCode -eq 0) {
    Report-Check "Ruff auto-fix" "Passed" "pass"
} else {
    $unfixable = $ruffOutput | Select-String -Pattern "error|Error|ERROR" -Quiet
    if ($unfixable) {
        Report-Check "Ruff auto-fix" "Unfixable errors found. Run 'ruff check .' for details." "fail"
    } else {
        Report-Check "Ruff auto-fix" "Warnings only (non-blocking)" "warn"
    }
}

# -------------------------------------------------------------------
# 3. Compile check
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[3/6] Verifying code compiles..." -ForegroundColor Yellow
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
    Report-Check "Python compile" "All files compile" "pass"
} else {
    Report-Check "Python compile" "Syntax errors in: $($compileErrors -join ', ')" "fail"
}

# -------------------------------------------------------------------
# 4. Secret scan in staged files
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[4/6] Checking for secrets..." -ForegroundColor Yellow
$secretPatterns = if ($script:SecretPatterns) { $script:SecretPatterns } else {
    @(
        'password\s*=\s*["''`]([^"''`]{8,})["''`]',
        'api[_-]?key\s*=\s*["''`]([^"''`]{10,})["''`]',
        'secret[_-]?key\s*=\s*["''`]([^"''`]{10,})["''`]',
        'token\s*=\s*["''`]([^"''`]{10,})["''`]'
    )
}
$secretSkipFiles = if ($script:SecretSkipPatterns) { $script:SecretSkipPatterns } else { @('_archive[\\/]', '_ARCHIVE[\\/]') }
$secretValueSkip = if ($script:SecretValueSkipPatterns) { $script:SecretValueSkipPatterns } else { '^\$|^\{|placeholder|your_|example\.com|localhost|^test_|^mock_' }

$foundSecrets = $false
foreach ($file in $stagedFiles) {
    $skipSecretCheck = ($secretSkipFiles | Where-Object { $file -match $_ })
    if ($skipSecretCheck) { continue }
    if (Test-Path $file) {
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if ($content) {
            foreach ($pattern in $secretPatterns) {
                if ($content -match $pattern) {
                    $captured = $Matches[1]
                    if ($captured -match $secretValueSkip) { continue }
                    Report-Check "Secret detection" "Potential secret in $file" "fail"
                    $foundSecrets = $true
                    break
                }
            }
        }
    }
}

if (-not $foundSecrets) {
    Report-Check "Secret detection" "No secrets found" "pass"
}

# -------------------------------------------------------------------
# 5. Fast tests (warning only)
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[5/6] Running fast tests (warning only)..." -ForegroundColor Yellow
$fastTestScript = "integration_tests\ESTIMATE_STUDIO\scripts\test_fast.ps1"
if (Test-Path $fastTestScript) {
    $ErrorActionPreference = "SilentlyContinue"
    $testOutput = & $fastTestScript 2>&1
    $testExitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"

    if ($testExitCode -eq 0) {
        Report-Check "Fast tests" "Passed" "pass"
    } else {
        Report-Check "Fast tests" "Failed (commit allowed, but push will be blocked)" "warn"
    }
} else {
    Report-Check "Fast tests" "test_fast.ps1 not found (skipping)" "pass"
}

# -------------------------------------------------------------------
# 6. Commit message format (ENFORCED)
# -------------------------------------------------------------------
Write-Host ""
Write-Host "[6/6] Validating commit message format..." -ForegroundColor Yellow
$commitMsgFile = ".git\COMMIT_EDITMSG"
if (Test-Path $commitMsgFile) {
    $commitMsg = (Get-Content $commitMsgFile -Raw).Trim()
    $conventionalPattern = '^(feat|fix|refactor|test|docs|chore|ci|build|perf|style|revert)(\(.+\))?:\s+.+'
    if ($commitMsg -match $conventionalPattern) {
        Report-Check "Commit message" "Follows conventional format" "pass"
    } else {
        Report-Check "Commit message" "Must match: <type>(<scope>): <description>" "fail"
        Write-Host "        Allowed types: feat|fix|refactor|test|docs|chore|ci|build|perf|style|revert" -ForegroundColor Gray
    }
} else {
    Report-Check "Commit message" "Message file not found (will validate on commit)" "pass"
}

# ===================================================================
# CONSOLIDATED ERROR SUMMARY
# ===================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($script:HasErrors) {
    Write-Host "  COMMIT BLOCKED" -ForegroundColor Red
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
    Write-Host "Fix these issues, then commit again." -ForegroundColor Yellow
    Write-Host "Bypass (NOT RECOMMENDED): git commit --no-verify" -ForegroundColor Gray
    exit 1
} elseif ($script:HasWarnings) {
    Write-Host "  COMMIT ALLOWED (with warnings)" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    foreach ($w in $script:Warnings) { Write-Host $w -ForegroundColor Yellow }
    exit 0
} else {
    Write-Host "  ALL PRE-COMMIT CHECKS PASSED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}
