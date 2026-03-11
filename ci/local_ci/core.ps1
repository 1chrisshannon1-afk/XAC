# Shared CI core engine. Called by each project's local_ci.ps1 after loading .ci/config.ps1. Do not run directly.
# Steps 1-4: containers, Python deps, static checks, parallel unit tests.
# Step 5: dynamic batches — integration, Playwright (multi-suite), Node/frontend — count driven by config.

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
# $CI_PLAYWRIGHT_DIR         — (legacy) single Playwright dir, used when $CI_PLAYWRIGHT_SUITES is not set
# $CI_PLAYWRIGHT_BATCHES     — (legacy) batches for single-dir Playwright
# $CI_PLAYWRIGHT_SUITES      — (preferred) array of @{Name="..."; Dir="..."; Batches=@(@{Name="..."; Paths="..."},...)})
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
function Invoke-EmulatorCheck {
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

# ── Detect Python version (from config $CI_PYTHON_VERSION, default 3.11) ───────
$requiredPy = if ($CI_PYTHON_VERSION) { $CI_PYTHON_VERSION } else { "3.11" }
$pyVer = (python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null)
$PY = "python"
$pyMatch = "^$($requiredPy -replace '\.', '\.')$"
if ($pyVer -and ($pyVer -notmatch $pyMatch)) {
    $pyPath = (py "-$requiredPy" -c "import sys; print(sys.executable)" 2>$null)
    if ($pyPath -and (Test-Path $pyPath.Trim())) {
        $PY = $pyPath.Trim()
        Write-Host "  Using Python $requiredPy (default is $pyVer)" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: Python $pyVer detected. CI requires $requiredPy (set `$CI_PYTHON_VERSION in config.ps1)." -ForegroundColor Red
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
Invoke-EmulatorCheck -Context "4"
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

# ── [5/9] Phase 2 — integration, Playwright, Node (batches 5a–5i) ───────────────
# Helper: run one integration batch, return 0 on success else 1
function Invoke-SingleIntegrationBatch {
    param([hashtable]$Batch, [int]$TimeoutSeconds)
    $exitFile = Join-Path $logDir "integration_$($Batch.Name -replace '\s','_').exit"
    if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
    $j = Start-Job -ScriptBlock {
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
    } -ArgumentList $ROOT, $PY, $exitFile, $Batch.Paths, $CI_INTEGRATION_PYTEST_FLAGS, @{
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
    Wait-Job -Job $j -Timeout $TimeoutSeconds | Out-Null
    $ec = 1
    if ($j.State -eq "Completed" -and (Test-Path $exitFile)) { $ec = [int](Get-Content $exitFile -Raw) }
    elseif ($j.State -ne "Completed") {
        Write-Host "  [$($Batch.Name)] TIMEOUT or RUNNING" -ForegroundColor Red
        Stop-Job -Job $j -ErrorAction SilentlyContinue
    }
    $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
    $color  = if ($ec -eq 0) { "Green" } else { "Red" }
    Write-Host "  [$($Batch.Name)] $status" -ForegroundColor $color
    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    return $ec
}

# Helper: run one Node/frontend job, return 0 on success else 1
function Invoke-SingleNodeJob {
    param([hashtable]$Job, [int]$TimeoutSeconds)
    $exitFile = Join-Path $logDir "node_$($Job.Name -replace '\s','_').exit"
    if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
    $j = Start-Job -ScriptBlock {
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
    } -ArgumentList $ROOT, $Job.Dir, $Job.Steps, $exitFile
    Wait-Job -Job $j -Timeout $TimeoutSeconds | Out-Null
    $ec = 1
    if ($j.State -eq "Completed" -and (Test-Path $exitFile)) { $ec = [int](Get-Content $exitFile -Raw) }
    elseif ($j.State -ne "Completed") {
        Write-Host "  [$($Job.Name)] TIMEOUT or RUNNING" -ForegroundColor Red
        Stop-Job -Job $j -ErrorAction SilentlyContinue
    }
    $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
    $color  = if ($ec -eq 0) { "Green" } else { "Red" }
    Write-Host "  [$($Job.Name)] $status" -ForegroundColor $color
    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    return $ec
}

$integrationBatchTimeout = 600   # 10 min per integration batch
$nodeJobTimeout = 600            # 10 min per Node job (frontend tests can be slow)
$playwrightTimeout = 600   # 10 min per Playwright batch (no step > 10 min)

$phaseLabels = @("5a", "5b", "5c", "5d")
# 5a–5d – Integration batches (one per batch in config)
for ($i = 0; $i -lt $CI_INTEGRATION_BATCHES.Count; $i++) {
    $batch = $CI_INTEGRATION_BATCHES[$i]
    $label = if ($i -lt $phaseLabels.Count) { $phaseLabels[$i] } else { "5$([char](97 + $i))" }
    Invoke-EmulatorCheck -Context $label
    Write-Host "[$label/9] Integration: $($batch.Name) (timeout 10 min)..." -ForegroundColor Yellow
    if (Invoke-SingleIntegrationBatch $batch $integrationBatchTimeout) {
        "Local CI: integration ($label) failed." | Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
        docker compose -f $CI_COMPOSE_FILE down 2>$null; exit 1
    }
}

# 5e – Playwright
if ($CI_PLAYWRIGHT_DIR) {
    Invoke-EmulatorCheck -Context "5e"
    $playwrightBatches = if ($CI_PLAYWRIGHT_BATCHES -and $CI_PLAYWRIGHT_BATCHES.Count -gt 0) { $CI_PLAYWRIGHT_BATCHES } else { @(@{ Name = "Playwright"; Paths = "" }) }
    $batchIdx = 0
    foreach ($pwBatch in $playwrightBatches) {
        $batchIdx++
        $label = if ($playwrightBatches.Count -gt 1) { "5e-$batchIdx/$($playwrightBatches.Count)" } else { "5e/9" }
        Write-Host "[$label] Playwright: $($pwBatch.Name) (timeout 10 min)..." -ForegroundColor Yellow
        $playwrightExitFile = Join-Path $logDir "playwright_$batchIdx.exit"
        if (Test-Path $playwrightExitFile) { Remove-Item $playwrightExitFile -Force }
        $playwrightJob = Start-Job -ScriptBlock {
            param($Dir, $ExitFile, $PathsStr)
            Set-Location $Dir
            npx playwright install --with-deps chromium 2>$null
            $paths = $PathsStr -split '\s+' | Where-Object { $_ }
            if ($paths) { npx playwright test --project=chromium $paths 2>&1 } else { npx playwright test --project=chromium 2>&1 }
            $code = $LASTEXITCODE
            try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
            exit $code
        } -ArgumentList $CI_PLAYWRIGHT_DIR, $playwrightExitFile, $pwBatch.Paths
        Wait-Job -Job $playwrightJob -Timeout $playwrightTimeout | Out-Null
        $ec = 1
        if ($playwrightJob.State -eq "Completed" -and (Test-Path $playwrightExitFile)) { $ec = [int](Get-Content $playwrightExitFile -Raw) }
        elseif ($playwrightJob.State -ne "Completed") { Write-Host "  [$($pwBatch.Name)] TIMEOUT or RUNNING" -ForegroundColor Red }
        $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }; $color = if ($ec -eq 0) { "Green" } else { "Red" }
        Write-Host "  [$($pwBatch.Name)] $status" -ForegroundColor $color
        Remove-Job -Job $playwrightJob -Force -ErrorAction SilentlyContinue
        if ($ec -ne 0) {
            "Local CI: Playwright ($label) failed." | Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
            docker compose -f $CI_COMPOSE_FILE down 2>$null; exit 1
        }
    }
}

# 5f – Node lint/format
Write-Host "[5f/9] Node: lint/format (timeout 10 min)..." -ForegroundColor Yellow
if (Invoke-SingleNodeJob $CI_NODE_JOBS[0] $nodeJobTimeout) {
    "Local CI: Node lint/format (5f) failed." | Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
    docker compose -f $CI_COMPOSE_FILE down 2>$null; exit 1
}

# 5g–5i – Remaining Node/frontend jobs (one per job in config)
$nodeStepNames = @("5g", "5h", "5i")
for ($idx = 1; $idx -lt $CI_NODE_JOBS.Count; $idx++) {
    $stepLabel = if ($idx -le $nodeStepNames.Count) { $nodeStepNames[$idx - 1] } else { "5$([char](96 + $idx + 4))" }
    Write-Host "[$stepLabel/9] Node: $($CI_NODE_JOBS[$idx].Name) (timeout 10 min)..." -ForegroundColor Yellow
    if (Invoke-SingleNodeJob $CI_NODE_JOBS[$idx] $nodeJobTimeout) {
        "Local CI: Node $($CI_NODE_JOBS[$idx].Name) ($stepLabel) failed." | Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
        docker compose -f $CI_COMPOSE_FILE down 2>$null; exit 1
    }
}

# Container health check after all jobs
$emulatorsOk = Test-EmulatorsHealthy -LogDir $logDir
if (-not $emulatorsOk) {
    Write-Host "Containers became unavailable during CI." -ForegroundColor Red
    $reportPath = Join-Path $logDir "CONTAINER_FAILURE.txt"
    if (Test-Path $reportPath) {
        Get-Content $reportPath -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
Write-Host "Stopping CI containers..." -ForegroundColor Gray
docker compose -f $CI_COMPOSE_FILE down 2>$null

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Local CI PASSED - $CI_PROJECT_NAME" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
exit 0
