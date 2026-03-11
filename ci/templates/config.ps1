# .ci/config.ps1 — Project-specific CI config. Copy from XAC ci/templates/config.ps1 and adapt.
# All $CI_* variables are consumed by XAC ci/local_ci/core.ps1. Keep unit/integration flags in sync with deploy-staging.yml.

$ROOT = $PSScriptRoot
if (-not $ROOT) { $ROOT = (Get-Location).Path }

# Project identity
$CI_PROJECT_NAME    = "MyProject"
$CI_PROJECT_LABEL   = "myproject"   # used for docker label filter

# Docker
$CI_COMPOSE_FILE    = "docker-compose.ci.yml"
$CI_CONTAINERS      = @("firestore-emulator", "redis")   # add "gcs-emulator" if needed

# GCP test environment
$CI_GOOGLE_CLOUD_PROJECT = "myproject-test"
$CI_FIRESTORE_HOST       = "localhost:8086"
$CI_STORAGE_HOST         = "http://localhost:9023"   # set $null if no GCS
$CI_REDIS_URL            = "redis://localhost:6399/0"

# Runtime versions (canonical for local CI; keep .python-version and .nvmrc in sync)
$CI_PYTHON_VERSION = "3.11"
$CI_NODE_VERSION   = "20"


# Python
$CI_PYTHONPATH_EXTRA     = @("$ROOT\entrypoint_backend")   # empty array if not needed
$CI_CATALOG_DIR          = "$ROOT\modules\catalog_api_public\data\catalog_source"   # or $null
$CI_CATALOG_COMPILE_CMD  = $null   # or a scriptblock

$CI_COMPILEALL_TARGETS   = @("modules/estimate_engine", "entrypoint_backend/backend")
$CI_RUFF_EXCLUDES        = @("tests_cross_module_e2e/**", "_archive/**")
$CI_MYPY_TARGET          = "entrypoint_backend/backend"

# Test flags — must match deploy-staging.yml exactly (excluding --cov flags)
# Unit: exclude integration and ai. Integration: run integration-marked tests only.
$CI_UNIT_PYTEST_FLAGS        = "-m 'not integration and not ai' --timeout=120 --maxfail=50 --no-cov -o addopts= -v --tb=short"
$CI_INTEGRATION_PYTEST_FLAGS = "-m 'integration and not ai' --timeout=300 --maxfail=50 -n auto -v --tb=short"

# Unit test sets — mirrors GH Actions matrix
$CI_UNIT_TEST_SETS = @(
    @{ Name = "unit_tests_1_Example"; Paths = "modules/example" }
)

# Integration batches — mirrors GH Actions matrix
$CI_INTEGRATION_BATCHES = @(
    @{ Name = "integration_1"; Paths = "tests_cross_module_e2e/EXAMPLE" }
)

# Playwright — set $null to skip
$CI_PLAYWRIGHT_DIR = $null   # e.g. "modules/estimate_product_layer/frontend"

# Node jobs — empty array to skip all
$CI_NODE_JOBS = @(
    # @{ Name = "Lint"; Dir = "."; Steps = @("lint", "format") }
    # @{ Name = "Frontend"; Dir = "frontend"; Steps = @("tsc", "test:cov") }
)
