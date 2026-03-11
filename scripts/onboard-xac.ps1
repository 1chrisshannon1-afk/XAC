<#
.SYNOPSIS
    XAC onboarding: one script, one URL. Run from your project repo root.
.DESCRIPTION
    Hosted in the XAC repo. Do not copy into consumer repos.
    One command: irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 | iex
    Downloads .github/workflows/sync-xac.yml from XAC, creates .ci/config.ps1 (thin wrapper),
    creates _XAC_Config/ with all template files. Local CI entry point: _XAC_Config/ci/local_ci.ps1 (delegates to _XAC_Base).
.EXAMPLE
    irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# ── XAC repo (change if you use a fork) ────────────────────────────────────────
$XAC_REPO_RAW = "https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main"

# ── Ensure we're in a git repo root ────────────────────────────────────────────
$ROOT = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
if (-not (Test-Path (Join-Path $ROOT ".git"))) {
    Write-Host "ERROR: Not a git repository root. Run this script from your project repo root." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  XAC Onboarding — One Script Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Collect project info ──────────────────────────────────────────────────────
$ProjectName = Read-Host "Project name (e.g. Acme Corp)"
if (-not $ProjectName) { Write-Host "Project name is required." -ForegroundColor Red; exit 1 }

$Sanitized = ($ProjectName -replace '[^a-zA-Z0-9]', '') -replace '^$', 'Project'
$DefaultConfigFolder = "_XAC_Config"
$ConfigFolderName = Read-Host "Config folder name [${DefaultConfigFolder}]"
if (-not $ConfigFolderName) { $ConfigFolderName = $DefaultConfigFolder }

$GcpProject = Read-Host "GCP project ID (e.g. acme-prod-123)"
if (-not $GcpProject) { Write-Host "GCP project ID is required." -ForegroundColor Red; exit 1 }

$GitHubOrg  = Read-Host "GitHub org (e.g. my-org)"
$GitHubRepo = Read-Host "GitHub repo name (e.g. acme-backend)"
$Region     = Read-Host "GCP region [us-central1]"
if (-not $Region) { $Region = "us-central1" }

$ProjectLabel = $Sanitized.ToLowerInvariant()

# ── Placeholder replacement ────────────────────────────────────────────────────
function Set-Placeholders {
    param([string]$Text, [hashtable]$Vars)
    $out = $Text
    foreach ($k in $Vars.Keys) { $out = $out.Replace("{{$k}}", $Vars[$k]) }
    return $out
}

$V = @{
    XAC_CONFIG_NAME = $ConfigFolderName
    PROJECT_NAME    = $ProjectName
    PROJECT_LABEL   = $ProjectLabel
    GCP_PROJECT     = $GcpProject
    GCP_REGION      = $Region
    GITHUB_ORG      = $GitHubOrg
    GITHUB_REPO     = $GitHubRepo
    XAC_REPO_RAW    = $XAC_REPO_RAW
}

# ── 1. Download Sync _XAC_Base workflow ────────────────────────────────────────
Write-Host "[1/5] Downloading Sync _XAC_Base workflow..." -ForegroundColor Yellow
$workflowUrl = "$XAC_REPO_RAW/ci/templates/sync-xac-consumer.yml"
$workflowDir = Join-Path $ROOT ".github\workflows"
$workflowPath = Join-Path $workflowDir "sync-xac.yml"
if (-not (Test-Path $workflowDir)) { New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null }
try {
    Invoke-WebRequest -Uri $workflowUrl -UseBasicParsing -OutFile $workflowPath
} catch {
    Write-Host "WARN: Could not download workflow from $workflowUrl" -ForegroundColor Yellow
    Write-Host "  Create .github/workflows/sync-xac.yml manually from XAC repo." -ForegroundColor Gray
}
Write-Host "  OK  .github/workflows/sync-xac.yml" -ForegroundColor Green

# ── 2. Create xac-ci.yml workflow ──────────────────────────────────────────────
Write-Host "[2/5] Creating .github/workflows/xac-ci.yml..." -ForegroundColor Yellow
$xacCiYml = @"
# {{PROJECT_NAME}} — CI + Deploy Pipeline
# Single workflow: CI on all branches, deploy on staging push.
# All jobs delegate to XAC reusable workflows.
name: XAC CI

on:
  push:
    branches: [main, develop, staging]
  pull_request:
    branches: [main, develop, staging]
  workflow_dispatch:
    inputs:
      reason:
        description: "Reason (optional)"
        required: false
        default: ""

permissions:
  contents: read
  id-token: write
  security-events: write

concurrency:
  group: xac-ci-`${{ github.ref }}
  cancel-in-progress: true

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"

jobs:
  preflight:
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-preflight.yml@main

  static-checks:
    needs: preflight
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-static-checks.yml@main
    with:
      compileall-targets: "."
      ruff-excludes: "_archive/**,_ARCHIVE/**,_XAC_Base/**,{{XAC_CONFIG_NAME}}/**"
      mypy-target: ""
      mypy-blocking: false

  tests:
    needs: preflight
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-python-tests.yml@main
    with:
      unit-test-matrix: "[{`"set_name`":`"unit`",`"test_paths`":`".`"}]"
      integration-test-matrix: "[{`"batch_name`":`"integration`",`"test_paths`":`".`"}]"
      pythonpath-extra: ""
      gcp-test-project: "{{GCP_PROJECT}}-test"

  build:
    if: github.event_name == 'push' && github.ref == 'refs/heads/staging'
    needs: [static-checks, tests]
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-build-push.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      repo-name: {{PROJECT_LABEL}}-apps
      service-name: {{PROJECT_LABEL}}-backend-staging
      dockerfile: Dockerfile
    secrets: inherit

  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/staging'
    needs: build
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-deploy-canary.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      service-name: {{PROJECT_LABEL}}-backend-staging
      image-uri: `${{ needs.build.outputs.image-uri }}
      revision-suffix: `${{ github.sha }}
      environment: staging
    secrets: inherit

  smoke:
    if: github.event_name == 'push' && github.ref == 'refs/heads/staging'
    needs: deploy
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-smoke-tests.yml@main
    with:
      revision-url: `${{ needs.deploy.outputs.revision-url }}
      health-endpoint: /health

  traffic:
    if: github.event_name == 'push' && github.ref == 'refs/heads/staging'
    needs: [deploy, smoke]
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-traffic-shift.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      service-name: {{PROJECT_LABEL}}-backend-staging
      revision-name: `${{ needs.deploy.outputs.revision-name }}
      canary-bake-minutes: 5
      environment: staging
    secrets: inherit

  rollback:
    if: failure() && needs.deploy.result == 'success'
    needs: [deploy, smoke, traffic]
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-rollback.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      service-name: {{PROJECT_LABEL}}-backend-staging
      failed-revision: `${{ needs.deploy.outputs.revision-name }}
      reason: "Post-deploy validation failed"
    secrets: inherit
