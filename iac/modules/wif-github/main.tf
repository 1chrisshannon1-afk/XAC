locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "XAC"
  }
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Workload Identity Pool for GitHub Actions OIDC"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}'"
}

resource "google_service_account" "ci_deployer" {
  project      = var.project_id
  account_id   = "ci-deployer"
  display_name = "CI Deployer (GitHub Actions)"
}

resource "google_service_account_iam_binding" "wif_binding" {
  service_account_id = google_service_account.ci_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
  ]
}

resource "google_project_iam_member" "ci_roles" {
  for_each = toset(var.service_account_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.ci_deployer.email}"
}
