<#
.SYNOPSIS
    Shared CI core engine. Called by each project's local_ci.ps1 after loading its .ci/config.ps1.
    Do not run this directly — use your project's local_ci.ps1 wrapper.
.DESCRIPTION
    All project-specific values come from variables set in .ci/config.ps1 before this script is dot-sourced.
    Steps 1-4: sequential (containers, Python deps, static checks, parallel unit tests).
    Step 5: parallel — integration batches + Playwright + Node/frontend jobs.
#>

$ErrorActionPreference = "Continue"
if (-not $ROOT) { $ROOT = $PWD.Path }
Set-Location $ROOT

# ── Required config variables (must be set by .ci/config.ps1) ────────────────
# $CI_PROJECT_LABEL          — docker compose project label (for force-remove)
# $CI_COMPOSE_FILE           — path to docker-compose.ci.yml relative to $ROOT
# $CI_CONTAINERS             — array of container names to health-check
# $CI_GOOGLE_CLOUD_PROJECT   — GCP project for test env
# $CI_FIRESTORE_HOST         — e.g. "localhost:8086"
# $CI_STORAGE_HOST           — e.g. "http://localhost:9023"
# $CI_REDIS_URL              — e.g. "redis://localhost:6399/0"
# $CI_PYTHONPATH_EXTRA       — extra paths appended to PYTHONPATH (array)
# $CI_CATALOG_DIR            — path to catalog source dir (or $null if not used)
# $CI_CATALOG_COMPILE_CMD    — scriptblock to compile catalog (or $null)
# $CI_COMPILEALL_TARGETS     — array of paths for python -m compileall
# $CI_RUFF_EXCLUDES          — array of --exclude args for ruff
# $CI_MYPY_TARGET            — path for mypy
# $CI_UNIT_PYTEST_FLAGS      — full pytest flag string for unit tests (must match deploy-staging)
# $CI_INTEGRATION_PYTEST_FLAGS — full pytest flag string for integration tests
# $CI_UNIT_TEST_SETS         — array of hashtables: @{Name="..."; Paths="..."}
# $CI_INTEGRATION_BATCHES    — array of hashtables: @{Name="..."; Paths="..."}
# $CI_PLAYWRIGHT_DIR         — path to run playwright from (or $null to skip)
# $CI_NODE_JOBS              — array of hashtables: @{Name="..."; Dir="..."; Steps=@("lint","build","test")}

$logDir = Join-Path $ROOT "ci_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Local CI - $CI_PROJECT_NAME" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ── Set env from config ───────────────────────────────────────────────────────
$env:GOOGLE_CLOUD_PROJECT    = $CI_GOOGLE_CLOUD_PROJECT
$env:FIRESTORE_EMULATOR_HOST = $CI_FIRESTORE_HOST
$env:STORAGE_EMULATOR_HOST   = $CI_STORAGE_HOST
$env:REDIS_URL               = $CI_REDIS_URL
$env:DEV_MODE                = "true"
$env:SKIP_AUTH               = "true"
$env:ENABLE_LICENSING        = "false"
$env:APP_ENV                 = "test"

$pyPaths = @($ROOT) + $CI_PYTHONPATH_EXTRA | ForEach-Object { $_ }
$env:PYTHONPATH = $pyPaths -join [System.IO.Path]::PathSeparator
if ($CI_CATALOG_DIR) { $env:CATALOG_DIR = $CI_CATALOG_DIR }

# ── Helpers ───────────────────────────────────────────────────────────────────
function Ensure-Emulators {
    param([string]$Context = "")
    $prefix = if ($Context) { "[$Context] " } else { "" }
    $healthy = $true
    foreach ($svc in $CI_CONTAINERS) {
        $state  = docker compose -f $CI_COMPOSE_FILE ps --format "{{.State}}"  $svc 2>$null
        $health = docker compose -f $CI_COMPOSE_FILE ps --format "{{.Health}}" $svc 2>$null
        if ($state -ne "running" -or ($health -and $health -ne "healthy")) {
            Write-Host "${prefix}Container '$svc' is $state/$health - restarting..." -ForegroundColor Red
            $healthy = $false
            break
        }
    }
    if (-not $healthy) {
        docker compose -f $CI_COMPOSE_FILE down 2>$null
        docker compose -f $CI_COMPOSE_FILE up -d --build --wait
        if ($LASTEXITCODE -ne 0) {
            Write-Host "${prefix}FATAL: Containers failed to restart." -ForegroundColor Red
            exit 1
        }
        Write-Host "${prefix}Containers restarted and healthy." -ForegroundColor Green
    }
}

