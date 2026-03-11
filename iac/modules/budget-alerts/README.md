# budget-alerts

Creates GCP budget alerts so cost spikes are caught immediately. Budget is scoped to the specific project_id.

## Inputs

| Name | Type | Description |
|------|------|-------------|
| billing_account_id | string | Billing account ID |
| project_id | string | GCP project ID |
| project_name | string | Project name (for labels) |
| company | string | Company name (for labels) |
| environment | string | staging or production |
| monthly_budget_usd | number | Monthly budget in USD; alerts at 50%, 90%, 100%, 120% |
| alert_email_addresses | list(string) | Emails to notify |
| alert_pubsub_topic | string | Optional Pub/Sub topic for programmatic alerts |

## Outputs

| Name | Description |
|------|-------------|
| budget_name | Budget display name |
| pubsub_topic_name | Pub/Sub topic name (if created or provided) |

## Example

```hcl
module "budget" {
  source = "../../modules/budget-alerts"

  billing_account_id    = "012345-6789AB-CDEF01"
  project_id            = "my-project"
  project_name          = "my-project"
  company               = "mycompany"
  environment           = "staging"
  monthly_budget_usd    = 200
  alert_email_addresses = ["devops@example.com"]
}
```
