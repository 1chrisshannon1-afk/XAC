# Runbook: Instance Count Anomaly

**Last reviewed:** 2026-03-11  
**Severity:** WARNING

## What this alert means

The number of Cloud Run instances is significantly above the 7-day average (e.g. more than 3x). This can indicate a legitimate traffic spike or a problem (e.g. retry storm, load test left on, or attack).

## Immediate actions (first 5 minutes)

1. Check Cloud Run metrics for request count and latency — is traffic actually high?
2. Check request sources in Logging (e.g. by user-agent or IP) to see if it is one client or many.
3. If you see a single IP or user-agent generating most of the traffic, consider whether it is expected (e.g. load test) or not (e.g. bot).

## Investigation steps

- **Request count and latency (Console):** Cloud Run → select service → Metrics tab.
- **Logging — request distribution:**
  ```bash
  gcloud logging read \
    'resource.type="cloud_run_revision" resource.labels.service_name="SERVICE_NAME"' \
    --project=PROJECT_ID \
    --limit=100 \
    --format="table(timestamp,httpRequest.requestUrl,httpRequest.userAgent)" \
    --freshness=30m
  ```
- Compare instance count and request rate to the same time yesterday or last week (e.g. in Monitoring dashboards).

## Common causes and fixes

| Cause | How to confirm | Fix |
|-------|----------------|-----|
| Legitimate traffic spike | Traffic and latency look normal; marketing event or product launch | No action; consider raising the anomaly threshold if this becomes common. |
| DDoS or abuse | Many requests from few IPs or strange user-agents | Add rate limiting, WAF, or block abusive IPs; use Cloud Armor if needed. |
| Retry storm from client | One client or service repeatedly failing and retrying | Fix the downstream bug or add backoff; add circuit breaker. |
| Load test left running | Traffic from a known load-test tool or environment | Stop the load test; add tags or headers to exclude test traffic from triggering alerts. |

## Escalation

If the traffic looks malicious or you cannot identify the source, escalate to security or platform. If instances are maxed out and latency is high, treat as a capacity/incident issue.

## How to silence this alert

Only if you have confirmed a known event (e.g. planned load test). Document the event and mute for a short window; do not silence indefinitely.
