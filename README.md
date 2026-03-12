# _XAC_Base

**XAC** = shared **CI, IaC, monitoring, and docs** used by all consuming projects. This folder is the **platform**; project-specific config lives in **`_XAC_Config/`** (or your project’s config folder name).

---

## Download / onboard XAC (run from repo root)

**Use this when you are setting up a new project to use XAC.** From your **new project repo root** (the repository that will consume XAC), run in **PowerShell**:

```powershell
irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 | iex
```

- **Where to run:** Your new project’s repo root (e.g. `C:\repos\MyNewApp`).
- **What it does:** Downloads and runs the XAC onboarding script. It will:
  - Create **`.github/workflows/sync-xac.yml`** so GitHub Actions can sync `_XAC_Base/` from the XAC repo.
  - Create **`.ci/config.ps1`** (thin wrapper that sources your config folder).
  - Create **`_XAC_Config/`** (or the name you choose) with `ci/`, `cursor/`, `iac/`, and a **CUSTOMIZE.md** checklist.
- **Next steps:** Edit variables in the new config folder per **CUSTOMIZE.md**, then add `_XAC_Base` (run **Actions → Sync _XAC_Base → Run workflow** or use `git subtree add`). Full flow: **docs/ADDING_A_CONSUMER.md**.

---

## Layout (this folder)

| Path | Purpose |
|------|---------|
| **ci/** | Local CI engine, scripts, templates |
| **ci/local_ci/core.ps1** | Shared CI engine (invoked by each project’s `local_ci.ps1`) |
| **ci/scripts/** | bootstrap.ps1, verify-setup.ps1, canary-health-check.sh |
| **ci/templates/** | config.ps1, local_ci.ps1, deploy-staging.yml, sync-xac-consumer.yml, Dockerfile templates |
| **ci/hooks/** | pre-commit.ps1, pre-push.ps1, install.ps1 — install with `.\_XAC_Base\ci\hooks\install.ps1` from repo root |
| **iac/** | Terraform modules, policies, reusable-terraform workflow |
| **iac/modules/** | wif-github, artifact-registry, secret-manager, cloud-run-service, cloud-build, network, budget-alerts, cloud-monitoring, project-baseline |
| **iac/policies/** | OPA Rego (health check, no plain secrets, require labels) |
| **iac/workflows/** | reusable-terraform.yml |
| **monitoring/** | Dashboards and runbooks |
| **monitoring/dashboards/** | cloud-run-baseline.json |
| **monitoring/runbooks/** | HIGH_ERROR_RATE, HIGH_LATENCY, DEPLOYMENT_FAILED, COST_SPIKE, INSTANCE_ANOMALY |
| **docs/** | Contracts and conventions (HEALTH_CHECK, SECRET_NAMING, ONBOARDING, IaC_ONBOARDING, ADDING_A_CONSUMER, etc.) |

---

## How a consuming project uses this

1. **Option A — _XAC_Base in repo (typical):** Ensure **`_XAC_Base/`** is at repo root (this folder). The project’s **`_XAC_Config/ci/local_ci.ps1`** loads **`.ci/config.ps1`** and bootstraps; bootstrap sets `$CI_SHARED_PATH` to **`_XAC_Base/ci`** so **`local_ci/core.ps1`** is found.

2. **Option B — Sibling XAC:** Clone [XAC](https://github.com/1chrisshannon1-afk/XAC) as a sibling directory; point `$CI_SHARED_PATH` at that clone (or use **`.ci/bootstrap-helper.ps1`**).

3. **Terraform:** Project IaC (e.g. **`_XAC_Config/iac`**) uses `source = "../../_XAC_Base/iac/modules/project-baseline"`. Run **`terraform init`** and **`terraform plan`** from the project’s iac directory.

4. **Verify setup (from repo root):**
   ```powershell
   .\_XAC_Base\ci\scripts\verify-setup.ps1
   ```
   Confirms Docker, Python, Node, `gh`, repo config, and XAC paths.

---

## Key commands (all from repo root)

| Task | Command |
|------|---------|
| Onboard a new project to XAC | `irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 \| iex` |
| Run local CI | `.\_XAC_Config\ci\local_ci.ps1` |
| Verify machine setup | `.\_XAC_Base\ci\scripts\verify-setup.ps1` |
| Install git hooks | `.\_XAC_Base\ci\hooks\install.ps1` |

---

## Reference

- **All `$CI_*` variables:** **docs/REFERENCE.md**
- **Provisioning a new GCP project:** **docs/IaC_ONBOARDING.md**
- **Publishing _XAC_Base to the XAC repo:** **docs/PUBLISH_TO_XAC.md**
- **Onboarding a new consumer (full steps):** **docs/ADDING_A_CONSUMER.md** and **ONBOARDING.md**

---

## Full onboarding (monitoring, runbooks, policies, workflows)

- **Monitoring:** The **project-baseline** Terraform module composes **cloud-monitoring** per service: dashboards (from **monitoring/dashboards/cloud-run-baseline.json**), alert policies (error rate, latency, instance anomaly), and runbook links. Alert docs use **runbook_base_url** (set in project config or left empty to use this repo’s **monitoring/runbooks**).
- **Runbooks:** **monitoring/runbooks/** (HIGH_ERROR_RATE, HIGH_LATENCY, DEPLOYMENT_FAILED, COST_SPIKE, INSTANCE_ANOMALY). Linked from alert policies when **runbook_base_url** is set (e.g. GitHub URL to this path).
- **Policies:** OPA Rego in **iac/policies/** (require-labels, cloud-run-health-check, no-plain-env-secrets). Used by **iac/workflows/reusable-terraform.yml** when running Terraform from a project path (e.g. **`_XAC_Config/iac`**).
- **Workflows:** **iac/workflows/reusable-terraform.yml** is the standard for Terraform + OPA. Call it with **`project-path`** pointing to your project’s Terraform directory.

---

## Versioning

- **VERSION** and **CHANGELOG.md** live in this folder. Sync updates **only** `_XAC_Base/`; consumer config (`_XAC_Config/`, etc.) is never rebuilt by sync.
- **Pin to a release:** Run **Sync _XAC_Base** (Actions or `gh workflow run sync-xac.yml`) with **`xac_ref=v1.0.0`** (or another tag). See **docs/VERSIONING_AND_CONFIG_UPDATE.md** for config adoption and breaking changes.