function Test-EmulatorsHealthy {
    param([string]$LogDir)
    $report = @(); $ok = $true
    foreach ($svc in $CI_CONTAINERS) {
        $state  = docker compose -f $CI_COMPOSE_FILE ps --format "{{.State}}"  $svc 2>$null
        $health = docker compose -f $CI_COMPOSE_FILE ps --format "{{.Health}}" $svc 2>$null
        $report += "$svc : State=$state Health=$health"
        if ($state -ne "running" -or ($health -and $health -ne "healthy")) { $ok = $false }
    }
    if (-not $ok) { $report | Set-Content (Join-Path $LogDir "CONTAINER_FAILURE.txt") -Encoding UTF8 }
    return $ok
}

# ── [1/5] Kill CI containers, rebuild images, start new ───────────────────────
Write-Host "[1/5] Killing CI containers, rebuilding, starting ($($CI_CONTAINERS -join ', '))..." -ForegroundColor Yellow
docker compose -f $CI_COMPOSE_FILE down --remove-orphans 2>$null
docker ps -a -q --filter "label=com.docker.compose.project=$CI_PROJECT_LABEL" 2>$null |
    ForEach-Object { docker rm -f $_ 2>$null }
docker compose -f $CI_COMPOSE_FILE up -d --build --wait
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Retry: down and up again..." -ForegroundColor Red
    docker compose -f $CI_COMPOSE_FILE down 2>$null
    Start-Sleep -Seconds 3
    docker compose -f $CI_COMPOSE_FILE up -d --build --wait
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FATAL: CI containers failed to start." -ForegroundColor Red
        @"
Local CI: containers failed to start.
Project: $CI_PROJECT_NAME
Action: Run 'docker compose -f $CI_COMPOSE_FILE down --remove-orphans' then '...up -d --build --wait' manually to debug.
"@ | Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
        exit 1
    }
}
Write-Host "  Containers are up and healthy." -ForegroundColor Green

# ── Detect Python 3.10/3.11 ───────────────────────────────────────────────────
$pyVer = (python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null)
$PY = "python"
if ($pyVer -and ($pyVer -notmatch '^3\.(10|11)$')) {
    $py311Path = (py -3.11 -c "import sys; print(sys.executable)" 2>$null)
    if ($py311Path -and (Test-Path $py311Path.Trim())) {
        $PY = $py311Path.Trim()
        Write-Host "  Using Python 3.11 (default is $pyVer)" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: Python $pyVer detected. CI requires 3.10 or 3.11." -ForegroundColor Red
        exit 1
    }
}

# ── [2/5] Python deps + catalog bundle ────────────────────────────────────────
Write-Host "[2/5] Python: install deps, catalog bundle..." -ForegroundColor Yellow
& $PY -m pip install --upgrade pip -q
& $PY -m pip install -r requirements.txt -q
if ($CI_CATALOG_COMPILE_CMD) {
    New-Item -ItemType Directory -Force -Path dist | Out-Null
    & $CI_CATALOG_COMPILE_CMD
    if (-not (Test-Path dist/catalog_bundle.json)) {
        '{"meta":{"catalog_version_id":"test","catalog_name":"test"},"tables":{}}' |
            Set-Content dist/catalog_bundle.json -Encoding UTF8
    }
    Copy-Item dist/catalog_bundle.json dist/catalog_bundle_local.json -ErrorAction SilentlyContinue
}

