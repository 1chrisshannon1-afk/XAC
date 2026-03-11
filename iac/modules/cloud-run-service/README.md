# cloud-run-service

Deploys a Cloud Run service with best-practice defaults. CI uses `gcloud run deploy` for ongoing deployments; this module creates the initial service and baseline. Lifecycle ignores image, env, and traffic so Terraform does not fight CI.

## Inputs

See variables.tf. Key: `service_account_email` = Cloud Run runtime SA (container identity); `ci_deployer_service_account_email` = CI/WIF SA (granted run.invoker). Use `secret_env_vars` for Secret Manager refs; `env_vars` for non-secret only.

## Outputs

| Name | Description |
|------|-------------|
| service_url | Service URI |
| service_name | Service name |
| service_id | Full resource ID |

## Example

```hcl
module "service" {
  source = "../../modules/cloud-run-service"

  project_id              = "my-project"
  project_name            = "my-project"
  company                 = "mycompany"
  environment             = "staging"
  service_name            = "my-backend"
  image                   = "us-central1-docker.pkg.dev/my-project/repo/backend:latest"
  service_account_email   = "my-runtime-sa@my-project.iam.gserviceaccount.com"
  ci_deployer_service_account_email = "ci-deployer@my-project.iam.gserviceaccount.com"
  enable_public_access    = true
  env_vars                = { APP_ENV = "staging" }
  secret_env_vars         = [{ name = "API_KEY"; secret_id = "staging-my-api-key"; version = "latest" }]
}
```
