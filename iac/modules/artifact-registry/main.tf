locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "XAC"
  }
}

resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id  = var.repo_id
  description   = "Docker repository for ${var.project_name}"
  format        = "DOCKER"
  labels        = local.standard_labels
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  project    = google_artifact_registry_repository.main.project
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.ci_service_account_email}"
}

resource "google_artifact_registry_repository_iam_member" "readers" {
  for_each   = toset(var.reader_members)
  project    = google_artifact_registry_repository.main.project
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}
