# _XAC

Cross-project XAC (CI, IaC, monitoring, docs). Shared content used by all projects. Project-specific config lives in `_XAC_Config/` (or similar).

## Layout

| Path | Purpose |
|------|---------|
| **ci/** | Local CI engine, scripts, templates |
| **ci/local_ci/core.ps1** | Shared CI engine (invoked by each project’s `local_ci.ps1`) |
| **ci/scripts/** | bootstrap.ps1, verify-setup.ps1, canary-health-check.sh |
| **ci/templates/** | config.ps1, local_ci.ps1, deploy-staging.yml, deploy-production.yml, Dockerfile.python, Dockerfile.node |
| **iac/** | Terraform modules, policies, reusable-terraform workflow |
| **iac/modules/** | wif-github, artifact-registry, secret-manager, cloud-run-service, cloud-build, network, budget-alerts, cloud-monitoring, project-baseline |
| **iac/policies/** | OPA Rego (health check, no plain secrets, require labels) |
| **iac/workflows/** | reusable-terraform.yml |
| **monitoring/** | Dashboards and runbooks |
| **monitoring/dashboards/** | cloud-run-baseline.json |
| **monitoring/runbooks/** | HIGH_ERROR_RATE, HIGH_LATENCY, DEPLOYMENT_FAILED, COST_SPIKE, INSTANCE_ANOMALY |
| **docs/** | Contracts and conventions (HEALTH_CHECK, SECRET_NAMING, ONBOARDING, IaC_ONBOARDING, etc.) |

## How a consuming project uses this

1. **Option A — _XAC in repo:** Ensure `_XAC` is at repo root (this folder). Project `local_ci.ps1` loads `.ci/config.ps1` and bootstraps; bootstrap sets `$CI_SHARED_PATH` to `_XAC/ci` so `local_ci\core.ps1` is found.

2. **Option B — Sibling XAC:** Clone [XAC](https://github.com/1chrisshannon1-afk/XAC) as a sibling; point `$CI_SHARED_PATH` at that clone (or use `.ci/bootstrap-helper.ps1`).

3. **Terraform:** Project IaC (e.g. `_XAC_Config/iac`) uses `source = "../../_XAC_Base/iac/modules/project-baseline"`. Run `terraform init` and `terraform plan` from the project iac dir.

4. **Verify setup:** `.\_XAC\ci\scripts\verify-setup.ps1`

## Reference

See **docs/REFERENCE.md** for all `$CI_*` variables and **docs/IaC_ONBOARDING.md** for provisioning a new project.  
To publish _XAC to the XAC GitHub repo, see **docs/PUBLISH_TO_XAC.md**.

## Full onboarding (monitoring, runbooks, policies, workflows)

- **Monitoring:** The **project-baseline** module composes **cloud-monitoring** per service: dashboards (from `monitoring/dashboards/cloud-run-baseline.json`), alert policies (error rate, latency, instance anomaly), and runbook links. Alert documentation uses **runbook_base_url** (set in project config or left empty to use this repo’s `_XAC/monitoring/runbooks`).
- **Runbooks:** Live in **monitoring/runbooks/** (HIGH_ERROR_RATE, HIGH_LATENCY, DEPLOYMENT_FAILED, COST_SPIKE, INSTANCE_ANOMALY). Linked from alert policies when `runbook_base_url` is set (e.g. GitHub URL to this path).
- **Policies:** OPA Rego in **iac/policies/** (require-labels, cloud-run-health-check, no-plain-env-secrets). Used by **iac/workflows/reusable-terraform.yml** when running Terraform from a project path (e.g. `_XAC_Config/iac`).
- **Workflows:** **iac/workflows/reusable-terraform.yml** is the standard for Terraform + OPA. Call it with `project-path` pointing to your project’s Terraform dir.


## Versioning

- **VERSION** and **CHANGELOG.md** in this folder. Sync updates only \_XAC/\; consumer config (\_XAC_Config_*\) is never rebuilt by sync.
- To pin to a release: run Sync _XAC with \xac_ref=v1.0.0\ (or another tag). See **docs/VERSIONING_AND_CONFIG_UPDATE.md** for config adoption and breaking changes.

