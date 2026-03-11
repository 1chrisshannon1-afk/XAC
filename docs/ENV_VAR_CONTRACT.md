# Environment Variable Contract

**Last reviewed:** 2026-03-11

Standard environment variables every service must support so local, test, staging, and production behave consistently.

| Variable | Values | Purpose |
|----------|--------|---------|
| `APP_ENV` | `local`, `test`, `staging`, `production` | Environment name |
| `DEV_MODE` | `true` / `false` | Enables dev-only features |
| `SKIP_AUTH` | `true` / `false` | Bypasses auth for testing |
| `GOOGLE_CLOUD_PROJECT` | project ID | GCP project |
| `FIRESTORE_EMULATOR_HOST` | `host:port` | Points to local emulator |
| `REDIS_URL` | `redis://host:port/db` | Redis connection |

Project-specific variables must be prefixed with the project abbreviation (e.g. `ACME_` for Acme Corp) to avoid collisions when multiple projects run in the same environment.

---

## How to apply this in your project

1. Read these variables at startup and document any project-specific prefixes in your README or runbook.
2. Use `APP_ENV` to gate feature flags, logging level, and external service endpoints.
3. Use `SKIP_AUTH` only in test/local; never enable in staging or production.
4. When adding new env vars, prefer the project prefix (e.g. `ACME_*`) for anything not shared across all services.
