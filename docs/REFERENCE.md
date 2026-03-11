# REFERENCE — _XAC

**Last reviewed:** 2026-03-11

Living reference for config variables, local CI behavior, and (when used) reusable workflow inputs/outputs. **Reference implementation:** see your project's `_XAC_Config/ci/config.ps1`.

---

## Config variables (`$CI_*`)

All project-specific values are set in `.ci/config.ps1` before `core.ps1` is dot-sourced.

| Variable | Type | Default / required | Description |
|----------|------|--------------------|-------------|
| `$CI_PROJECT_NAME` | string | required | Human-readable project name (e.g. "ContractorScope AI") |
| `$CI_PROJECT_LABEL` | string | required | Docker Compose project label; used for container filter (e.g. "contractorscope") |
| `$CI_COMPOSE_FILE` | string | required | Path to docker-compose CI file (e.g. "docker-compose.ci.yml") |
| `$CI_CONTAINERS` | array | required | Container names to health-check (e.g. firestore-emulator, redis, gcs-emulator) |
| `$CI_GOOGLE_CLOUD_PROJECT` | string | required | GCP project for test env |
| `$CI_FIRESTORE_HOST` | string | required | e.g. "localhost:8086" |
| `$CI_STORAGE_HOST` | string | string or $null | e.g. "http://localhost:9023"; $null if no GCS |
| `$CI_REDIS_URL` | string | required | e.g. "redis://localhost:6399/0" |
| `$CI_PYTHONPATH_EXTRA` | array | @() | Extra paths for PYTHONPATH (e.g. entrypoint_backend) |
| `$CI_CATALOG_DIR` | string | $null | Path to catalog source dir; $null if not used |
| `$CI_CATALOG_COMPILE_CMD` | scriptblock | $null | Command to compile catalog; $null to skip |
| `$CI_COMPILEALL_TARGETS` | array | required | Paths for `python -m compileall` |
| `$CI_RUFF_EXCLUDES` | array | @() | Patterns for `ruff --exclude` |
| `$CI_MYPY_TARGET` | string | required | Path for mypy |
| `$CI_UNIT_PYTEST_FLAGS` | string | required | Full pytest flag string for unit tests (must match deploy-staging, excluding --cov) |
| `$CI_INTEGRATION_PYTEST_FLAGS` | string | required | Full pytest flag string for integration tests |
| `$CI_UNIT_TEST_SETS` | array | required | Hashtables: @{ Name = "…"; Paths = "…" } — mirrors GH Actions matrix |
| `$CI_INTEGRATION_BATCHES` | array | required | Hashtables: @{ Name = "…"; Paths = "…" } |
| `$CI_PLAYWRIGHT_DIR` | string | $null | Path to run Playwright from; $null to skip |
| `$CI_NODE_JOBS` | array | @() | Hashtables: @{ Name = "…"; Dir = "…"; Steps = @("lint", "tsc", …) } |

---

## How `core.ps1` uses config

- **Unit tests:** For each `$CI_UNIT_TEST_SETS` entry, `core.ps1` runs pytest with paths and `$CI_UNIT_PYTEST_FLAGS` (split on spaces and passed as arguments). No hardcoded flags — flags come only from config.
- **Integration tests:** Same pattern using `$CI_INTEGRATION_BATCHES` and `$CI_INTEGRATION_PYTEST_FLAGS`.
- **mypy:** Run once against `$CI_MYPY_TARGET`; **non-blocking** (continue-on-error) so local behavior matches CI.
- **Bootstrap:** `core.ps1` does not call bootstrap; the project’s `local_ci.ps1` (or a thin `.ci/bootstrap-helper.ps1`) dot-sources `_XAC_Base/ci/scripts/bootstrap.ps1` so `$CI_SHARED_PATH` is set before invoking `core.ps1`.

---

## Local vs CI pytest flags

For a correctly configured project, the same flag strings are used in both places:

- **Local:** `core.ps1` reads `$CI_UNIT_PYTEST_FLAGS` and `$CI_INTEGRATION_PYTEST_FLAGS` from `.ci/config.ps1` and passes them to pytest.
- **CI:** The caller workflow passes `unit-pytest-flags` and `integration-pytest-flags` inputs (copied from the same config or a single source of truth). Coverage flags (e.g. `--cov`) belong only in the integration flags input if desired; the workflow does not hardcode them.

Keeping flags in config and passing them through keeps local and origin CI in sync.

---

## Reusable workflow inputs/outputs (reference)

When using XAC’ GitHub Actions:

- **reusable-preflight.yml:** inputs: `python-version`. No outputs.
- **reusable-static-checks.yml:** inputs: `python-version`, `compileall-targets`, `ruff-excludes`, `mypy-target`, `mypy-config`. No outputs.
- **reusable-python-tests.yml:** inputs: `python-version`, `unit-test-matrix`, `integration-test-matrix`, `unit-pytest-flags`, `integration-pytest-flags`, `pythonpath-extra`, `needs-gcs-emulator`, `run-catalog-compile`. No outputs.
- **reusable-build-push.yml:** inputs: `project-id`, `region`, `repo-name`, `service-name`, `dockerfile`. Outputs: `image-uri`, `image-tag`.
- **reusable-deploy-staging.yml:** inputs: `project-id`, `region`, `service-name`, `image-uri`, `revision-suffix`, `playwright-dir`, `health-endpoint`, `smoke-endpoints`. Outputs: revision name, URL.
- **reusable-deploy-production.yml:** inputs: same as staging plus `run-migrations`, `migration-command`, `canary-percentage`, `canary-bake-minutes`, `error-rate-threshold`. Outputs: revision name, URL.
- **reusable-smoke-tests.yml:** inputs: `base-url`, `health-endpoint`, `readiness-endpoint`, `smoke-endpoints`.
- **reusable-playwright.yml:** inputs: `base-url`, `playwright-dir`, `browsers`, `node-version`, `shard-total`.
- **reusable-traffic-shift.yml:** inputs: `project-id`, `region`, `service-name`, `revision-name`, `percentage`.
- **reusable-rollback.yml:** inputs: `project-id`, `region`, `service-name`, `failed-revision`, `reason`.

(Exact input names may vary slightly in the workflow files; this is the intended contract.)

---

## Changelog / breaking changes

- **2026-03-11:** Introduced `$CI_UNIT_PYTEST_FLAGS` and `$CI_INTEGRATION_PYTEST_FLAGS`; `core.ps1` no longer hardcodes pytest flags. Config must define both.
- **2026-03-11:** mypy is non-blocking in both local and CI (see DECISIONS.md).
- **2026-03-11:** Bootstrap moved to `scripts/bootstrap.ps1`; callers must dot-source it before `core.ps1`.

---

## How to apply this in your project

Use this doc when adding or changing `$CI_*` variables or when aligning a new project’s config. Update the changelog when you change the config contract so consumers know what to add or migrate.
