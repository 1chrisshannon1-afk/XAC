<#
.SYNOPSIS
    Verifies a developer's machine has everything needed to run local CI.
.DESCRIPTION
    Run standalone at any time. Checks Docker, Python, Node, gh, git, IAC/_XAC (shared CI),
    project .ci/config.ps1, docker-compose.ci.yml, and .secrets.baseline. Colored PASS/FAIL per check.
.EXAMPLE
    .\_XAC\ci\scripts\verify-setup.ps1
#>

$ErrorActionPreference = "Continue"
$ROOT = $PSScriptRoot
# When run as repo\_XAC\ci\scripts: _XAC root is two levels up, project root is three levels up
$SharedPath = (Get-Item $ROOT).Parent.Parent.FullName
$ProjectRoot = (Get-Item $ROOT).Parent.Parent.Parent.FullName
# If .ci\config.ps1 not at that project root, assume current directory is project root
if (-not (Test-Path (Join-Path $ProjectRoot ".ci\config.ps1"))) {
    $ProjectRoot = $PWD.Path
    $SharedPath = Join-Path $ProjectRoot "_XAC"
}

$failed = 0

function Pass { param($msg) Write-Host "  PASS: $msg" -ForegroundColor Green }
function Fail { param($msg) Write-Host "  FAIL: $msg" -ForegroundColor Red; $script:failed++ }

Write-Host "Verify setup (project root: $ProjectRoot)" -ForegroundColor Cyan

# Docker
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -eq 0) { Pass "Docker installed and running" } else { Fail "Docker not running or not installed" }
} catch { Fail "Docker not found" }

try {
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) { Pass "docker compose v2 available" } else { Fail "docker compose v2 not found" }
} catch { Fail "docker compose not found" }

# Python 3.11
$py = $null
foreach ($cmd in @("python", "py")) {
    $v = & $cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    if ($v -match "3\.(10|11)") { $py = $cmd; break }
}
if ($py) { Pass "Python 3.10 or 3.11 available ($py)" } else { Fail "Python 3.10 or 3.11 not found" }

# Node 20+
$nodeVer = node --version 2>$null
if ($nodeVer -match "v(\d+)") {
    $major = [int]$Matches[1]
    if ($major -ge 20) { Pass "Node $nodeVer" } else { Fail "Node 20+ required (found $nodeVer)" }
} else { Fail "Node not found" }

# gh
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) { Pass "gh CLI installed and authenticated" } else { Fail "gh CLI not authenticated" }
} else { Fail "gh CLI not installed" }

# git
if (Get-Command git -ErrorAction SilentlyContinue) { Pass "git installed" } else { Fail "git not installed" }

# XAC shared content (inside repo or sibling)
if (Test-Path $SharedPath) {
    $core = Join-Path $SharedPath "ci\local_ci\core.ps1"
    if (Test-Path $core) { Pass "XAC at $SharedPath" } else { Fail "XAC path exists but ci\local_ci\core.ps1 missing" }
} else { Fail "XAC not found at $SharedPath" }

# Project files
$configPath = Join-Path $ProjectRoot ".ci\config.ps1"
if (Test-Path $configPath) { Pass "Project .ci/config.ps1 exists" } else { Fail "Project .ci/config.ps1 missing" }

$composePath = Join-Path $ProjectRoot "docker-compose.ci.yml"
if (Test-Path $composePath) { Pass "Project docker-compose.ci.yml exists" } else { Fail "Project docker-compose.ci.yml missing" }

$baselinePath = Join-Path $ProjectRoot ".secrets.baseline"
if (Test-Path $baselinePath) { Pass "Project .secrets.baseline exists" } else { Fail "Project .secrets.baseline missing" }

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed check(s) failed." -ForegroundColor Red
    exit 1
}
