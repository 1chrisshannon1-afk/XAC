# Onboarding — Adding a New Project to XAC

**Last reviewed:** 2026-03-11

Step-by-step guide for adding a new project so it uses XAC (shared CI/IaC/monitoring) for local CI and (when wired) deploy pipelines.

---

## 1. Clone XAC

Clone XAC as a sibling to your project repo:

```bash
git clone https://github.com/1chrisshannon1-afk/XAC.git
```

(Or use the path your org uses for the shared repo. The project’s `local_ci.ps1` will expect it at a sibling directory named `XAC` unless overridden.)

---

## 2. Copy templates into your project

Copy (do not symlink) these files and adapt:

| From | To |
|------|-----|
| `templates/ci-config/config.ps1` | `.ci/config.ps1` |
| `templates/local-ci/local_ci.ps1` | `local_ci.ps1` (repo root) |
| `templates/workflows/deploy-staging.yml` | `.github/workflows/deploy-staging.yml` |
| `templates/docker/Dockerfile.python` | `Dockerfile` (adapt as needed) |

---

## 3. Edit `.ci/config.ps1`

- Set all `$CI_*` variables for your project (name, compose file, containers, GCP test project, paths).
- Copy unit test sets from your existing workflow matrix into `$CI_UNIT_TEST_SETS`.
- Copy integration batches from your existing workflow matrix into `$CI_INTEGRATION_BATCHES`.
- Ensure `$CI_UNIT_PYTEST_FLAGS` and `$CI_INTEGRATION_PYTEST_FLAGS` match what you use in deploy-staging (excluding `--cov` flags).

---

## 4. Edit `.github/workflows/deploy-staging.yml`

- Replace all `<PLACEHOLDER>` values with your project ID, repo name, service name, paths.
- Paste your unit-test-matrix JSON (matching `$CI_UNIT_TEST_SETS`).
- Paste your integration-test-matrix JSON (matching `$CI_INTEGRATION_BATCHES`).
- Ensure the pytest flag inputs match `.ci/config.ps1`.

---

## 5. Implement health check endpoints

Implement `/health` and `/health/ready` per `docs/HEALTH_CHECK_CONTRACT.md` so smoke tests and canary checks work.

---

## 6. Verify setup

From your project root:

```powershell
.\XAC\ci\scripts\verify-setup.ps1
```

(If you use _XAC in-repo: `.\_XAC\ci\scripts\verify-setup.ps1`.)

Fix any reported failures (Docker, Python, Node, `gh`, `.ci/config.ps1`, `docker-compose.ci.yml`, `.secrets.baseline`).

---

## 7. Run local CI

```powershell
.\local_ci.ps1
```

Local CI should bootstrap XAC automatically (clone if missing, warn if stale) when not using _XAC in-repo, and run the full pipeline.

---

## 8. Push to staging (when CI is wired)

Push to the `staging` branch — full CI + deploy pipeline should run. Confirm in your CI provider.

---

## 9. Security tab (when scans are wired)

Verify that SARIF reports (e.g. Bandit, Trivy) appear in the GitHub Security tab after a CI run.

---

## How to apply this in your project

Use this doc as the canonical onboarding checklist. Link to it from your main README or CONTRIBUTING.md. When you add new required steps (e.g. new secrets or env vars), update this list and the “Last reviewed” date.
