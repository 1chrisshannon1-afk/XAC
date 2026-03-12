# _XAC_Config

**XAC configuration for {{PROJECT_NAME}}.** Contains only what XAC needs: CI config, Cursor rules overlay, and IaC. Project-specific scripts, Docker, GCP CI/CD, briefs, and docs live in **`_Config_Project/`**.

**→ First time?** See **[CUSTOMIZE.md](CUSTOMIZE.md)** for a step-by-step list of what to edit (paths, test sets, IaC, cursor) and what the script already set for you.

## Layout (this folder)

| Folder | Purpose |
|--------|---------|
| **ci/** | `config.ps1` — master project config (GCP, paths, test sets). Root `.ci/config.ps1` sources this. `local_ci.ps1` — local CI entry point (loads config, runs `_XAC_Base/ci/local_ci/core.ps1`). |
| **cursor/** | Cursor overlay: `cursorrules.project`, `cursorignore.project`, `rules/`. Assembled with `_XAC_Base/cursor/` into root `.cursorrules` and `.cursorignore`. |
| **iac/** | Terraform for this project (uses modules from `_XAC_Base/iac/modules/`). |

## How root references this

| Root | Uses |
|------|------|
| `.ci/config.ps1` | Thin wrapper — sources `{{XAC_CONFIG_NAME}}/ci/config.ps1` |
| `.cursorrules` / `.cursorignore` | Assembled from `_XAC_Base/cursor/` + `{{XAC_CONFIG_NAME}}/cursor/` |

## Running commands (no root stubs)

| Task | Command (from repo root) |
|------|--------------------------|
| Local CI | `.\{{XAC_CONFIG_NAME}}\ci\local_ci.ps1` |
| Docker start | `.\_Config_Project\docker\docker-start.ps1 -Dev` |
| Docker stop | `.\_Config_Project\docker\docker-stop.ps1` |

## The 3-folder split

| Folder | What goes here | Who changes it |
|--------|---------------|----------------|
| **_XAC_Base/** | Shared CI engine, hooks, templates, IaC modules, monitoring, docs | XAC maintainers (sync workflow) |
| **{{XAC_CONFIG_NAME}}/** | CI config, local CI entry, cursor rules overlay, project IaC | Project team when CI/IaC/rules change |
| **_Config_Project/** | Docker, deploy scripts, GCP setup, tooling configs, project docs | Project team for project-specific ops |
