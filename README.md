# SharedWorkflows

Shared CI/CD engine and GitHub Actions reusable workflows for GCP Cloud Run projects. Any project can onboard by copying templates and filling in project-specific config.

**GitHub:** https://github.com/1chrisshannon1-afk/SharedWorkflows

## Quick Start (New Project)

```bash
# From your project root:
../SharedWorkflows/scripts/bootstrap.sh
# Then: edit .ci/config.ps1 and .github/workflows/deploy-staging.yml
# Then: ../SharedWorkflows/scripts/verify-setup.sh
# Then: .\local_ci.ps1
```

See `docs/ONBOARDING.md` for the full guide.

## Repository Contents

```
SharedWorkflows/
├── .github/
│   ├── workflows/
│   │   ├── reusable-preflight.yml          # Branch/commit checks
│   │   ├── reusable-static-checks.yml      # compileall, ruff, mypy (non-blocking default)
│   │   ├── reusable-python-tests.yml       # Unit + integration tests (parallel matrix)
│   │   ├── reusable-build-push.yml         # Docker build + push to Artifact Registry
│   │   ├── reusable-deploy-canary.yml      # Deploy at 0% traffic
│   │   ├── reusable-smoke-tests.yml        # HTTP health/readiness checks
│   │   ├── reusable-playwright.yml         # E2E tests (fixed 3 shards)
│   │   ├── reusable-traffic-shift.yml      # 10% canary → 15-30 min bake → 100%
│   │   └── reusable-rollback.yml           # Auto-rollback on failure
│   └── actions/
│       ├── gcp-auth/action.yml             # WIF auth composite action
│       ├── start-emulators/action.yml      # Firestore + Redis + optional GCS
│       └── notify/action.yml               # Slack + step summary notifications
├── local_ci/
│   └── core.ps1                            # Local CI engine (PowerShell)
├── scripts/
│   ├── bootstrap.sh                        # Bootstrap a new project
│   ├── verify-setup.sh                     # Verify project setup
│   └── canary-health-check.sh              # HTTP-based canary health check
├── templates/
│   ├── config.ps1.template                 # Project config template
│   ├── local_ci.ps1.template               # Local CI wrapper template
│   └── deploy-staging.yml.template         # GitHub Actions deploy template
├── docs/
│   └── ONBOARDING.md                       # Full onboarding guide
├── briefs/
│   ├── agent_brief_sharedworkflows_staging.md
│   └── agent_brief_sharedworkflows_production.md
└── README.md
```

## Pipeline Stages (Staging)

```
1. Preflight          — fast checks (requirements.txt, secrets baseline)
2. Static checks      — compileall, ruff check, ruff format, mypy
3. Tests (parallel)   — unit tests (matrix) + integration tests (matrix)
4. Build & push       — Docker image to Artifact Registry
5. Deploy at 0%       — new Cloud Run revision, zero traffic
6. Smoke tests        — HTTP health checks against 0% revision
7. Playwright E2E     — 3 fixed shards against 0% revision
8. Canary (10%)       — shift 10% traffic, bake 15-30 min with HTTP monitoring
9. Cutover (100%)     — full traffic + success notification
10. Auto-rollback     — on any failure in 5-9
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **mypy non-blocking** | Matches existing CI; avoids blocking on type issues during migration |
| **Playwright 3 fixed shards** | GitHub Actions cannot generate matrix from workflow input; fixed works |
| **15-30 min canary bake** | 5 min is not statistically meaningful for error detection |
| **HTTP-based canary health** | Real pass/fail threshold; no pseudocode gcloud monitoring |
| **Success + rollback notifications** | Both directions must notify; previously only rollback did |
| **pytest flags from config** | Prevents local/CI divergence; config is single source of truth |
| **`jobs` at YAML top level** | GitHub Actions requires this; nested under `on:` causes parse error |

## Config Variables (core.ps1)

See `templates/config.ps1.template` for the complete list. Key additions over basic setup:

- `$CI_MYPY_BLOCKING` — `$false` (default) = warn only; `$true` = fail CI
- `$CI_UNIT_PYTEST_FLAGS` — override default unit test flags
- `$CI_INTEGRATION_PYTEST_FLAGS` — override default integration test flags
