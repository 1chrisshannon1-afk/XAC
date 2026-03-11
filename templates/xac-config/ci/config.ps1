# config.ps1 — {{PROJECT_NAME}}
# Central project configuration. All project-specific settings live here.
# Loaded by: .ci/config.ps1 (thin wrapper), _XAC CI engine.
# ─────────────────────────────────────────────────────────────────────────────

# ── Project identity ──────────────────────────────────────────────────────────
$CI_PROJECT_NAME  = "{{PROJECT_NAME}}"
$CI_PROJECT_LABEL = "{{PROJECT_LABEL}}"

# ── GCP identity ──────────────────────────────────────────────────────────────
$CI_GCP_PROJECT         = "{{GCP_PROJECT}}"
$CI_GCP_SERVICE_ACCOUNT = "cursor-agent@{{GCP_PROJECT}}.iam.gserviceaccount.com"
$CI_GCP_KEY_FILE        = "cursor-agent-key.json"
$CI_GCP_REGION          = "{{GCP_REGION}}"

# ── Project paths ─────────────────────────────────────────────────────────────
$CI_DOCKER_PATH    = "_Config_Project/docker"
$CI_GCP_CICD_PATH  = "_Config_Project/gcp_cicd"
$CI_XAC_CONFIG     = "{{XAC_CONFIG_NAME}}"

# ── Docker ────────────────────────────────────────────────────────────────────
$CI_COMPOSE_FILE = "_XAC_Base/ci/templates/docker-compose.ci.yml"
$CI_CONTAINERS   = @("firestore-emulator", "gcs-emulator", "redis")

# ── Test environment ──────────────────────────────────────────────────────────
$CI_GOOGLE_CLOUD_PROJECT = "{{GCP_PROJECT}}-test"
$CI_FIRESTORE_HOST       = "localhost:8086"
$CI_STORAGE_HOST         = "http://localhost:9023"
$CI_REDIS_URL            = "redis://localhost:6399/0"

# ── Python paths ──────────────────────────────────────────────────────────────
$CI_PYTHONPATH_EXTRA = @()
$CI_CATALOG_DIR      = $null
$CI_CATALOG_COMPILE_CMD = $null

# ── Static analysis ──────────────────────────────────────────────────────────
$CI_COMPILEALL_TARGETS = @(".")
$CI_RUFF_EXCLUDES = @("_archive/**", "_ARCHIVE/**", "_XAC_Base/**", "{{XAC_CONFIG_NAME}}/**", "_Config_Project/**")
$CI_MYPY_TARGET = $null
$CI_MYPY_BLOCKING = $false

# ── Unit test sets (parallel) ────────────────────────────────────────────────
$CI_UNIT_TEST_SETS = @(
    @{ Name = "unit_tests"; Paths = "." }
)

# ── Integration test batches ─────────────────────────────────────────────────
$CI_INTEGRATION_BATCHES = @(
    @{ Name = "integration"; Paths = "." }
)

# ── Playwright ────────────────────────────────────────────────────────────────
$CI_PLAYWRIGHT_DIR = $null
$CI_PLAYWRIGHT_BATCHES = @()

# ── Pytest flags ──────────────────────────────────────────────────────────────
$CI_UNIT_PYTEST_FLAGS        = '-v --tb=short --maxfail=50'
$CI_INTEGRATION_PYTEST_FLAGS = '-v --tb=short --maxfail=20'

# ── Node / frontend jobs ─────────────────────────────────────────────────────
$CI_NODE_JOBS = @()
