# ── Identity ─────────────────────────────────────────────────────────────
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

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "region" {
  type    = string
  default = "us-central1"
}

# ── GitHub ────────────────────────────────────────────────────────────────
variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

# ── Services ──────────────────────────────────────────────────────────────
variable "services" {
  type = list(object({
    name                 = string
    image                = string
    min_instances        = optional(number, 0)
    max_instances        = optional(number, 10)
    cpu                  = optional(string, "1")
    memory               = optional(string, "512Mi")
    enable_public_access = optional(bool, false)
    env_vars             = optional(map(string), {})
    secret_ids           = optional(list(string), [])
  }))
  description = "List of Cloud Run services to create"
}

# ── Artifact Registry ─────────────────────────────────────────────────────
variable "artifact_registry_repo_id" {
  type = string
}

# ── Network ───────────────────────────────────────────────────────────────
variable "enable_vpc" {
  type    = bool
  default = true
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "connector_cidr" {
  type    = string
  default = "10.8.0.0/28"
}

# ── Cost ──────────────────────────────────────────────────────────────────
variable "billing_account_id" {
  type = string
}

variable "monthly_budget_usd" {
  type = number
}

variable "alert_email_addresses" {
  type = list(string)
}

# ── Monitoring ────────────────────────────────────────────────────────────
variable "slack_webhook_url" {
  type    = string
  default = ""
}

variable "error_rate_threshold_pct" {
  type    = number
  default = 1
}

variable "latency_p95_threshold_ms" {
  type    = number
  default = 2000
}

variable "runbook_base_url" {
  type        = string
  default     = ""
  description = "Base URL for runbook links in alert notifications (e.g. GitHub _XAC/monitoring/runbooks). Empty uses cloud-monitoring default."
}

# ── Secrets ───────────────────────────────────────────────────────────────
variable "secrets" {
  type = list(object({
    secret_id = string
  }))
  default     = []
  description = "Secrets to create in Secret Manager (values set manually)"
}

# ── Cloud Build ───────────────────────────────────────────────────────────
variable "cloudbuild_config" {
  type    = string
  default = "gcp_cicd/cloudbuild-ci-staging.yaml"
}
