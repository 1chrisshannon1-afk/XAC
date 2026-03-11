# Runbook: Cost Spike

**Last reviewed:** 2026-03-11  
**Severity:** WARNING

## What this alert means

GCP spend has exceeded the budget threshold (50%, 90%, 100%, or 120%) for the project. This may indicate runaway usage or unexpectedly high traffic.

## Immediate actions (first 5 minutes)

1. Open **Billing → Reports** and filter by the project; identify which service or SKU is driving cost (e.g. Cloud Run, Cloud Build, Artifact Registry).
2. Check for a recent traffic spike or a large number of Cloud Build runs.
3. If you see a clear culprit (e.g. one service with many revisions or a build loop), consider stopping or scaling down.

## Investigation steps

- **Cost breakdown by service (Console):** Billing → Reports → filter by project → group by "Service".
- **Recent Cloud Build usage:**
  ```bash
  gcloud builds list --project=PROJECT_ID --limit=50
  ```
- **Cloud Run revisions (possible bloat):**
  ```bash
  gcloud run revisions list --service=SERVICE_NAME --region=REGION --project=PROJECT_ID
  ```
- **Artifact Registry size:** In Console, check Artifact Registry → select repo → see storage usage.

## Common causes and fixes

| Cause | How to confirm | Fix |
|-------|----------------|-----|
| Runaway Cloud Build | Many builds in a short time; trigger on every push to a busy branch | Adjust trigger (e.g. only staging/main); add concurrency limit. |
| Traffic spike | Cloud Run request count and CPU much higher than usual | If legitimate, increase budget; if attack, add rate limiting/WAF. |
| Forgotten test resources | VMs, disks, or other resources left running | Delete or shut down test resources; add labels for cleanup. |
| High max instances | Cloud Run scaled to max and stayed there | Review autoscaling settings; consider lowering max_instances. |
| Artifact Registry | Large number or size of images | Set lifecycle policy to delete old images; clean up unused repos. |

## Cost reduction quick wins

- Delete old Cloud Run revisions: keep last N and delete the rest (via script or Console).
- Set Artifact Registry lifecycle policy: delete untagged images older than 30 days.
- Review Cloud Build trigger: avoid building on every branch; use path filters.
- Ensure Cloud Run min_instances=0 for non-critical services to allow scale-to-zero.

## Escalation

If the spike is large (e.g. >120% of budget) or the cause is unclear, escalate to the billing owner or platform team. Consider temporarily disabling non-essential triggers or scaling down until the cause is fixed.

## How to silence this alert

Do not silence cost alerts. Adjust the budget or thresholds in Terraform if the new level of spend is expected and approved.
