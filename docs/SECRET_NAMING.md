# Secret Naming

**Last reviewed:** 2026-03-11

GCP Secret Manager naming convention so secrets are discoverable and consistent across environments and services.

---

## Pattern

```
{environment}-{service}-{name}
```

**Examples:**

- `staging-csa-backend-firebase-api-key`
- `production-csa-backend-django-secret-key`
- `staging-gam-backend-google-ads-credentials`

---

## Rules

- All lowercase
- Hyphens only (no underscores)
- Environment prefix always first
- Service name always second
- Never store secrets in env vars directly in Cloud Run config — always reference Secret Manager via `--set-secrets` (or equivalent) so rotation and audit stay in one place

---

## How to apply this in your project

1. Create secrets in Secret Manager using the pattern above (e.g. `staging-<project>-<service>-<secret-name>`).
2. In Cloud Run (or deploy config), reference them with `--set-secrets=ENV_VAR_NAME=secret-name:latest` and do not paste raw values into YAML or env blocks.
3. Document required secret names in your runbook or ONBOARDING.md so new environments can be provisioned consistently.
