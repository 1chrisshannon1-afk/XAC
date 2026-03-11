# Reference: config and wrapper examples

The shared engine in this repo is driven by **project-specific config**. The canonical examples live in the **ContractorScope AI** repo:

| Purpose | Location (ContractorScope AI repo) |
|--------|-------------------------------------|
| Project config example | `_SHARED CI (in dev)/config.ps1` |
| Wrapper script example | `_SHARED CI (in dev)/local_ci.ps1` |
| Same engine (for diff/reference) | `_SHARED CI (in dev)/core.ps1` |

Use **`_SHARED CI (in dev)/config.ps1`** as the template for your `.ci/config.ps1`: it defines every required `$CI_*` variable and the structure of unit test sets, integration batches, and Node jobs.

Your repo’s **`local_ci.ps1`** should:

1. Set `$ROOT = $PSScriptRoot` (or `$PWD.Path`).
2. Dot-source your project config: `. (Join-Path $ROOT ".ci\config.ps1")`
3. Set `$CI_SHARED_PATH` to the directory of your SharedWorkflows clone (or use `$env:CI_SHARED_PATH`).
4. Dot-source the shared engine: `. (Join-Path $CI_SHARED_PATH "local_ci\core.ps1")`

No other changes are required in the consuming repo until you are ready to switch from existing CI to this standardized flow.
