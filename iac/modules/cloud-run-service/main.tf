locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "IAC"
  }

  secret_env = [
    for s in var.secret_env_vars : {
      name = s.name
      secret_key_ref = {
        secret  = "projects/${var.project_id}/secrets/${s.secret_id}"
        version = s.version
      }
    }
  ]

  plain_env = [
    for k, v in var.env_vars : {
      name  = k
      value = v
    }
  ]
}

resource "google_cloud_run_v2_service" "main" {
  project  = var.project_id
  location = var.region
  name     = var.service_name
  labels   = local.standard_labels

  template {
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
    timeout         = "${var.timeout_seconds}s"
    service_account = var.service_account_email
    max_instance_request_concurrency = var.concurrency

    vpc_access {
      connector = var.vpc_connector != "" ? var.vpc_connector : null
      egress    = var.vpc_connector != "" ? var.vpc_egress : null
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      dynamic "env" {
        for_each = local.plain_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
      dynamic "env" {
        for_each = local.secret_env
        content {
          name = env.value.name
          value_source {
            secret_key_ref {
              secret  = env.value.secret_key_ref.secret
              version = env.value.secret_key_ref.version
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 3
      }
      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 15
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].containers[0].env,
      traffic,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "ci_invoker" {
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.ci_deployer_service_account_email}"
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.enable_public_access ? 1 : 0

  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
