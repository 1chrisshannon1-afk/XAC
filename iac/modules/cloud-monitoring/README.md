# cloud-monitoring

Creates baseline alert policies and notification channels for a Cloud Run service. Dashboard from `terraform/dashboards/cloud-run-baseline.json`.

## Inputs

See variables.tf. Key: `service_name`, `alert_email_addresses`, `error_rate_threshold_pct`, `latency_p95_threshold_ms`, `runbook_base_url`.

## Outputs

| Name | Description |
|------|-------------|
| alert_policy_ids | List of alert policy IDs |
| notification_channel_ids | List of notification channel IDs |
| dashboard_name | Dashboard resource ID |

## Alerts

1. High error rate (5xx) — CRITICAL, runbook HIGH_ERROR_RATE.md  
2. High P95 latency — WARNING, runbook HIGH_LATENCY.md  
3. High P99 latency — CRITICAL, runbook HIGH_LATENCY.md  
4. Deployment failed (Cloud Build) — WARNING, runbook DEPLOYMENT_FAILED.md  
5. No healthy instances — CRITICAL (only if min_instances > 0)

## Example

```hcl
module "monitoring" {
  source = "../../modules/cloud-monitoring"

  project_id                 = "my-project"
  project_name               = "my-project"
  company                    = "mycompany"
  environment                = "staging"
  service_name               = "my-backend"
  alert_email_addresses      = ["devops@example.com"]
  error_rate_threshold_pct   = 1
  latency_p95_threshold_ms   = 2000
  min_instances              = 0
}
```
