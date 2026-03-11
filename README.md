# SharedWorkflows

Shared CI engine and (later) GitHub Actions reusable workflows. Consuming projects keep their own config and a thin wrapper that invokes this repo.

## Repository

- **GitHub:** [https://github.com/1chrisshannon1-afk/SharedWorkflows](https://github.com/1chrisshannon1-afk/SharedWorkflows)

## Reference documentation

The **canonical design and project-specific config examples** live in the ContractorScope AI repo under:

- **`_SHARED CI (in dev)/`** — reference implementation and docs:
  - **`config.ps1`** — example project config (all `$CI_*` variables). Copy/adapt into your repo as `.ci/config.ps1`.
  - **`local_ci.ps1`** — example wrapper that loads `.ci/config.ps1` and invokes this repo’s `local_ci/core.ps1`.
  - **`core.ps1`** — same logic as this repo’s `local_ci/core.ps1`; kept in dev for reference and diff.

Use those files as the source of truth for variable names, step order, and how to wire a new project.

## Contents of this repo

| Path | Purpose |
|------|--------|
| `local_ci/core.ps1` | Shared CI engine. Do not run directly; invoked by each project’s `local_ci.ps1` after loading its `.ci/config.ps1`. |

## How a consuming project uses this

1. **In your repo:** Add a project config and a wrapper script.
   - **`.ci/config.ps1`** — Set all `$CI_*` variables (project name, compose file, containers, test paths, unit/integration sets, Playwright dir, Node jobs). See `_SHARED CI (in dev)/config.ps1` for the full list and an example.
   - **`local_ci.ps1`** (at repo root) — Set `$ROOT`, dot-source `.ci\config.ps1`, set `$CI_SHARED_PATH` to the path of your SharedWorkflows clone, then dot-source `$CI_SHARED_PATH\local_ci\core.ps1`. See `_SHARED CI (in dev)/local_ci.ps1` for the exact pattern.

2. **Clone SharedWorkflows** (this repo) somewhere, e.g. sibling to your project:
   ```powershell
   git clone https://github.com/1chrisshannon1-afk/SharedWorkflows.git
   ```

3. **Point your wrapper at it** (one of):
   - **Env:** `$env:CI_SHARED_PATH = "C:\path\to\SharedWorkflows"`
   - **Sibling:** In `local_ci.ps1`, use `Join-Path (Split-Path $ROOT -Parent) "SharedWorkflows"` so the clone lives next to your repo.

4. **Run CI:** From your project root, run `.\local_ci.ps1`. It loads your config and runs the shared engine.

## Required config variables (set in `.ci/config.ps1`)

Your `.ci/config.ps1` must define (see reference `config.ps1` for types and examples):

- `$CI_PROJECT_NAME`, `$CI_PROJECT_LABEL`
- `$CI_COMPOSE_FILE`, `$CI_CONTAINERS`
- `$CI_GOOGLE_CLOUD_PROJECT`, `$CI_FIRESTORE_HOST`, `$CI_STORAGE_HOST`, `$CI_REDIS_URL`
- `$CI_PYTHONPATH_EXTRA`, `$CI_CATALOG_DIR`, `$CI_CATALOG_COMPILE_CMD` (or `$null`)
- `$CI_COMPILEALL_TARGETS`, `$CI_RUFF_EXCLUDES`, `$CI_MYPY_TARGET`
- `$CI_UNIT_TEST_SETS`, `$CI_INTEGRATION_BATCHES`
- `$CI_PLAYWRIGHT_DIR` (or `$null`), `$CI_NODE_JOBS`

## CI steps (executed by `local_ci/core.ps1`)

1. **Containers** — Down, prune by project label, up with `docker compose -f $CI_COMPOSE_FILE up -d --build --wait`.
2. **Python** — `pip install`, optional catalog compile (if `$CI_CATALOG_COMPILE_CMD` is set).
3. **Static** — `compileall`, `ruff check`, `ruff format --check`, `mypy`.
4. **Unit tests** — Parallel pytest sets (emulators must be healthy).
5. **Integration + Playwright + Node** — All in parallel; then cleanup containers.

## Pushing this content to GitHub

This folder (e.g. `SharedWorkflows/` in ContractorScope AI) mirrors what should be in the GitHub repo. To publish:

1. Clone the repo: `git clone https://github.com/1chrisshannon1-afk/SharedWorkflows.git`
2. Copy into the clone: `local_ci/`, `README.md` (overwrite as needed).
3. Commit and push from the clone.

Existing CI in consuming repos is **not** modified; this runs in parallel until you switch the wrapper to use `CI_SHARED_PATH` pointing at SharedWorkflows.
