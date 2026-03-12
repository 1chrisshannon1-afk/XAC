# Customize _XAC_Config After Onboarding

The onboarding script filled in **project name, GCP project, GitHub org/repo, and region**. You only need to edit the items below to match your codebase and infra.

---

## 1. CI config — `ci/config.ps1`

Edit these variables so local CI and GitHub Actions match your repo layout.

| Variable | What to set | Example |
|----------|-------------|---------|
| `$CI_COMPOSE_FILE` | Path to docker-compose CI file | Already set to `_XAC_Base/ci/templates/docker-compose.ci.yml` |
| `$CI_PYTHONPATH_EXTRA` | Extra Python path for tests (array) | `@("entrypoint_backend")` or `@()` |
| `$CI_CATALOG_DIR` | Catalog source dir, or `$null` | `"$ROOT\modules\catalog\data"` or `$null` |
| `$CI_CATALOG_COMPILE_CMD` | Scriptblock to compile catalog, or `$null` | See existing projects for pattern |
| `$CI_COMPILEALL_TARGETS` | Paths for `python -m compileall` | `@("backend", "modules/core")` |
| `$CI_RUFF_EXCLUDES` | Patterns to exclude from ruff | Add your `**/migrations/**`, legacy dirs, etc. |
| `$CI_MYPY_TARGET` | Path for mypy, or `$null` | `"backend"` or `$null` |
| `$CI_UNIT_TEST_SETS` | Array of `@{ Name = "…"; Paths = "…" }` | One entry per parallel unit job; Paths = space-separated dirs |
| `$CI_INTEGRATION_BATCHES` | Array of `@{ Name = "…"; Paths = "…" }` | One entry per integration batch |
| `$CI_PLAYWRIGHT_DIR` | Dir containing Playwright tests, or `$null` | `"$ROOT\frontend"` or `$null` |
| `$CI_NODE_JOBS` | Array of `@{ Name = "…"; Dir = "…"; Steps = @("lint", "tsc") }` | Add if you have Node/frontend jobs |

**Tip:** Match `$CI_UNIT_TEST_SETS` and `$CI_INTEGRATION_BATCHES` to the `unit-test-matrix` and `integration-test-matrix` in `.github/workflows/xac-ci.yml` so local CI and GitHub Actions stay in sync.

---

## 2. IaC — `iac/`

| Task | Where |
|------|--------|
| Add/change services (e.g. backend, frontend) | `main.tf` — edit the `services` list and `artifact_registry_repo_id` |
| Add secrets | `main.tf` — add to `secrets` and each service’s `secret_ids`; create secrets in GCP |
| Set billing and alerts | Copy `terraform.tfvars.example` to `terraform.tfvars`, set `billing_account_id`, `alert_email_addresses`. **Do not commit terraform.tfvars.** |
| State bucket | Ensure GCS bucket `{project_id}-terraform-state` exists; `backend.tf` already points to it |

---

## 3. Cursor — `cursor/`

| File | Purpose |
|------|---------|
| `cursorrules.project` | Project-specific agent rules (GCP project, app URL, deploy commands, structure). |
| `cursorignore.project` | Paths to ignore (logs, uploads, local data). |
| `rules/*.md` | Optional project rule files; sync to root with your sync script. |

---

## 4. Add _XAC_Base to the repo

If you haven’t already:

- **Option A:** In GitHub, go to **Actions → Sync _XAC_Base → Run workflow** (it will add the subtree and open a PR).
- **Option B:** From repo root:  
  `git subtree add --prefix=_XAC_Base https://github.com/1chrisshannon1-afk/XAC.git main --squash`

---

## 5. Root assembly

- **.cursorrules / .cursorignore:** Assemble from `_XAC_Base/cursor/` + this folder’s `cursor/` (see `_XAC_Base/cursor/README.md`).
- **Docker:** Add Dockerfiles under `_Config_Project/docker/` (or your project’s docker path) and point any root docker-compose at them.

---

## Quick reference: what the script already set

- Project name, label, GCP project ID, region  
- GitHub org and repo (used in IaC and runbook URLs)  
- Config folder name (e.g. `_XAC_Config`)  
- `.ci/config.ps1` thin wrapper and `.github/workflows/sync-xac.yml` + `xac-ci.yml`

You only customize paths, test sets, IaC services/secrets, and cursor rules as above.
