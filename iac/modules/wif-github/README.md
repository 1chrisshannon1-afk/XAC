# wif-github

Sets up Workload Identity Federation so GitHub Actions can authenticate to GCP without service account keys. This must exist before any CI/CD pipeline can run.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| project_id | string | - | GCP project ID |
| project_name | string | - | Project name (for labels) |
| company | string | - | Company name (for labels) |
| environment | string | - | staging or production |
| github_org | string | - | GitHub org or username |
| github_repo | string | - | Repo name without org prefix |
| pool_id | string | "github" | WIF pool ID |
| provider_id | string | "github" | WIF provider ID |
| service_account_roles | list(string) | [run.admin, artifactregistry.writer, ...] | IAM roles for CI SA |

## Outputs

| Name | Description |
|------|-------------|
| wif_provider | Full WIF provider name (use in GitHub var WIF_PROVIDER) |
| service_account_email | CI deployer SA email (use in GitHub var WIF_SERVICE_ACCOUNT) |
| pool_name | WIF pool name |

## Example

```hcl
module "wif" {
  source = "../../modules/wif-github"

  project_id   = "my-project"
  project_name = "my-project"
  company      = "mycompany"
  environment  = "staging"
  github_org    = "myorg"
  github_repo   = "my-repo"
}
```
