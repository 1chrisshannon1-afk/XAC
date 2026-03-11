# XAC Cursor Configuration

Shared Cursor IDE configuration templates for all XAC-consuming projects.

## Files

| File | Purpose |
|------|---------|
| `cursorrules.base` | Base `.cursorrules` content — execution model, git discipline, post-task workflow, testing, do-not list |
| `cursorignore.base` | Base `.cursorignore` patterns — venvs, build artifacts, coverage, credentials, binaries, logs |
| `rules/project_lock.mdc` | Template — GCP project lock with `{{PROJECT_ID}}`, `{{PROJECT_DISPLAY_NAME}}`, `{{APP_URL}}` placeholders |
| `rules/no_spanner_firestore_only.mdc` | Shared rule — no Cloud Spanner, Firestore only |
| `rules/automatic_refactoring_rules.md` | Shared rule — safe refactoring for files > 500 lines |

## Setup for a New Project

1. **Copy base files** into project root and `.cursor/rules/`:

```powershell
# .cursorrules = base + project-specific additions
# Assemble from:
#   _XAC/cursor/cursorrules.base
#   _XAC_Config_<ProjectName>/cursor/cursorrules.project

# .cursorignore = base + project-specific additions
# Assemble from:
#   _XAC/cursor/cursorignore.base
#   _XAC_Config_<ProjectName>/cursor/cursorignore.project
```

2. **Populate templates** — replace `{{PROJECT_ID}}`, `{{PROJECT_DISPLAY_NAME}}`, `{{APP_URL}}` in `project_lock.mdc` with your project values.

3. **Copy shared rules** into `.cursor/rules/`:
   - `no_spanner_firestore_only.mdc`
   - `automatic_refactoring_rules.md`
   - Populated `project_lock.mdc`

4. **Add project-specific rules** to `_XAC_Config_<ProjectName>/cursor/rules/` and copy into `.cursor/rules/`.

## Layering Convention

```
.cursorrules  =  _XAC/cursor/cursorrules.base  +  _XAC_Config_<Project>/cursor/cursorrules.project
.cursorignore =  _XAC/cursor/cursorignore.base  +  _XAC_Config_<Project>/cursor/cursorignore.project
.cursor/rules/*  =  _XAC/cursor/rules/*  +  _XAC_Config_<Project>/cursor/rules/*
```
