# XAC Git Hooks Installer
# Installs pre-commit and pre-push hooks from _XAC/ci/hooks/ into .git/hooks/

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  INSTALLING XAC GIT HOOKS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path ".git")) {
    Write-Host "ERROR: Not in a git repository. Run from the project root." -ForegroundColor Red
    exit 1
}

$hooksDir = ".git\hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}

$hooksSourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Install pre-commit hook
Write-Host "[1/3] Installing pre-commit hook..." -ForegroundColor Yellow
$preCommitSource = Join-Path $hooksSourceDir "pre-commit.ps1"
$preCommitDest = Join-Path $hooksDir "pre-commit"

if (Test-Path $preCommitSource) {
    Copy-Item $preCommitSource -Destination "$preCommitDest.ps1" -Force

    $preCommitWrapper = @"
#!/bin/sh
powershell.exe -ExecutionPolicy Bypass -File ".git\hooks\pre-commit.ps1"
exit `$?
"@
    $preCommitWrapper | Out-File -FilePath $preCommitDest -Encoding ASCII -NoNewline
    Write-Host "  OK  pre-commit" -ForegroundColor Green
} else {
    Write-Host "  ERROR: pre-commit.ps1 not found at $preCommitSource" -ForegroundColor Red
    exit 1
}

# Install pre-push hook
Write-Host "[2/3] Installing pre-push hook..." -ForegroundColor Yellow
$prePushSource = Join-Path $hooksSourceDir "pre-push.ps1"
$prePushDest = Join-Path $hooksDir "pre-push"

if (Test-Path $prePushSource) {
    Copy-Item $prePushSource -Destination "$prePushDest.ps1" -Force

    $prePushWrapper = @"
#!/bin/sh
powershell.exe -ExecutionPolicy Bypass -File ".git\hooks\pre-push.ps1" "`$1" "`$2"
exit `$?
"@
    $prePushWrapper | Out-File -FilePath $prePushDest -Encoding ASCII -NoNewline
    Write-Host "  OK  pre-push" -ForegroundColor Green
} else {
    Write-Host "  ERROR: pre-push.ps1 not found at $prePushSource" -ForegroundColor Red
    exit 1
}

# Copy secret patterns
Write-Host "[3/3] Copying secret patterns..." -ForegroundColor Yellow
$secretSource = Join-Path $hooksSourceDir "secret_patterns.ps1"
if (Test-Path $secretSource) {
    Copy-Item $secretSource -Destination "$hooksDir\secret_patterns.ps1" -Force
    Write-Host "  OK  secret_patterns" -ForegroundColor Green
}

# Make executable on Unix-like systems
if (Get-Command chmod -ErrorAction SilentlyContinue) {
    chmod +x $preCommitDest
    chmod +x $prePushDest
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  GIT HOOKS INSTALLED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Pre-commit: Ruff, compile, secret scan, commit message format" -ForegroundColor Gray
Write-Host "Pre-push:   Uncommitted changes, force push, remote sync, compile, lint, secrets" -ForegroundColor Gray
Write-Host ""
Write-Host "To bypass: git commit --no-verify / git push --no-verify" -ForegroundColor Yellow