# ── [3/5] Static analysis ──────────────────────────────────────────────────────
Write-Host "[3/5] Static checks: compile, ruff, mypy..." -ForegroundColor Yellow
if ($env:OS -match "Windows") {
    foreach ($t in $CI_COMPILEALL_TARGETS) {
        Get-ChildItem -Path $t -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
& $PY -m compileall -q @CI_COMPILEALL_TARGETS
& $PY -m pip install "ruff>=0.14.0" mypy types-requests -q 2>$null
$ruffExcludeArgs = $CI_RUFF_EXCLUDES | ForEach-Object { "--exclude=$_" }
& $PY -m ruff check @ruffExcludeArgs .
if ($LASTEXITCODE -ne 0) { exit 1 }
& $PY -m ruff format --check --diff .
if ($LASTEXITCODE -ne 0) { exit 1 }
# Non-blocking — matches local CI and reusable-static-checks behavior (ADR-001)
& $PY -m mypy $CI_MYPY_TARGET --config-file=mypy.ini
if ($LASTEXITCODE -ne 0) {
    Write-Host "  mypy reported issues (non-blocking)." -ForegroundColor Yellow
}

# ── [4/5] Unit tests (parallel sets) ──────────────────────────────────────────
Ensure-Emulators -Context "4"
Write-Host "[4/5] Unit tests ($($CI_UNIT_TEST_SETS.Count) parallel sets)..." -ForegroundColor Yellow

$unitJobs = @()
$unitExitFiles = @()
foreach ($set in $CI_UNIT_TEST_SETS) {
    $exitFile = Join-Path $logDir "unit_$($set.Name -replace '\s','_').exit"
    if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
    $unitExitFiles += $exitFile
    $unitJobs += Start-Job -ScriptBlock {
        param($Root, $Py, $ExitFile, $PathsStr, $FlagsStr, $EnvMap)
        Set-Location $Root
        foreach ($k in $EnvMap.Keys) { [System.Environment]::SetEnvironmentVariable($k, $EnvMap[$k]) }
        $paths = $PathsStr -split '\s+' | Where-Object { $_ -and (Test-Path $_) }
        if (-not $paths) { $paths = $PathsStr -split '\s+' }
        $flagList = $FlagsStr -split '\s+' | Where-Object { $_ }
        & $Py -m pytest $paths @flagList 2>&1
        $code = $LASTEXITCODE
        try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
        exit $code
    } -ArgumentList $ROOT, $PY, $exitFile, $set.Paths, $CI_UNIT_PYTEST_FLAGS, @{
        PYTHONPATH               = $env:PYTHONPATH
        CATALOG_DIR              = $env:CATALOG_DIR
        DEV_MODE                 = "true"
        SKIP_AUTH                = "true"
        ENABLE_LICENSING         = "false"
        APP_ENV                  = "test"
        GOOGLE_CLOUD_PROJECT     = $CI_GOOGLE_CLOUD_PROJECT
        FIRESTORE_EMULATOR_HOST  = $CI_FIRESTORE_HOST
        STORAGE_EMULATOR_HOST    = $CI_STORAGE_HOST
        REDIS_URL                = $CI_REDIS_URL
        USE_CLOUD_DATA           = "false"
    }
}
Wait-Job -Job $unitJobs -Timeout 1800 | Out-Null
$unitFailed = 0
for ($i = 0; $i -lt $unitJobs.Count; $i++) {
    $j = $unitJobs[$i]; $set = $CI_UNIT_TEST_SETS[$i]
    $ec = 1
    if ($j.State -eq "Completed" -and (Test-Path $unitExitFiles[$i])) {
        $ec = [int](Get-Content $unitExitFiles[$i] -Raw)
    }
    $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
    $color  = if ($ec -eq 0) { "Green" } else { "Red" }
    Write-Host "  [$($set.Name)] $status" -ForegroundColor $color
    if ($ec -ne 0) { $unitFailed = 1 }
    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
}
if ($unitFailed -ne 0) {
    "Local CI: unit tests failed. See ci_logs/ for details." |
        Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
    exit 1
}

# ── [5/5] Integration + Playwright + Node/Frontend jobs (all parallel) ─────────
Ensure-Emulators -Context "5"
$jobCount = $CI_INTEGRATION_BATCHES.Count +
            $(if ($CI_PLAYWRIGHT_DIR) { 1 } else { 0 }) +
            $CI_NODE_JOBS.Count
Write-Host "[5/5] $jobCount parallel jobs (integration x$($CI_INTEGRATION_BATCHES.Count), $(if ($CI_PLAYWRIGHT_DIR) { 'Playwright, ' })Node x$($CI_NODE_JOBS.Count))..." -ForegroundColor Yellow

# Integration batch jobs
$integrationJobs = @(); $integrationExitFiles = @()
foreach ($batch in $CI_INTEGRATION_BATCHES) {
    $exitFile = Join-Path $logDir "integration_$($batch.Name -replace '\s','_').exit"
    if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
    $integrationExitFiles += $exitFile
    $integrationJobs += Start-Job -ScriptBlock {
        param($Root, $Py, $ExitFile, $PathsStr, $FlagsStr, $EnvMap)
        Set-Location $Root
        foreach ($k in $EnvMap.Keys) { [System.Environment]::SetEnvironmentVariable($k, $EnvMap[$k]) }
        $paths = $PathsStr -split '\s+' | Where-Object { $_ -and (Test-Path $_) }
        if (-not $paths) { $paths = $PathsStr -split '\s+' }
        $flagList = $FlagsStr -split '\s+' | Where-Object { $_ }
        & $Py -m pytest $paths @flagList 2>&1
        $code = $LASTEXITCODE
        try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
        exit $code
    } -ArgumentList $ROOT, $PY, $exitFile, $batch.Paths, $CI_INTEGRATION_PYTEST_FLAGS, @{
        PYTHONPATH               = $env:PYTHONPATH
        CATALOG_DIR              = $env:CATALOG_DIR
        DEV_MODE                 = "true"
        SKIP_AUTH                = "false"
        ENABLE_LICENSING         = "true"
        APP_ENV                  = "test"
        GOOGLE_CLOUD_PROJECT     = $CI_GOOGLE_CLOUD_PROJECT
        FIRESTORE_EMULATOR_HOST  = $CI_FIRESTORE_HOST
        STORAGE_EMULATOR_HOST    = $CI_STORAGE_HOST
        REDIS_URL                = $CI_REDIS_URL
    }
}

# Playwright job
$playwrightJob = $null; $playwrightExitFile = $null
if ($CI_PLAYWRIGHT_DIR) {
    $playwrightExitFile = Join-Path $logDir "playwright.exit"
    if (Test-Path $playwrightExitFile) { Remove-Item $playwrightExitFile -Force }
    $playwrightJob = Start-Job -ScriptBlock {
        param($Dir, $ExitFile)
        Set-Location $Dir
        npx playwright install --with-deps chromium 2>$null
        npx playwright test --project=chromium 2>&1
        $code = $LASTEXITCODE
        try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
        exit $code
    } -ArgumentList $CI_PLAYWRIGHT_DIR, $playwrightExitFile
}

# Node/frontend jobs
$nodeJobs = @(); $nodeExitFiles = @()
foreach ($job in $CI_NODE_JOBS) {
    $exitFile = Join-Path $logDir "node_$($job.Name -replace '\s','_').exit"
    if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
    $nodeExitFiles += $exitFile
    $nodeJobs += Start-Job -ScriptBlock {
        param($Root, $JobDir, $Steps, $ExitFile)
        Set-Location (Join-Path $Root $JobDir)
        $code = 0
        npm ci --no-audit --no-fund 2>$null; if ($LASTEXITCODE -ne 0) { npm install }
        if ($Steps -contains "lint")   { npm run lint 2>&1 | Out-Null;   if ($LASTEXITCODE -ne 0) { $code = 1 } }
        if ($code -eq 0 -and $Steps -contains "format") { npm run format:check 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { $code = 1 } }
        if ($code -eq 0 -and $Steps -contains "tsc")    { npx tsc -b 2>&1 | Out-Null;           if ($LASTEXITCODE -ne 0) { $code = 1 } }
        if ($code -eq 0 -and $Steps -contains "build")  { npm run build 2>&1 | Out-Null;        if ($LASTEXITCODE -ne 0) { $code = 1 } }
        if ($code -eq 0 -and $Steps -contains "test")   { npm test -- --run 2>&1 | Out-Null;    if ($LASTEXITCODE -ne 0) { $code = 1 } }
        if ($code -eq 0 -and $Steps -contains "test:cov") { npm test -- --run --coverage 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { $code = 1 } }
        try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
        exit $code
    } -ArgumentList $ROOT, $job.Dir, $job.Steps, $exitFile
}

$allJobs = $integrationJobs + @($nodeJobs)
if ($playwrightJob) { $allJobs += $playwrightJob }
Wait-Job -Job $allJobs -Timeout 3600 | Out-Null

# Collect integration results
$integrationFailed = 0
for ($i = 0; $i -lt $integrationJobs.Count; $i++) {
    $j = $integrationJobs[$i]; $batch = $CI_INTEGRATION_BATCHES[$i]
    $ec = 1
    if ($j.State -eq "Completed" -and (Test-Path $integrationExitFiles[$i])) {
        $ec = [int](Get-Content $integrationExitFiles[$i] -Raw)
    }
    $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
    $color  = if ($ec -eq 0) { "Green" } else { "Red" }
    Write-Host "  [$($batch.Name)] $status" -ForegroundColor $color
    if ($ec -ne 0) { $integrationFailed = 1 }
    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
}

# Collect Playwright result
$playwrightFailed = 0
if ($playwrightJob) {
    $ec = 1
    if ($playwrightJob.State -eq "Completed" -and (Test-Path $playwrightExitFile)) {
        $ec = [int](Get-Content $playwrightExitFile -Raw)
    }
    $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
    $color  = if ($ec -eq 0) { "Green" } else { "Red" }
    Write-Host "  [Playwright] $status" -ForegroundColor $color
    if ($ec -ne 0) { $playwrightFailed = 1 }
    Remove-Job -Job $playwrightJob -Force -ErrorAction SilentlyContinue
}

# Collect Node/frontend results
$nodeFailed = 0
for ($i = 0; $i -lt $nodeJobs.Count; $i++) {
    $j = $nodeJobs[$i]; $job = $CI_NODE_JOBS[$i]
    $ec = 1
    if ($j.State -eq "Completed" -and (Test-Path $nodeExitFiles[$i])) {
        $ec = [int](Get-Content $nodeExitFiles[$i] -Raw)
    }
    $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
    $color  = if ($ec -eq 0) { "Green" } else { "Red" }
    Write-Host "  [$($job.Name)] $status" -ForegroundColor $color
    if ($ec -ne 0) { $nodeFailed = 1 }
    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
}

# Container health check after all jobs
if (-not (Test-EmulatorsHealthy -LogDir $logDir)) {
    Write-Host "Containers became unavailable during CI." -ForegroundColor Red
    Get-Content (Join-Path $logDir "CONTAINER_FAILURE.txt") -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

if ($integrationFailed -ne 0 -or $playwrightFailed -ne 0 -or $nodeFailed -ne 0) {
    @(
        "Local CI failed - $CI_PROJECT_NAME",
        "Integration:  $(if ($integrationFailed) { 'FAIL' } else { 'PASS' })",
        "Playwright:   $(if ($playwrightFailed)  { 'FAIL' } else { 'PASS' })",
        "Node/frontend: $(if ($nodeFailed)       { 'FAIL' } else { 'PASS' })",
        "",
        "See ci_logs/ for per-job exit files."
    ) | Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
    exit 1
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
Write-Host "Stopping CI containers..." -ForegroundColor Gray
docker compose -f $CI_COMPOSE_FILE down 2>$null

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Local CI PASSED - $CI_PROJECT_NAME" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
exit 0
