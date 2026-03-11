# secret-manager

Creates a Secret Manager secret with correct IAM. Does NOT set the secret value — that is done manually or by the application. Follows naming from docs/SECRET_NAMING.md.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| project_id | string | - | GCP project ID |
| project_name | string | - | Project name (for labels) |
| company | string | - | Company name (for labels) |
| environment | string | - | staging or production |
| secret_id | string | - | Secret name (e.g. staging-csa-backend-firebase-api-key) |
| accessor_members | list(string) | - | IAM members granted secretAccessor |
| automatic_replication | bool | true | Use auto replication |

## Outputs

| Name | Description |
|------|-------------|
| secret_id | Secret ID |
| secret_name | Full secret resource name |

## Example

```hcl
module "secret" {
  source = "../../modules/secret-manager"

  project_id        = "my-project"
  project_name      = "my-project"
  company           = "mycompany"
  environment       = "staging"
  secret_id         = "staging-my-backend-api-key"
  accessor_members  = ["serviceAccount:my-sa@my-project.iam.gserviceaccount.com"]
}
```