"@
$xacCiPath = Join-Path $workflowDir "xac-ci.yml"
Set-Content -Path $xacCiPath -Value (Set-Placeholders $xacCiYml $V)
Write-Host "  OK  .github/workflows/xac-ci.yml" -ForegroundColor Green

# ── 3. Create .ci/config.ps1 thin wrapper ──────────────────────────────────────
Write-Host "[3/5] Creating .ci/config.ps1..." -ForegroundColor Yellow
$ciDir = Join-Path $ROOT ".ci"
if (-not (Test-Path $ciDir)) { New-Item -ItemType Directory -Path $ciDir -Force | Out-Null }
$ciWrapper = @"
# .ci/config.ps1 — Thin wrapper
# Sources the canonical config from $ConfigFolderName.
`$_configRoot = Split-Path `$PSScriptRoot -Parent
`$_canonical  = Join-Path `$_configRoot "$ConfigFolderName\ci\config.ps1"
if (Test-Path `$_canonical) { . `$_canonical } else { Write-Host "ERROR: Config not found: `$_canonical" -ForegroundColor Red; exit 1 }
"@
Set-Content -Path (Join-Path $ciDir "config.ps1") -Value $ciWrapper
Write-Host "  OK  .ci/config.ps1" -ForegroundColor Green

# ── 4. Create _XAC_Config_* folder and all files ───────────────────────────────
Write-Host "[4/5] Creating $ConfigFolderName with ci, cursor, docker, iac, cicd, briefs..." -ForegroundColor Yellow
$cfgRoot = Join-Path $ROOT $ConfigFolderName
$null = New-Item -ItemType Directory -Path $cfgRoot -Force

