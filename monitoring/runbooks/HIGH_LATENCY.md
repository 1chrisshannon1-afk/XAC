# Runbook: High Latency

**Last reviewed:** 2026-03-11  
**Severity:** WARNING (P95) / CRITICAL (P99)

## What this alert means

Response time has exceeded the threshold (e.g. P95 > 2s or P99 > 5s) over a 5-minute window. Users may experience slow pages or timeouts.

## Immediate actions (first 5 minutes)

1. Check if a single endpoint is slow or all traffic — use Cloud Trace or Logging to see which paths have high latency.
2. Check recent deployments — a new revision might have introduced a slow query or blocking call.
3. Check database and cache latency in the same project.

## Investigation steps

- **Cloud Trace:** In GCP Console, go to **Trace** and filter by the Cloud Run service; identify the slowest traces and their spans.
- **Logging — slow requests:**
  ```bash
  gcloud logging read \
    'resource.type="cloud_run_revision" resource.labels.service_name="SERVICE_NAME" jsonPayload.latency_ms>2000' \
    --project=PROJECT_ID \
    --limit=20 \
    --format=json \
    --freshness=1h
  ```
- Check **Cloud Run → Metrics** for CPU and memory utilization; high utilization can cause queuing and higher latency.

## Common causes and fixes

| Cause | How to confirm | Fix |
|-------|----------------|-----|
| Slow database query | Trace shows long DB span | Optimize query, add index, or cache. |
| Cold start | Latency spike after idle period | Consider min_instances=1 for critical services. |
| Downstream API slow | Trace shows long HTTP call to external API | Add timeout/circuit breaker; consider caching. |
| CPU/memory saturation | High utilization in metrics | Increase CPU/memory or scale out. |

## Escalation

If latency remains high after 30 minutes or affects a critical path, escalate to the service owner or platform team.

## How to silence this alert

Only for known false positives (e.g. expected slow batch job). Document and prefer adjusting the threshold in Terraform over long-term silence.
