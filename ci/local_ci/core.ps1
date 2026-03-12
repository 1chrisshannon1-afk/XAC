# XAC shared CI core engine.
# Called by each project's local_ci.ps1 after loading .ci/config.ps1.
# Do not run directly. All parallelism is driven by the arrays the project config supplies.
#
# Pipeline:
#   [1] Containers   — rebuild and health-check emulators
#   [2] Python deps  — pip install, catalog compile
#   [3] One parallel wave — Static + Unit + Integration + Node + Playwright (all at once)
#   [4] Cleanup      — stop containers, report
# Total wall time ≈ containers + deps + max(static, unit, integration, node, playwright).

$ErrorActionPreference = "Continue"
if (-not $ROOT) { $ROOT = $PWD.Path }
Set-Location $ROOT

# ── Required config variables (must be set by project .ci/config.ps1) ────────
# $CI_PROJECT_NAME, $CI_PROJECT_LABEL
# $CI_COMPOSE_FILE, $CI_CONTAINERS
# $CI_GOOGLE_CLOUD_PROJECT, $CI_FIRESTORE_HOST, $CI_STORAGE_HOST, $CI_REDIS_URL
# $CI_PYTHONPATH_EXTRA, $CI_CATALOG_DIR, $CI_CATALOG_COMPILE_CMD
# $CI_COMPILEALL_TARGETS, $CI_RUFF_EXCLUDES, $CI_MYPY_TARGET, $CI_MYPY_BLOCKING
# $CI_UNIT_PYTEST_FLAGS, $CI_INTEGRATION_PYTEST_FLAGS
# $CI_UNIT_TEST_SETS    — @(@{Name; Paths}, ...)
# $CI_INTEGRATION_BATCHES — @(@{Name; Paths}, ...)
# $CI_NODE_JOBS           — @(@{Name; Dir; Steps}, ...) or $null
# $CI_PLAYWRIGHT_SUITES   — @(@{Name; Dir; Batches=@(@{Name; Paths}, ...)}, ...) or $null