$configPs1 = @'
# config.ps1 — {{PROJECT_NAME}}
$CI_PROJECT_NAME  = "{{PROJECT_NAME}}"
$CI_PROJECT_LABEL = "{{PROJECT_LABEL}}"
$CI_GCP_PROJECT         = "{{GCP_PROJECT}}"
$CI_GCP_SERVICE_ACCOUNT = "cursor-agent@{{GCP_PROJECT}}.iam.gserviceaccount.com"
$CI_GCP_KEY_FILE        = "cursor-agent-key.json"
$CI_GCP_REGION          = "{{GCP_REGION}}"
$CI_DOCKER_PATH    = "{{XAC_CONFIG_NAME}}/docker"
$CI_GCP_CICD_PATH  = "{{XAC_CONFIG_NAME}}/gcp_cicd"
$CI_XAC_CONFIG     = "{{XAC_CONFIG_NAME}}"
$CI_COMPOSE_FILE = "docker-compose.ci.yml"
$CI_CONTAINERS   = @("firestore-emulator", "gcs-emulator", "redis")
$CI_GOOGLE_CLOUD_PROJECT = "{{GCP_PROJECT}}-test"
$CI_FIRESTORE_HOST       = "localhost:8086"
$CI_STORAGE_HOST         = "http://localhost:9023"
$CI_REDIS_URL            = "redis://localhost:6399/0"
$CI_PYTHONPATH_EXTRA = @()
$CI_CATALOG_DIR      = $null
$CI_CATALOG_COMPILE_CMD = $null
$CI_COMPILEALL_TARGETS = @(".")
$CI_RUFF_EXCLUDES = @("_archive/**", "_ARCHIVE/**", "_XAC_Base/**", "{{XAC_CONFIG_NAME}}/**")
$CI_MYPY_TARGET = $null
$CI_MYPY_BLOCKING = $false
$CI_UNIT_TEST_SETS = @(@{ Name = "unit_tests"; Paths = "." })
$CI_INTEGRATION_BATCHES = @(@{ Name = "integration"; Paths = "." })
$CI_PLAYWRIGHT_DIR = $null
$CI_PLAYWRIGHT_BATCHES = @()
$CI_NODE_JOBS = @()
$CI_UNIT_PYTEST_FLAGS = '-v --tb=short --maxfail=50'
$CI_INTEGRATION_PYTEST_FLAGS = '-v --tb=short --maxfail=20'
'@

$localCiPs1 = @'
# Entry point: delegates to _XAC_Base. Run from repo root: _XAC_Config\ci\local_ci.ps1
$repoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
& (Join-Path $repoRoot "_XAC_Base\ci\local_ci.ps1")
'@

$deployYml = @'
name: Deploy Staging (Shared)
on:
  workflow_dispatch:
    inputs:
      reason:
        description: "Reason (optional)"
        required: false
        default: ""
permissions:
  contents: read
  id-token: write
  security-events: write
concurrency:
  group: deploy-staging-shared
  cancel-in-progress: true
