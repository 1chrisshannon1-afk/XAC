# Runbook: High Error Rate

**Last reviewed:** 2026-03-11  
**Severity:** CRITICAL

## What this alert means

The Cloud Run service is returning 5xx errors at a rate above the threshold (e.g. 1%) over a 5-minute window. Users may be seeing errors or timeouts.

## Immediate actions (first 5 minutes)

1. Open Cloud Logging and filter for the service and `severity>=ERROR`.
2. Check whether a new revision was deployed in the last 15 minutes — if yes, consider rolling back.
3. If the service uses a database or cache, check their health and latency.

## Investigation steps

- **Cloud Logging — recent errors:**
  ```bash
  gcloud logging read \
    'resource.type="cloud_run_revision" resource.labels.service_name="SERVICE_NAME" severity>=ERROR' \
    --project=PROJECT_ID \
    --limit=50 \
    --format="table(timestamp,textPayload)" \
    --freshness=1h
  ```
- **Recent revisions:**
  ```bash
  gcloud run revisions list \
    --service=SERVICE_NAME \
    --region=REGION \
    --project=PROJECT_ID \
    --limit=10
  ```
- In the Cloud Console, open **Logging → Logs Explorer** and filter by the service; look for stack traces and repeated error messages.

## Common causes and fixes

| Cause | How to confirm | Fix |
|-------|----------------|-----|
| Bad deploy | New revision in last 15 min, errors started after deploy | Roll back to previous revision (see below). |
| Dependency outage | Errors mention connection timeout, 503 from downstream | Wait or fail gracefully; check status of Firestore, Redis, external APIs. |
| Connection pool exhausted | Errors like "too many connections" or pool timeout | Increase pool size or scale up; fix connection leaks. |
| Unhandled exception | Same exception in many logs | Fix the bug and deploy; roll back in the meantime. |

## Rollback (traffic to previous revision)

```bash
# List revisions and note the previous stable revision name
gcloud run revisions list --service=SERVICE_NAME --region=REGION --project=PROJECT_ID

# Shift 100% traffic to the previous revision
gcloud run services update-traffic SERVICE_NAME \
  --to-revisions=PREVIOUS_REVISION=100 \
  --region=REGION \
  --project=PROJECT_ID
```

## Escalation

If rollback does not reduce errors, or the cause is not obvious within 15 minutes, escalate to the on-call engineer or platform team. Page if the error rate is above 10% or affecting paying customers.

## How to silence this alert

Only if you have confirmed a false positive (e.g. a known deployment that triggers a brief spike). Document the reason in the alert and in your runbook log. Prefer muting the policy temporarily over silencing indefinitely.
