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

variable "region" {
  type    = string
  default = "us-central1"
}

variable "service_name" {
  type = string
}

variable "image" {
  type        = string
  description = "Initial placeholder image"
}

variable "service_account_email" {
  type        = string
  description = "Cloud Run runtime service account (container identity)"
}

variable "ci_deployer_service_account_email" {
  type        = string
  description = "CI deployer SA (e.g. WIF); granted roles/run.invoker so CI can deploy and invoke"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "timeout_seconds" {
  type    = number
  default = 300
}

variable "concurrency" {
  type    = number
  default = 80
}

variable "env_vars" {
  type        = map(string)
  default     = {}
  description = "Non-secret environment variables only. No secret values."
}

variable "secret_env_vars" {
  type = list(object({
    name      = string
    secret_id = string
    version   = string
  }))
  default     = []
  description = "Secrets from Secret Manager mounted as env vars"
}

variable "enable_public_access" {
  type    = bool
  default = false
}

variable "vpc_connector" {
  type    = string
  default = ""
}

variable "vpc_egress" {
  type    = string
  default = "private-ranges-only"
}