jobs:
  preflight:
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-preflight.yml@main
  static-checks:
    needs: preflight
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-static-checks.yml@main
    with:
      compileall-targets: "."
      ruff-excludes: "_archive/**,_ARCHIVE/**,_XAC_Base/**,{{XAC_CONFIG_NAME}}/**"
      mypy-target: ""
      mypy-blocking: false
  tests:
    needs: preflight
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-python-tests.yml@main
    with:
      unit-test-matrix: "[{\"set_name\":\"unit\",\"test_paths\":\".\"}]"
      integration-test-matrix: "[{\"batch_name\":\"integration\",\"test_paths\":\".\"}]"
      pythonpath-extra: ""
      gcp-test-project: "{{GCP_PROJECT}}-test"
  build:
    needs: [static-checks, tests]
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-build-push.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      repo-name: {{PROJECT_LABEL}}-apps
      service-name: {{PROJECT_LABEL}}-backend-staging
      dockerfile: Dockerfile
    secrets: inherit
  deploy:
    needs: build
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-deploy-canary.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      service-name: {{PROJECT_LABEL}}-backend-staging
      image-uri: ${{ needs.build.outputs.image-uri }}
      revision-suffix: ${{ github.sha }}
      environment: staging
    secrets: inherit
  smoke:
    needs: deploy
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-smoke-tests.yml@main
    with:
      revision-url: ${{ needs.deploy.outputs.revision-url }}
      health-endpoint: /health
  traffic:
    needs: [deploy, smoke]
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-traffic-shift.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      service-name: {{PROJECT_LABEL}}-backend-staging
      revision-name: ${{ needs.deploy.outputs.revision-name }}
      canary-bake-minutes: 5
      environment: staging
    secrets: inherit
  rollback:
    needs: [deploy, smoke, traffic]
    if: failure() && needs.deploy.result == 'success'
    uses: 1chrisshannon1-afk/XAC/.github/workflows/reusable-rollback.yml@main
    with:
      project-id: {{GCP_PROJECT}}
      service-name: {{PROJECT_LABEL}}-backend-staging
      failed-revision: ${{ needs.deploy.outputs.revision-name }}
      reason: "Post-deploy validation failed"
    secrets: inherit
'@

