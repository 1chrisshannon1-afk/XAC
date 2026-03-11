# cloud-build

Creates Cloud Build trigger and grants IAM so Cloud Build can push images and deploy to Cloud Run.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| project_id | string | - | GCP project ID |
| project_name | string | - | Project name (for labels) |
| company | string | - | Company name (for labels) |
| environment | string | - | staging or production |
| region | string | "us-central1" | Region for Cloud Build |
| github_owner | string | - | GitHub org or user |
| github_repo | string | - | Repo name |
| trigger_branch | string | "staging" | Branch to trigger on |
| cloudbuild_config | string | - | Path to cloudbuild yaml in repo |
| service_account_email | string | - | (Reserved for future use) |

## Outputs

| Name | Description |
|------|-------------|
| trigger_id | Cloud Build trigger ID |
| trigger_name | Trigger name |

## Example

```hcl
module "cloud_build" {
  source = "../../modules/cloud-build"

  project_id         = "my-project"
  project_name       = "my-project"
  company            = "mycompany"
  environment        = "staging"
  github_owner       = "myorg"
  github_repo        = "my-repo"
  cloudbuild_config  = "gcp_cicd/cloudbuild-ci-staging.yaml"
}
```
