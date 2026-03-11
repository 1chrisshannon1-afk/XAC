locals {
  # Single Cloud Run runtime SA used by all services
  cloud_run_sa_email = google_service_account.cloud_run_runtime.email
}

# WIF + CI deployer SA
module "wif" {
  source = "../wif-github"

  project_id   = var.project_id
  project_name = var.project_name
  company      = var.company
  environment  = var.environment
  github_org   = var.github_org
  github_repo  = var.github_repo
}

# Cloud Run runtime service account (used by all Cloud Run services)
resource "google_service_account" "cloud_run_runtime" {
  project      = var.project_id
  account_id   = "cloud-run-runtime"
  display_name = "Cloud Run runtime"
}

# Artifact Registry — CI gets writer, Cloud Run SA gets reader
module "artifact_registry" {
  source = "../artifact-registry"

  project_id                 = var.project_id
  project_name               = var.project_name
  company                    = var.company
  environment                = var.environment
  region                     = var.region
  repo_id                    = var.artifact_registry_repo_id
  ci_service_account_email   = module.wif.service_account_email
  reader_members             = ["serviceAccount:${local.cloud_run_sa_email}"]
}

# Network (optional)
module "network" {
  count = var.enable_vpc ? 1 : 0

  source = "../network"

  project_id   = var.project_id
  project_name = var.project_name
  company      = var.company
  environment  = var.environment
  region       = var.region
  subnet_cidr  = var.subnet_cidr
  connector_cidr = var.connector_cidr
}

# Secrets — one per entry; grant Cloud Run SA access
module "secret" {
  for_each = toset([for s in var.secrets : s.secret_id])

  source = "../secret-manager"

  project_id        = var.project_id
  project_name      = var.project_name
  company           = var.company
  environment       = var.environment
  secret_id         = each.value
  accessor_members  = ["serviceAccount:${local.cloud_run_sa_email}", "serviceAccount:${module.wif.service_account_email}"]
}

# Cloud Run services
module "cloud_run" {
  for_each = { for s in var.services : s.name => s }

  source = "../cloud-run-service"

  project_id  = var.project_id
  project_name = var.project_name
  company     = var.company
  environment = var.environment
  region      = var.region
  service_name = each.value.name
  image       = each.value.image
  service_account_email = local.cloud_run_sa_email
  ci_deployer_service_account_email = module.wif.service_account_email
  min_instances = each.value.min_instances
  max_instances = each.value.max_instances
  cpu         = each.value.cpu
  memory      = each.value.memory
  enable_public_access = each.value.enable_public_access
  env_vars    = each.value.env_vars
  vpc_connector = var.enable_vpc && length(module.network) > 0 ? module.network[0].connector_name : ""
  secret_env_vars = [
    for sid in each.value.secret_ids : {
      name      = replace(upper(replace(sid, "-", "_")), ".", "_")
      secret_id = sid
      version   = "latest"
    }
  ]
}

# Cloud Build trigger
module "cloud_build" {
  source = "../cloud-build"

  project_id         = var.project_id
  project_name       = var.project_name
  company            = var.company
  environment        = var.environment
  region             = var.region
  github_owner       = var.github_org
  github_repo        = var.github_repo
  trigger_branch     = var.environment == "production" ? "main" : "staging"
  cloudbuild_config  = var.cloudbuild_config
  service_account_email = module.wif.service_account_email
}

# Budget alerts
module "budget" {
  source = "../budget-alerts"

  billing_account_id    = var.billing_account_id
  project_id            = var.project_id
  project_name          = var.project_name
  company               = var.company
  environment           = var.environment
  monthly_budget_usd    = var.monthly_budget_usd
  alert_email_addresses = var.alert_email_addresses
}

# Monitoring per service
module "monitoring" {
  for_each = { for s in var.services : s.name => s }

  source = "../cloud-monitoring"

  project_id                 = var.project_id
  project_name               = var.project_name
  company                    = var.company
  environment                = var.environment
  service_name               = each.value.name
  region                     = var.region
  alert_email_addresses      = var.alert_email_addresses
  slack_webhook_url         = var.slack_webhook_url
  error_rate_threshold_pct  = var.error_rate_threshold_pct
  latency_p95_threshold_ms  = var.latency_p95_threshold_ms
  min_instances             = each.value.min_instances
  runbook_base_url          = var.runbook_base_url
}
