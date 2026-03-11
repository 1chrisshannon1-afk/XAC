variable "project_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "company" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_org" {
  type        = string
  description = "GitHub org or username"
}

variable "github_repo" {
  type        = string
  description = "Repo name without org prefix"
}

variable "pool_id" {
  type    = string
  default = "github"
}

variable "provider_id" {
  type    = string
  default = "github"
}

variable "service_account_roles" {
  type = list(string)
  default = [
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/cloudbuild.builds.editor",
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountUser",
    "roles/monitoring.metricWriter",
  ]
}
