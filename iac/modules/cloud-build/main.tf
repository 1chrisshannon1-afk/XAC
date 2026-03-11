locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "IAC"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  project = var.project_id
  service = each.value
}

resource "google_cloudbuild_trigger" "main" {
  project  = var.project_id
  name     = "deploy-${var.trigger_branch}"
  location = var.region
  labels   = local.standard_labels

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^${var.trigger_branch}$"
    }
  }

  filename = var.cloudbuild_config
}

# Cloud Build uses a default service account; grant it the needed roles.
# The default SA is projects/PROJECT_NUMBER/serviceAccounts/PROJECT_NUMBER@cloudbuild.gserviceaccount.com
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