$logDir = Join-Path $ROOT "ci_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$totalSteps = 4
$parallelWaveTimeout = 900   # 15 min max for the whole wave (should be ~10 min if parallel enough)
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
$CI_CONTAINER_MAX_RETRIES = 3   # kill+restart up to 3 times before failing (4 attempts total)

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
        $attempt = 0
        $succeeded = $false
        while ($attempt -le $CI_CONTAINER_MAX_RETRIES) {
            $attempt++
            if ($attempt -gt 1) {
                Write-Host "${prefix}Retry $($attempt - 1)/${CI_CONTAINER_MAX_RETRIES}: down and up again..." -ForegroundColor Yellow
                docker compose -f $CI_COMPOSE_FILE down 2>$null
                Start-Sleep -Seconds 3
            }
            docker compose -f $CI_COMPOSE_FILE up -d --build --wait
            if ($LASTEXITCODE -eq 0) { $succeeded = $true; break }
        }
        if (-not $succeeded) {
            Write-Host "${prefix}FATAL: Containers failed to restart after $CI_CONTAINER_MAX_RETRIES retries." -ForegroundColor Red
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

# Shared env map for pytest jobs (unit/integration differ on SKIP_AUTH and ENABLE_LICENSING)
function Get-PytestEnv {
    param([bool]$IsIntegration = $false)
    return @{
        PYTHONPATH               = $env:PYTHONPATH
        CATALOG_DIR              = $env:CATALOG_DIR
        DEV_MODE                 = "true"
        SKIP_AUTH                = if ($IsIntegration) { "false" } else { "true" }
        ENABLE_LICENSING         = if ($IsIntegration) { "true" } else { "false" }
        APP_ENV                  = "test"
        GOOGLE_CLOUD_PROJECT     = $CI_GOOGLE_CLOUD_PROJECT
        FIRESTORE_EMULATOR_HOST  = $CI_FIRESTORE_HOST
        STORAGE_EMULATOR_HOST    = $CI_STORAGE_HOST
        REDIS_URL                = $CI_REDIS_URL
        USE_CLOUD_DATA           = "false"
    }
}

# Generic parallel pytest runner — accepts any array of @{Name; Paths}, flags, and env.
# Returns 0 if all pass, 1 if any fail.
function Invoke-ParallelPytest {
    param(
        [array]$Sets,
        [string]$Flags,
        [hashtable]$EnvMap,
        [string]$Prefix,        # "unit" or "integration" — for exit file naming
        [int]$TimeoutSeconds = 1800
    )
    $jobs = @(); $exitFiles = @()
    foreach ($set in $Sets) {
        $exitFile = Join-Path $logDir "${Prefix}_$($set.Name -replace '\s','_').exit"
        if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
        $exitFiles += $exitFile
        $jobs += Start-Job -ScriptBlock {
            param($Root, $Py, $ExitFile, $PathsStr, $FlagsStr, $Env)
            Set-Location $Root
            foreach ($k in $Env.Keys) { [System.Environment]::SetEnvironmentVariable($k, $Env[$k]) }
            $paths = $PathsStr -split '\s+' | Where-Object { $_ -and (Test-Path $_) }
            if (-not $paths) { $paths = $PathsStr -split '\s+' }
            $flagList = $FlagsStr -split '\s+' | Where-Object { $_ }
            & $Py -m pytest $paths @flagList 2>&1
            $code = $LASTEXITCODE
            try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
            exit $code
        } -ArgumentList $ROOT, $PY, $exitFile, $set.Paths, $Flags, $EnvMap
    }
    Wait-Job -Job $jobs -Timeout $TimeoutSeconds | Out-Null
    $failed = 0
    for ($i = 0; $i -lt $jobs.Count; $i++) {
        $j = $jobs[$i]; $set = $Sets[$i]
        $ec = 1
        if ($j.State -eq "Completed" -and (Test-Path $exitFiles[$i])) {
            $ec = [int](Get-Content $exitFiles[$i] -Raw)
        } elseif ($j.State -ne "Completed") {
            Write-Host "  [$($set.Name)] TIMEOUT" -ForegroundColor Red
            Stop-Job -Job $j -ErrorAction SilentlyContinue
        }
        $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
        $color  = if ($ec -eq 0) { "Green" } else { "Red" }
        Write-Host "  [$($set.Name)] $status" -ForegroundColor $color
        if ($ec -ne 0) {
            $failed = 1
            $logFile = Join-Path $logDir "${Prefix}_$($set.Name -replace '\s','_').log"
            Receive-Job -Job $j 2>$null | Set-Content -Path $logFile -Encoding utf8 -ErrorAction SilentlyContinue
        }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $failed
}

# Generic parallel Node runner — accepts any array of @{Name; Dir; Steps}.
function Invoke-ParallelNode {
    param(
        [array]$Jobs,
        [int]$TimeoutSeconds = 600
    )
    $bgJobs = @(); $exitFiles = @()
    foreach ($nJob in $Jobs) {
        $exitFile = Join-Path $logDir "node_$($nJob.Name -replace '\s','_').exit"
        if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
        $exitFiles += $exitFile
        $bgJobs += Start-Job -ScriptBlock {
            param($Root, $JobDir, $Steps, $ExitFile)
            Set-Location (Join-Path $Root $JobDir)
            $code = 0
            npm ci --no-audit --no-fund 2>$null; if ($LASTEXITCODE -ne 0) { npm install }
            if ($Steps -contains "lint")     { npm run lint 2>&1 | Out-Null;                     if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "format")   { npm run format:check 2>&1 | Out-Null;             if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "tsc")      { npx tsc -b 2>&1 | Out-Null;                       if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "build")    { npm run build 2>&1 | Out-Null;                    if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "test")     { npm test -- --run 2>&1 | Out-Null;                if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "test:cov") { npm test -- --run --coverage 2>&1 | Out-Null;     if ($LASTEXITCODE -ne 0) { $code = 1 } }
            try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
            exit $code
        } -ArgumentList $ROOT, $nJob.Dir, $nJob.Steps, $exitFile
    }
    Wait-Job -Job $bgJobs -Timeout $TimeoutSeconds | Out-Null
    $failed = 0
    for ($i = 0; $i -lt $bgJobs.Count; $i++) {
        $j = $bgJobs[$i]; $nJob = $Jobs[$i]
        $ec = 1
        if ($j.State -eq "Completed" -and (Test-Path $exitFiles[$i])) {
            $ec = [int](Get-Content $exitFiles[$i] -Raw)
        } elseif ($j.State -ne "Completed") {
            Write-Host "  [$($nJob.Name)] TIMEOUT" -ForegroundColor Red
            Stop-Job -Job $j -ErrorAction SilentlyContinue
        }
        $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
        $color  = if ($ec -eq 0) { "Green" } else { "Red" }
        Write-Host "  [$($nJob.Name)] $status" -ForegroundColor $color
        if ($ec -ne 0) { $failed = 1 }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $failed
}

# Generic parallel Playwright runner — accepts $CI_PLAYWRIGHT_SUITES (multi-suite).
# Flattens all batches across all suites into one parallel wave.
function Invoke-ParallelPlaywright {
    param(
        [array]$Suites,
        [int]$TimeoutSeconds = 600
    )
    $bgJobs = @(); $exitFiles = @(); $labels = @()
    foreach ($suite in $Suites) {
        foreach ($batch in $suite.Batches) {
            $label = "$($suite.Name)/$($batch.Name)"
            $labels += $label
            $exitFile = Join-Path $logDir "playwright_$($label -replace '[/\s]','_').exit"
            if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
            $exitFiles += $exitFile
            $bgJobs += Start-Job -ScriptBlock {
                param($Dir, $ExitFile, $PathsStr)
                Set-Location $Dir
                npx playwright install --with-deps chromium 2>$null
                $paths = $PathsStr -split '\s+' | Where-Object { $_ }
                if ($paths) { npx playwright test --project=chromium $paths 2>&1 }
                else        { npx playwright test --project=chromium 2>&1 }
                $code = $LASTEXITCODE
                try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
                exit $code
            } -ArgumentList $suite.Dir, $exitFile, $batch.Paths
        }
    }
    if ($bgJobs.Count -eq 0) { return 0 }
    Wait-Job -Job $bgJobs -Timeout $TimeoutSeconds | Out-Null
    $failed = 0
    for ($i = 0; $i -lt $bgJobs.Count; $i++) {
        $j = $bgJobs[$i]
        $ec = 1
        if ($j.State -eq "Completed" -and (Test-Path $exitFiles[$i])) {
            $ec = [int](Get-Content $exitFiles[$i] -Raw)
        } elseif ($j.State -ne "Completed") {
            Write-Host "  [$($labels[$i])] TIMEOUT" -ForegroundColor Red
            Stop-Job -Job $j -ErrorAction SilentlyContinue
        }
        $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
        $color  = if ($ec -eq 0) { "Green" } else { "Red" }
        Write-Host "  [$($labels[$i])] $status" -ForegroundColor $color
        if ($ec -ne 0) { $failed = 1 }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $failed
}

# ── [1/4] Kill CI containers, rebuild images, start new ───────────────────────
Write-Host "[1/$totalSteps] Containers: kill, rebuild, start ($($CI_CONTAINERS -join ', '))..." -ForegroundColor Yellow
docker compose -f $CI_COMPOSE_FILE down --remove-orphans 2>$null
docker ps -a -q --filter "label=com.docker.compose.project=$CI_PROJECT_LABEL" 2>$null |
    ForEach-Object { docker rm -f $_ 2>$null }
$attempt = 0
$succeeded = $false
while ($attempt -le $CI_CONTAINER_MAX_RETRIES) {
    $attempt++
    if ($attempt -gt 1) {
        Write-Host "  Retry $($attempt - 1)/${CI_CONTAINER_MAX_RETRIES}: down and up again..." -ForegroundColor Yellow
        docker compose -f $CI_COMPOSE_FILE down 2>$null
        Start-Sleep -Seconds 3
    }
    docker compose -f $CI_COMPOSE_FILE up -d --build --wait
    if ($LASTEXITCODE -eq 0) { $succeeded = $true; break }
}
if (-not $succeeded) {
    Write-Host "FATAL: CI containers failed to start after $CI_CONTAINER_MAX_RETRIES retries." -ForegroundColor Red
    @"
Local CI: containers failed to start.
Project: $CI_PROJECT_NAME
Action: Run 'docker compose -f $CI_COMPOSE_FILE down --remove-orphans' then '...up -d --build --wait' manually to debug.
"@ | Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
    exit 1
}
Write-Host "  Containers are up and healthy." -ForegroundColor Green

# ── Detect Python version ─────────────────────────────────────────────────────
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
        Write-Host "  ERROR: Python $pyVer detected. CI requires $requiredPy (set CI_PYTHON_VERSION in config.ps1)." -ForegroundColor Red
        exit 1
    }
}

# ── [2/4] Python deps + catalog bundle ────────────────────────────────────────
Write-Host "[2/$totalSteps] Python: install deps, catalog bundle..." -ForegroundColor Yellow
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

# ── [3/4] One parallel wave: Static + Unit + Integration + Node + Playwright ───
Invoke-EmulatorCheck -Context "wave"
$allJobs = @()
$allLabels = @()
$allExitFiles = @()

# Static check (single job)
$staticExitFile = Join-Path $logDir "static.exit"
if (Test-Path $staticExitFile) { Remove-Item $staticExitFile -Force }
$compileallTargets = $CI_COMPILEALL_TARGETS
$ruffExcludes = $CI_RUFF_EXCLUDES
$mypyTarget = $CI_MYPY_TARGET
$mypyBlocking = $CI_MYPY_BLOCKING
$allJobs += Start-Job -ScriptBlock {
    param($Root, $Py, $ExitFile, $CompileallTargets, $RuffExcludes, $MypyTarget, $MypyBlocking)
    Set-Location $Root
    $code = 0
    if ($env:OS -match "Windows") {
        foreach ($t in $CompileallTargets) {
            Get-ChildItem -Path $t -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    & $Py -m compileall -q @CompileallTargets 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $code = 1 }
    & $Py -m pip install "ruff>=0.14.0" mypy types-requests -q 2>$null | Out-Null
    $ruffArgs = $RuffExcludes | ForEach-Object { "--exclude=$_" }
    & $Py -m ruff check @ruffArgs . 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $code = 1 }
    & $Py -m ruff format --check --diff . 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { $code = 1 }
    & $Py -m mypy $MypyTarget --config-file=mypy.ini 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        if ($MypyBlocking) { $code = 1 }
    }
    try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
    exit $code
} -ArgumentList $ROOT, $PY, $staticExitFile, (,$compileallTargets), (,$ruffExcludes), $mypyTarget, $mypyBlocking
$allLabels += "Static"
$allExitFiles += $staticExitFile

# Unit test jobs
$unitEnv = Get-PytestEnv -IsIntegration $false
foreach ($set in $CI_UNIT_TEST_SETS) {
    $exitFile = Join-Path $logDir "unit_$($set.Name -replace '\s','_').exit"
    if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
    $allExitFiles += $exitFile
    $allJobs += Start-Job -ScriptBlock {
        param($Root, $Py, $ExitFile, $PathsStr, $FlagsStr, $Env)
        Set-Location $Root
        foreach ($k in $Env.Keys) { [System.Environment]::SetEnvironmentVariable($k, $Env[$k]) }
        $paths = $PathsStr -split '\s+' | Where-Object { $_ -and (Test-Path $_) }
        if (-not $paths) { $paths = $PathsStr -split '\s+' }
        $flagList = $FlagsStr -split '\s+' | Where-Object { $_ }
        & $Py -m pytest $paths @flagList 2>&1
        $code = $LASTEXITCODE
        try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
        exit $code
    } -ArgumentList $ROOT, $PY, $exitFile, $set.Paths, $CI_UNIT_PYTEST_FLAGS, $unitEnv
    $allLabels += $set.Name
}

# Integration jobs
$intEnv = Get-PytestEnv -IsIntegration $true
foreach ($batch in $CI_INTEGRATION_BATCHES) {
    $exitFile = Join-Path $logDir "integration_$($batch.Name -replace '\s','_').exit"
    if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
    $allExitFiles += $exitFile
    $allJobs += Start-Job -ScriptBlock {
        param($Root, $Py, $ExitFile, $PathsStr, $FlagsStr, $Env)
        Set-Location $Root
        foreach ($k in $Env.Keys) { [System.Environment]::SetEnvironmentVariable($k, $Env[$k]) }
        $paths = $PathsStr -split '\s+' | Where-Object { $_ -and (Test-Path $_) }
        if (-not $paths) { $paths = $PathsStr -split '\s+' }
        $flagList = $FlagsStr -split '\s+' | Where-Object { $_ }
        & $Py -m pytest $paths @flagList 2>&1
        $code = $LASTEXITCODE
        try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
        exit $code
    } -ArgumentList $ROOT, $PY, $exitFile, $batch.Paths, $CI_INTEGRATION_PYTEST_FLAGS, $intEnv
    $allLabels += $batch.Name
}

# Node jobs
if ($CI_NODE_JOBS -and $CI_NODE_JOBS.Count -gt 0) {
    foreach ($nJob in $CI_NODE_JOBS) {
        $exitFile = Join-Path $logDir "node_$($nJob.Name -replace '\s','_').exit"
        if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
        $allExitFiles += $exitFile
        $allJobs += Start-Job -ScriptBlock {
            param($Root, $JobDir, $Steps, $ExitFile)
            Set-Location (Join-Path $Root $JobDir)
            $code = 0
            npm ci --no-audit --no-fund 2>$null; if ($LASTEXITCODE -ne 0) { npm install }
            if ($Steps -contains "lint")     { npm run lint 2>&1 | Out-Null;                     if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "format")   { npm run format:check 2>&1 | Out-Null;             if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "tsc")      { npx tsc -b 2>&1 | Out-Null;                       if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "build")    { npm run build 2>&1 | Out-Null;                    if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "test")     { npm test -- --run 2>&1 | Out-Null;                if ($LASTEXITCODE -ne 0) { $code = 1 } }
            if ($code -eq 0 -and $Steps -contains "test:cov") { npm test -- --run --coverage 2>&1 | Out-Null;     if ($LASTEXITCODE -ne 0) { $code = 1 } }
            try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
            exit $code
        } -ArgumentList $ROOT, $nJob.Dir, $nJob.Steps, $exitFile
        $allLabels += $nJob.Name
    }
}

# Playwright jobs
if ($CI_PLAYWRIGHT_SUITES -and $CI_PLAYWRIGHT_SUITES.Count -gt 0) {
    foreach ($suite in $CI_PLAYWRIGHT_SUITES) {
        foreach ($batch in $suite.Batches) {
            $label = "$($suite.Name)/$($batch.Name)"
            $exitFile = Join-Path $logDir "playwright_$($label -replace '[/\s]','_').exit"
            if (Test-Path $exitFile) { Remove-Item $exitFile -Force }
            $allExitFiles += $exitFile
            $allJobs += Start-Job -ScriptBlock {
                param($Dir, $ExitFile, $PathsStr)
                Set-Location $Dir
                npx playwright install --with-deps chromium 2>$null
                $paths = $PathsStr -split '\s+' | Where-Object { $_ }
                if ($paths) { npx playwright test --project=chromium $paths 2>&1 }
                else        { npx playwright test --project=chromium 2>&1 }
                $code = $LASTEXITCODE
                try { [System.IO.File]::WriteAllText($ExitFile, $code) } catch {}
                exit $code
            } -ArgumentList $suite.Dir, $exitFile, $batch.Paths
            $allLabels += $label
        }
    }
}

$waveCount = $allJobs.Count
Write-Host "[3/$totalSteps] Parallel wave ($waveCount jobs, timeout ${parallelWaveTimeout}s)..." -ForegroundColor Yellow
Wait-Job -Job $allJobs -Timeout $parallelWaveTimeout | Out-Null

$waveFailed = 0
for ($i = 0; $i -lt $allJobs.Count; $i++) {
    $j = $allJobs[$i]
    $label = $allLabels[$i]
    $ec = 1
    if ($j.State -eq "Completed" -and $i -lt $allExitFiles.Count -and (Test-Path $allExitFiles[$i])) {
        $ec = [int](Get-Content $allExitFiles[$i] -Raw)
    } elseif ($j.State -ne "Completed") {
        Write-Host "  [$label] TIMEOUT" -ForegroundColor Red
        Stop-Job -Job $j -ErrorAction SilentlyContinue
    }
    $status = if ($ec -eq 0) { "PASS" } else { "FAIL" }
    $color  = if ($ec -eq 0) { "Green" } else { "Red" }
    Write-Host "  [$label] $status" -ForegroundColor $color
    if ($ec -ne 0) {
        $waveFailed = 1
        $logFile = Join-Path $logDir "wave_$($label -replace '[/\s]','_').log"
        Receive-Job -Job $j 2>$null | Set-Content -Path $logFile -Encoding utf8 -ErrorAction SilentlyContinue
    }
    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
}

if ($waveFailed -ne 0) {
    "Local CI: one or more jobs in parallel wave failed. See ci_logs/ for details." |
        Set-Content (Join-Path $logDir "LATEST_FAILURE.md") -Encoding UTF8
    docker compose -f $CI_COMPOSE_FILE down 2>$null
    exit 1
}

# ── [4/4] Cleanup ────────────────────────────────────────────────────────────
Write-Host "[4/$totalSteps] Cleanup..." -ForegroundColor Gray
$emulatorsOk = Test-EmulatorsHealthy -LogDir $logDir
if (-not $emulatorsOk) {
    Write-Host "Containers became unavailable during CI." -ForegroundColor Red
    $reportPath = Join-Path $logDir "CONTAINER_FAILURE.txt"
    if (Test-Path $reportPath) {
        Get-Content $reportPath -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
}
Write-Host "Stopping CI containers..." -ForegroundColor Gray
docker compose -f $CI_COMPOSE_FILE down 2>$null

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Local CI PASSED - $CI_PROJECT_NAME" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
exit 0
