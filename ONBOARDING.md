# XAC — Onboard a new consumer (one command)

From the **new project repo root** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 | iex
```

That single command downloads and runs the onboarding script from this repo. It creates in the consumer repo:

- `.github/workflows/sync-xac.yml` (from this repo’s `ci/templates/sync-xac-consumer.yml`)
- `.ci/config.ps1` (thin wrapper)
- `local_ci.ps1` (stub → `_XAC/ci/local_ci.ps1`)
- `_XAC_Config_<Project>/` with ci/, cursor/, docker/, iac/, cicd/, briefs/

Then they edit variables in the config folder and add _XAC (Sync _XAC workflow or `git subtree add`). Full steps: `docs/ADDING_A_CONSUMER.md`.
