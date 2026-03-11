# Agent Brief: SharedWorkflows — Staging CI/CD

# Repo: https://github.com/1chrisshannon1-afk/SharedWorkflows

---

## Context

Staging pipeline for the shared GitHub Actions CI/CD in SharedWorkflows. Runs **in parallel** with each project’s existing CI; existing pipelines are not modified. Output is additive — new reusable workflows and a project-specific caller workflow that consuming projects can opt into.

Target: GCP Cloud Run (staging), Artifact Registry, Cloud Build. Auth: Workload Identity Federation.

---

## Pipeline overview (staging)

```
1.  Pre-flight checks        (parallel, fast)
2.  Security scans           (parallel)
3.  Static analysis          (parallel)
4.  Unit tests               (parallel matrix)
5.  Integration tests        (parallel matrix)
6.  Build & push image       (single job)
7.  Database migrations      (after image, before any traffic to new revision)
8.  Deploy at 0% traffic     (single job)
9.  Smoke tests              (against 0% revision URL)
10. Playwright E2E           (against 0% revision URL, fixed 3 shards)
11. Traffic shift: 10%       (canary)
12. Canary health check      (15–30 min bake; real HTTP-based pass/fail threshold)
13. Traffic shift: 100%      (full cutover)
14. Success notification    (Slack + summary on successful cutover)
15. Auto-rollback            (on any failure in 8–13); rollback sends failure notification
```

---

## Fixes applied (vs initial brief)

| Issue | Fix |
|-------|-----|
| **Bake time too short** | Canary bake is **15–30 minutes** (configurable). Brief and default input state this explicitly; 5 minutes is not statistically meaningful. |
| **Playwright sharding broken** | **Fixed 3 shards.** Matrix is `shard: [1, 2, 3]`. No dynamic `shard-count` input — GitHub Actions cannot generate a matrix from a workflow input. Use exactly 3 shards; document in brief. |
| **No database migration step** | Add **reusable-migrations.yml** (or a step in deploy flow): runs **after** image is built and **before** any traffic hits the new revision. Consuming project provides migration command (e.g. run a Cloud Run job or a step that invokes migrations against the target). |
| **Canary health check naive** | Use **repeated HTTP checks** with a real pass/fail threshold (e.g. N requests over bake period, max allowed non-200 count). No pseudocode “gcloud monitoring” that doesn’t return useful error rate. Script: `scripts/canary-health-check.sh` with clear contract. |
| **No success notification** | **Success notification** on full cutover (Slack + step summary). Rollback already sends failure notification; both must be present. |
| **YAML structural error** | **jobs** is at top level of the workflow file, **not** nested inside `on:`. All reusable workflows use correct structure: `on: workflow_call:` then top-level `jobs:`. |

---

## File structure (shared/)

```
shared/
├── .github/
│   ├── workflows/
│   │   ├── reusable-preflight.yml
│   │   ├── reusable-scans.yml
│   │   ├── reusable-static-checks.yml
│   │   ├── reusable-python-tests.yml
│   │   ├── reusable-build-push.yml
│   │   ├── reusable-migrations.yml
│   │   ├── reusable-deploy-canary.yml
│   │   ├── reusable-smoke-tests.yml
│   │   ├── reusable-playwright.yml
│   │   ├── reusable-traffic-shift.yml
│   │   ├── reusable-rollback.yml
│   │   └── reusable-notify.yml (or notify step in traffic-shift/cutover)
│   └── actions/
│       ├── gcp-auth/action.yml
│       └── notify/action.yml
├── scripts/
│   └── canary-health-check.sh
└── briefs/
    ├── agent_brief_sharedworkflows_staging.md   (this file)
    └── agent_brief_sharedworkflows_production.md
```

---

## Canary bake and health check

- **Default canary-bake-minutes:** 15 (minimum 15, recommend 15–30 for staging; production brief uses 20–30).
- **Health check:** No reliance on Cloud Monitoring for error rate in the brief. Use **repeated HTTP requests** to the service URL over the bake period:
  - Interval every 30–60 s.
  - Threshold: e.g. allow at most 2 non-200 responses out of 20 checks, or equivalent (configurable).
  - Script `canary-health-check.sh` implements this and exits 0/1; workflow step runs it and fails the job on exit 1.

---

## Playwright

- **Fixed shards:** Matrix is `shard: [1, 2, 3]`. No `shard-count` input.
- `reusable-playwright.yml` runs: `npx playwright test --shard=${{ matrix.shard }}/3 ...`

---

## Database migrations

- **reusable-migrations.yml** (or a dedicated job in the deploy flow):
  - Inputs: `project-id`, `region`, `service-name`, `image-uri`, `revision-suffix`, optional `migration-command` (e.g. run a Cloud Run job that executes migrations).
  - Runs **after** build, **before** deploy at 0%. Optionally: deploy at 0% first, run migrations against that revision’s DB/config, then proceed. Either way: migrations must complete before traffic hits the new revision.
  - If the project has no migrations, the workflow can be a no-op or the caller omits it.

---

## Notifications

- **On rollback:** Existing rollback workflow calls `notify` with status `rollback`.
- **On success:** After traffic shift 100%, add a step (or job) that calls `notify` with status `success` and message “Staging deployment complete — 100% traffic to revision X.”

---

## Reusable workflow YAML structure

Every reusable workflow must have this shape (jobs at top level):

```yaml
on:
  workflow_call:
    inputs: { ... }
    outputs: { ... }   # if needed

permissions: { ... }

jobs:
  job-name:
    runs-on: ubuntu-latest
    timeout-minutes: N
    steps: [ ... ]
```

Not:

```yaml
on:
  workflow_call:
    inputs: { ... }
    jobs:   # WRONG — jobs cannot be under on:
      job-name: ...
```

---

## ContractorScope AI caller workflow (staging)

Lives in `contractorscope ai/deploy-staging-shared.yml`. It:

1. Calls SharedWorkflows reusable workflows in order (preflight → … → traffic-shift).
2. Uses `needs:` so build runs after tests, deploy after build, migrations after build (or after deploy at 0% if migrations need the new revision), etc.
3. On failure of deploy/smoke/playwright/traffic-shift: calls reusable-rollback and notify (failure).
4. On success of traffic-shift 100%: calls notify (success).

---

## Definition of done (staging)

1. Push to `staging` (or workflow_dispatch) runs the full pipeline with reusable workflows.
2. Migrations run after image build and before (or immediately after) deploy at 0%, before any canary traffic.
3. Canary bake is 15–30 minutes; health check uses HTTP-based pass/fail threshold.
4. Playwright uses fixed 3 shards (matrix [1,2,3]).
5. Success notification is sent on full cutover; rollback notification on failure.
6. All workflow YAML has `jobs` at top level.
7. Existing `deploy-staging.yml` in the repo is unchanged; new system is opt-in via `deploy-staging-shared.yml`.
