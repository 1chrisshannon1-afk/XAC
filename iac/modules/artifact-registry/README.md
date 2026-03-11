# artifact-registry

Creates a Docker repository in Artifact Registry for storing built images.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| project_id | string | - | GCP project ID |
| project_name | string | - | Project name (for labels) |
| company | string | - | Company name (for labels) |
| environment | string | - | staging or production |
| region | string | "us-central1" | Region for the repository |
| repo_id | string | - | Repository ID (e.g. contractorscope-apps) |
| reader_members | list(string) | [] | IAM members with read access |
| ci_service_account_email | string | - | CI deployer SA (gets writer access) |

## Outputs

| Name | Description |
|------|-------------|
| repository_id | Full repository resource ID |
| repository_url | Base URL for pushing images (region-docker.pkg.dev/...) |

## Example

```hcl
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id                 = "my-project"
  project_name               = "my-project"
  company                    = "mycompany"
  environment                = "staging"
  repo_id                    = "my-apps"
  ci_service_account_email   = module.wif.service_account_email
  reader_members             = ["serviceAccount:cloud-run-sa@my-project.iam.gserviceaccount.com"]
}
```
