# Cursor project config (rules, cursorrules.project, cursorignore.project)

**Canonical source** for project-specific Cursor rules. Root `.cursor/rules/` and `.cursorrules` are **sync targets**.

## Sync to root

After editing files here or after pulling _XAC_Base updates, run:

```powershell
.\_Config_Project\scripts\sync-cursor-rules-to-root.ps1
```

This copies `_XAC_Base/cursor/rules/*` to `.cursor/rules/`, then overwrites with this folder's `rules/*`, and assembles `.cursorrules` from `_XAC_Base/cursor/cursorrules.base` + `cursorrules.project`.

Do not edit `.cursor/rules/` or `.cursorrules` directly; edit here and sync.
