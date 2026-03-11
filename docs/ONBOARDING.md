# Onboarding a New Project to SharedWorkflows

This guide walks through adding a new company/project to the shared CI/CD system.

## Prerequisites

- A GCP project with Cloud Run, Artifact Registry, and Workload Identity Federation set up.
- A GitHub repo for the project.
- Python 3.10 or 3.11 and Docker installed locally.
- `requirements.txt` in the repo root.

## Step 1: Clone SharedWorkflows

Clone this repo as a sibling to your project repo:

```powershell
cd C:\dev  # or wherever your repos live
git clone https://github.com/1chrisshannon1-afk/SharedWorkflows.git
```

## Step 2: Create project config

Copy the config template into your repo:

```powershell
mkdir .ci
cp ../SharedWorkflows/templates/config.ps1.template .ci/config.ps1
```

Edit `.ci/config.ps1` and fill in every value:

| Variable | What to set |
|----------|------------|
| `$CI_PROJECT_NAME` | Human-readable name (e.g. "Acme App") |
| `$CI_PROJECT_LABEL` | Docker compose label (e.g. "acmeapp") |
| `$CI_COMPOSE_FILE` | Path to your CI docker-compose file |
| `$CI_CONTAINERS` | Array of container names to health-check |
| `$CI_GOOGLE_CLOUD_PROJECT` | GCP project for test env |
| `$CI_COMPILEALL_TARGETS` | Paths for `python -m compileall` |
| `$CI_RUFF_EXCLUDES` | Ruff exclude patterns |
| `$CI_MYPY_TARGET` | Path for mypy |
| `$CI_UNIT_TEST_SETS` | Array of `@{Name="..."; Paths="..."}` |
| `$CI_INTEGRATION_BATCHES` | Array of `@{Name="..."; Paths="..."}` |

## Step 3: Create local CI wrapper

Copy the wrapper template:

```powershell
cp ../SharedWorkflows/templates/local_ci.ps1.template local_ci.ps1
```

No edits needed if SharedWorkflows is a sibling folder. Otherwise set `$CI_SHARED_PATH`.

## Step 4: Verify local CI

```powershell
.\local_ci.ps1
```

This runs all 5 steps: containers, deps, static checks, unit tests, integration + Playwright + Node.

## Step 5: Create docker-compose.ci.yml

Your project needs a `docker-compose.ci.yml` (or whatever `$CI_COMPOSE_FILE` points to) that starts the emulators listed in `$CI_CONTAINERS`. Example:

```yaml
services:
  firestore-emulator:
    image: google/cloud-sdk:slim
    command: >
      bash -c "apt-get update -qq && apt-get install -y -qq default-jre > /dev/null 2>&1 &&
               gcloud emulators firestore start --host-port=0.0.0.0:8086 --project=test-project"
    ports: ["8086:8086"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8086/"]
      interval: 5s
      retries: 12
  redis:
    image: redis:7-alpine
    ports: ["6399:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 10
```

## Step 6: Set up GitHub Actions (staging deploy)

Copy the deploy template:

```powershell
mkdir -p .github/workflows
cp ../SharedWorkflows/templates/deploy-staging.yml.template .github/workflows/deploy-staging.yml
```

Edit and replace all `YOUR_` placeholders:
- `YOUR_GCP_PROJECT_ID` — your GCP project
- `YOUR_ARTIFACT_REGISTRY_REPO` — Artifact Registry repo name
- `YOUR_SERVICE_NAME` — Cloud Run service name
- `YOUR_COMPILEALL_TARGETS`, `YOUR_RUFF_EXCLUDES`, `YOUR_MYPY_TARGET`
- `YOUR_UNIT_TEST_PATHS`, `YOUR_INTEGRATION_PATHS`
- `YOUR_EXTRA_PYTHONPATH`

## Step 7: Set GitHub repo variables

In your GitHub repo settings → Secrets and variables → Actions → Variables:

| Variable | Value |
|----------|-------|
| `WIF_PROVIDER` | Your WIF provider resource name |
| `WIF_SERVICE_ACCOUNT` | Your CI deployer service account email |

## Step 8: Verify the setup

Run the verification script:

```bash
./scripts/verify-setup.sh
```

Or manually check:
- `.ci/config.ps1` exists and all `$CI_*` variables are set
- `requirements.txt` exists
- `docker-compose.ci.yml` (or `$CI_COMPOSE_FILE`) exists
- `.github/workflows/deploy-staging.yml` has no `YOUR_` placeholders left

## Step 9: Push and test

```powershell
git add .ci/ local_ci.ps1 .github/workflows/
git commit -m "Add SharedWorkflows CI/CD"
git push origin staging
```

Watch the GitHub Actions run. If it fails, check the logs — the pipeline will tell you which step failed.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Shared CI core not found" | Set `$env:CI_SHARED_PATH` or clone SharedWorkflows as sibling |
| mypy fails CI | Set `$CI_MYPY_BLOCKING = $false` in config (default) |
| Tests use wrong pytest flags | Set `$CI_UNIT_PYTEST_FLAGS` / `$CI_INTEGRATION_PYTEST_FLAGS` in config |
| WIF auth fails | Check `WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT` repo variables |
| Canary bake too short | Set `canary-bake-minutes: 15` or higher in deploy workflow |
