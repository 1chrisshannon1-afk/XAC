# Reference: config and wrapper examples

The shared engine is driven by **project-specific config**. See **docs/REFERENCE.md** for the full living reference (all $CI_* variables, workflow inputs/outputs, changelog).

Quick pointers:
- **Project config:** Copy from `ci/templates/config.ps1` to your repo as `.ci/config.ps1`.
- **Wrapper:** Copy from `ci/templates/local_ci.ps1` to your repo root. It loads `.ci/config.ps1` then invokes `_XAC/ci/local_ci/core.ps1` (or sibling IAC).
- **Bootstrap:** Dot-source `_XAC/ci/scripts/bootstrap.ps1` (or use `.ci/bootstrap-helper.ps1`) so `$CI_SHARED_PATH` is set before core.ps1 runs.
- **Project-specific CI/IaC:** See `_XAC_Config_ContractorScope_/` for ContractorScope AI.
