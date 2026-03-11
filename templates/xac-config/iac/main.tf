module "staging" {
  source = "../../_XAC_Base/iac/modules/project-baseline"

  project_id   = var.project_id
  project_name = "{{GCP_PROJECT}}"
  company      = "{{PROJECT_LABEL}}"
  environment  = "staging"
  region       = var.region

  github_org  = "{{GITHUB_ORG}}"
  github_repo = "{{GITHUB_REPO}}"

  services = [
    {
      name                 = "{{PROJECT_LABEL}}-backend-staging"
      image                = "{{GCP_REGION}}-docker.pkg.dev/${var.project_id}/{{PROJECT_LABEL}}-apps/backend:latest"
      min_instances        = 0
      max_instances        = 10
      cpu                  = "1"
      memory               = "1Gi"
      enable_public_access = true
      env_vars = {
        APP_ENV    = "staging"
        REGION     = var.region
        PROJECT_ID = var.project_id
      }
      secret_ids = []
    }
  ]

  artifact_registry_repo_id = "{{PROJECT_LABEL}}-apps"

  enable_vpc     = true
  subnet_cidr    = "10.0.0.0/24"
  connector_cidr = "10.8.0.0/28"

  billing_account_id    = var.billing_account_id
  monthly_budget_usd    = 200
  alert_email_addresses = var.alert_email_addresses

  slack_webhook_url = var.slack_webhook_url
  runbook_base_url  = var.runbook_base_url

  secrets = []

  cloudbuild_config = "{{XAC_CONFIG_NAME}}/gcp_cicd/cloudbuild-ci-staging.yaml"
}
