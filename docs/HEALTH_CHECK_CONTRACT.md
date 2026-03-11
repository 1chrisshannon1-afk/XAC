# Health Check Contract

**Last reviewed:** 2026-03-11

Every service must implement two endpoints so smoke tests, load balancers, and canary health monitoring can rely on a consistent contract.

---

## `GET /health`

**Purpose:** Liveness — the process is alive and can respond.

- **HTTP status:** 200 when the process is alive
- **Response body (JSON):**
  ```json
  {
    "status": "ok",
    "version": "abc1234",
    "timestamp": "2026-03-11T12:00:00Z"
  }
  ```
- **Latency:** Must respond in &lt; 500ms
- **Dependencies:** Must **NOT** check external dependencies (databases, caches). This is a liveness check only.

---

## `GET /health/ready`

**Purpose:** Readiness — the service is ready to accept traffic.

- **HTTP status:** 200 when ready, 503 when not ready
- **Response body (JSON):**
  ```json
  {
    "status": "ready",
    "checks": {
      "database": "ok",
      "cache": "ok",
      "emulator": "ok"
    }
  }
  ```
- **Dependencies:** May check external dependencies (DB, cache, etc.). Used by smoke tests and canary health monitoring.

The smoke test workflow checks for these exact fields and status values. If your service uses different field names, the smoke tests will fail.

---

## How to apply this in your project

1. Add a `/health` route that returns 200 and the JSON above with `status: "ok"`, your app version, and a timestamp. Do not call Firestore, Redis, or any external service in this handler.
2. Add a `/health/ready` route that returns 200 and the JSON above when all required backends are reachable; return 503 and an appropriate body when any check fails.
3. Ensure both endpoints respond quickly; avoid long timeouts on dependency checks in `/health/ready` (e.g. 2–3 second timeout per check).
4. Document the URLs in your runbook; they are used by Cloud Run, smoke workflows, and canary health checks.
