# DECISIONS — Architecture Decision Records

**Last reviewed:** 2026-03-11

Why key choices were made. Each entry is an ADR.

---

## ADR-001: mypy is non-blocking in both local and CI

**Date:** 2026-03-11  
**Status:** Accepted

**Context:** mypy was blocking in local_ci.ps1 but continue-on-error in CI, leading to inconsistent behavior.

**Decision:** mypy is non-blocking in both environments.

**Reason:** Consistency. Local CI must match CI behavior exactly. mypy is a quality tool, not a gate. Blocking on type errors would discourage incremental adoption.

**Consequences:** Type errors do not block deploys. Teams must review mypy output separately and fix over time.

---

## ADR-002: SHA pinning for all actions

**Date:** 2026-03-11  
**Status:** Accepted

**Context:** Using `@v1` or `@main` for actions can break CI when action maintainers change behavior.

**Decision:** All reusable workflows and composite actions use SHA-pinned references for every third-party action.

**Reason:** Reproducibility and stability. CI behavior should not change without an explicit update (e.g. Dependabot PR or manual SHA bump).

**Consequences:** Someone must periodically update SHAs (e.g. via Dependabot); workflow files carry a comment block listing current SHAs.

---

## ADR-003: Canary bake time default 20 minutes

**Date:** 2026-03-11  
**Status:** Accepted

**Context:** Production deploy needs a canary phase to detect bad releases before full traffic. Too short a bake misses statistically meaningful error rate changes.

**Decision:** Default `canary-bake-minutes` is 20. Minimum recommended 15–30 minutes.

**Reason:** 5 minutes is insufficient for production. Error rate and latency need enough samples to be meaningful; 15–30 minutes is a reasonable minimum. Default 20 is documented in workflow comments.

**Consequences:** Production deploys take longer; rollback is still automatic if canary health check fails.

---

## ADR-004: Deploy new revision at 0% traffic, then shift

**Date:** 2026-03-11  
**Status:** Accepted

**Context:** Deploying with immediate traffic can blast a broken revision to all users.

**Decision:** Production deploy: create new revision with 0% traffic, run smoke/Playwright against the canary URL, then shift a small percentage (canary), bake, then cut over to 100%.

**Reason:** Validates the new revision before any user traffic. Rollback is simply shifting traffic back; no need to redeploy.

**Consequences:** Slightly more steps in the workflow; requires a health check script and traffic-shift workflow.

---

## ADR-005: Shared base image and Dockerfile template

**Date:** 2026-03-11  
**Status:** Accepted

**Context:** Each project could use ad-hoc base images and Dockerfile patterns, making security and maintenance harder.

**Decision:** Provide `templates/docker/Dockerfile.python` and `Dockerfile.node` as starting points. Base image pinned by digest; update quarterly.

**Reason:** Consistency, security (known base), and a single place to document health check and non-root user patterns per HEALTH_CHECK_CONTRACT.

**Consequences:** Projects copy and adapt; they are not required to stay in sync with template changes after initial copy.

---

## ADR-006: Conventional Commits adoption

**Date:** 2026-03-11  
**Status:** Accepted

**Context:** Unstructured commit messages make changelog and automation harder.

**Decision:** Document and recommend Conventional Commits (`<type>(<scope>): <description>`) in COMMIT_CONVENTIONS.md. Pre-commit or PR checks can enforce.

**Reason:** Enables future automatic changelog generation and semantic versioning; improves consistency across repos.

**Consequences:** Contributors must follow the format; projects may add a small validator.

---

## How to apply this in your project

When you make a significant architectural choice affecting XAC or consuming projects, add an ADR here with context, decision, reason, and consequences. Bump the "Last reviewed" date when touching this file.
