locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "IAC"
  }
}

resource "google_secret_manager_secret" "main" {
  project   = var.project_id
  secret_id = var.secret_id
  labels    = local.standard_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "accessors" {
  for_each  = toset(var.accessor_members)
  project   = var.project_id
  secret_id = google_secret_manager_secret.main.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}