$cursorrules = "# {{PROJECT_NAME}} — Project rules`n- **Project ID:** {{GCP_PROJECT}}`n- Edit paths and deploy commands. See _XAC_Base/cursor/README.md.`n"
$cursorignore = "# {{PROJECT_NAME}} — Add paths to ignore (logs, uploads, etc.)`n"
$configReadme = @'
# {{XAC_CONFIG_NAME}}
Project config for {{PROJECT_NAME}}. Shared platform: _XAC_Base/.
Edit: ci/config.ps1, cursor/*.project, iac/, ci/deploy-staging-shared.yml. Add Dockerfiles in docker/.
'@

$iacMain = @'
module "staging" {
  source = "../../_XAC_Base/iac/modules/project-baseline"
  project_id   = var.project_id
  project_name = "{{GCP_PROJECT}}"
  company      = "{{PROJECT_LABEL}}"
  environment  = "staging"
  region       = var.region
  github_org  = "{{GITHUB_ORG}}"
  github_repo = "{{GITHUB_REPO}}"
  services = [{
    name = "{{PROJECT_LABEL}}-backend-staging"
    image = "{{GCP_REGION}}-docker.pkg.dev/${var.project_id}/{{PROJECT_LABEL}}-apps/backend:latest"
    min_instances = 0
    max_instances = 10
    cpu = "1"
    memory = "1Gi"
    enable_public_access = true
    env_vars = { APP_ENV = "staging", REGION = var.region, PROJECT_ID = var.project_id }
    secret_ids = []
  }]
  artifact_registry_repo_id = "{{PROJECT_LABEL}}-apps"
  enable_vpc = true
  subnet_cidr = "10.0.0.0/24"
  connector_cidr = "10.8.0.0/28"
  billing_account_id = var.billing_account_id
  monthly_budget_usd = 200
  alert_email_addresses = var.alert_email_addresses
  slack_webhook_url = var.slack_webhook_url
  runbook_base_url = var.runbook_base_url
  secrets = []
  cloudbuild_config = "{{XAC_CONFIG_NAME}}/gcp_cicd/cloudbuild-ci-staging.yaml"
}
'@

$iacVars = "variable `"project_id`" { type = string default = `"{{GCP_PROJECT}}`" }`nvariable `"region`" { type = string default = `"{{GCP_REGION}}`" }`nvariable `"billing_account_id`" { type = string }`nvariable `"alert_email_addresses`" { type = list(string) }`nvariable `"slack_webhook_url`" { type = string default = `"`" }`nvariable `"runbook_base_url`" { type = string default = `"https://github.com/{{GITHUB_ORG}}/{{GITHUB_REPO}}/blob/main/_XAC_Base/monitoring/runbooks`" }`n"
$iacBackend = "terraform { backend `"gcs`" { bucket = `"{{GCP_PROJECT}}-terraform-state`"; prefix = `"terraform/state`" } }`n"
$iacOutputs = "output `"wif_provider`" { value = module.staging.wif_provider }`noutput `"ci_service_account`" { value = module.staging.ci_service_account }`noutput `"artifact_registry_url`" { value = module.staging.artifact_registry_url }`noutput `"service_urls`" { value = module.staging.service_urls }`n"
$iacTfvarsExample = "project_id = `"{{GCP_PROJECT}}`"`nregion = `"{{GCP_REGION}}`"`nbilling_account_id = `"REPLACE`"`nalert_email_addresses = [`"devops@example.com`"]`nslack_webhook_url = `"`"`nrunbook_base_url = `"`"`n"
$cicdReadme = "# CI/CD — {{PROJECT_NAME}}`nSee MANIFEST.md. Hooks: _XAC_Base/ci/hooks/install.ps1`n"
$cicdManifest = "| Path | Purpose |`n|------|---------|`n| {{XAC_CONFIG_NAME}}/ci/config.ps1 | Master config |`n| .github/workflows/sync-xac.yml | Sync _XAC_Base |`n| _XAC_Base/ci/hooks/ | Pre-commit, pre-push |`n"

foreach ($pair in @(
    @{ Path = "README.md"; Content = (Set-Placeholders $configReadme $V) },
    @{ Path = "ci\config.ps1"; Content = (Set-Placeholders $configPs1 $V) },
    @{ Path = "ci\local_ci.ps1"; Content = (Set-Placeholders $localCiPs1 $V) },
    @{ Path = "ci\deploy-staging-shared.yml"; Content = (Set-Placeholders $deployYml $V) },
    @{ Path = "cursor\cursorrules.project"; Content = (Set-Placeholders $cursorrules $V) },
    @{ Path = "cursor\cursorignore.project"; Content = (Set-Placeholders $cursorignore $V) },
    @{ Path = "cursor\rules\project_rules.md"; Content = "# Add project rules here`n" },
    @{ Path = "docker\README.md"; Content = "Add Dockerfile.backend.dev etc. Root docker-compose references $ConfigFolderName/docker/.`n" },
    @{ Path = "iac\main.tf"; Content = (Set-Placeholders $iacMain $V) },
    @{ Path = "iac\variables.tf"; Content = (Set-Placeholders $iacVars $V) },
    @{ Path = "iac\backend.tf"; Content = (Set-Placeholders $iacBackend $V) },
    @{ Path = "iac\outputs.tf"; Content = (Set-Placeholders $iacOutputs $V) },
    @{ Path = "iac\terraform.tfvars.example"; Content = (Set-Placeholders $iacTfvarsExample $V) },
    @{ Path = "cicd\README.md"; Content = (Set-Placeholders $cicdReadme $V) },
    @{ Path = "cicd\MANIFEST.md"; Content = (Set-Placeholders $cicdManifest $V) },
    @{ Path = "cicd\docs\COMMIT_PUSH_DEPLOY.md"; Content = "See _XAC_Base/docs/. Push to staging to deploy.`n" },
    @{ Path = "briefs\README.md"; Content = "Add agent briefs here.`n" }
)) {
    $fullPath = Join-Path $cfgRoot $pair.Path
    $dir = Split-Path $fullPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $fullPath -Value $pair.Content
}
Write-Host "  OK  $ConfigFolderName/" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Onboarding Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit $ConfigFolderName/ci/config.ps1 — paths, test sets, GCP." -ForegroundColor White
Write-Host "  2. Edit $ConfigFolderName/iac/ — services, secrets, terraform.tfvars." -ForegroundColor White
Write-Host "  3. Edit $ConfigFolderName/cursor/*.project for your project." -ForegroundColor White
Write-Host "  4. Add _XAC_Base: run Actions -> Sync _XAC_Base, or: git subtree add --prefix=_XAC_Base https://github.com/1chrisshannon1-afk/XAC.git main --squash" -ForegroundColor White
Write-Host "  5. Assemble .cursorrules/.cursorignore (see _XAC_Base/cursor/README.md). Add Dockerfiles in $ConfigFolderName/docker/." -ForegroundColor White
Write-Host ""
