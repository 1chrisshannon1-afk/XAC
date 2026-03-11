# Runbooks

**Last reviewed:** 2026-03-11

Runbooks linked from Terraform-managed alert policies. Each alert policy includes a link to the relevant runbook so responders know what to do when an alert fires.

## Index

| Runbook | Alert(s) | Severity |
|---------|----------|----------|
| [HIGH_ERROR_RATE.md](HIGH_ERROR_RATE.md) | High 5xx error rate, No healthy instances | CRITICAL |
| [HIGH_LATENCY.md](HIGH_LATENCY.md) | High P95/P99 latency | WARNING / CRITICAL |
| [DEPLOYMENT_FAILED.md](DEPLOYMENT_FAILED.md) | Cloud Build failure | WARNING |
| [COST_SPIKE.md](COST_SPIKE.md) | Budget threshold exceeded | WARNING |
| [INSTANCE_ANOMALY.md](INSTANCE_ANOMALY.md) | Instance count >> 7-day average | WARNING |

## Structure

Each runbook includes:

- **What this alert means** — plain-language description
- **Immediate actions** — first 5 minutes
- **Investigation steps** — gcloud commands and Console navigation
- **Common causes and fixes** — table of cause, how to confirm, and fix
- **Escalation** — when to page or hand off
- **How to silence** — only when appropriate; document reason

Keep runbooks up to date when you change alert thresholds or add new services. Update the "Last reviewed" date when you edit.
