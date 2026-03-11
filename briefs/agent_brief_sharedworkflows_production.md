# Agent Brief: SharedWorkflows — Production CI/CD

# Repo: https://github.com/1chrisshannon1-afk/SharedWorkflows

---

## Context

Production pipeline for the shared GitHub Actions CI/CD in SharedWorkflows. Runs **in parallel** with each project’s existing CI. Same reusable workflows as staging where possible; production-specific defaults (longer canary bake, stricter notifications). Auth: Workload Identity Federation.

---

## Relationship to staging

- Staging brief: `agent_brief_sharedworkflows_staging.md` — defines pipeline order, fixes (bake time, Playwright shards, migrations, canary health check, success/rollback notifications, YAML structure).
- Production uses the **same** reusable workflow files with production-specific **inputs** (e.g. `canary-bake-minutes: 20` or `30`, production service name, production secrets).

All technical fixes from the staging brief apply to production:

| Item | Production default |
|------|--------------------|
| **Canary bake** | **20–30 minutes** (explicit in brief; 5 minutes is not statistically meaningful). |
| **Playwright** | Fixed 3 shards; no dynamic shard-count input. |
| **Migrations** | Run after image build, before any traffic hits new revision. |
| **Canary health check** | Repeated HTTP checks with pass/fail threshold (no pseudocode gcloud monitoring). |
| **Success notification** | Sent on full cutover; rollback sends failure notification. |
| **YAML** | `jobs` at top level, not under `on:`. |

---

## Pipeline overview (production)

```
1.  Pre-flight checks
2.  Security scans
3.  Static analysis
4.  Unit tests
5.  Integration tests
6.  Build & push image
7.  Database migrations     (before any traffic to new revision)
8.  Deploy at 0% traffic
9.  Smoke tests
10. Playwright E2E           (fixed 3 shards)
11. Traffic shift: 10%       (canary)
12. Canary health check      (20–30 min bake; HTTP-based threshold)
13. Traffic shift: 100%
14. Success notification
15. Auto-rollback            (on failure in 8–13)
```

---

## Production-specific inputs

- **reusable-traffic-shift.yml:** `canary-bake-minutes: 30` for production (staging 15–20).
- **reusable-deploy-canary.yml:** `environment: production`, production service name and project.
- **reusable-rollback.yml** and **notify:** Same as staging; ensure production webhook/channel if different.

---

## File structure

Same as staging; see `agent_brief_sharedworkflows_staging.md`. Reusable workflows live in `.github/workflows/`; production caller workflow (e.g. `deploy-production.yml`) in the consuming repo calls them with production inputs.

---

## Definition of done (production)

1. Production deploy uses the same reusable workflows as staging with production inputs.
2. Canary bake is **20–30 minutes**; health check is HTTP-based with clear threshold.
3. Migrations run before traffic hits the new revision.
4. Success and rollback notifications both implemented.
5. All workflow YAML has correct structure (`jobs` at top level).
