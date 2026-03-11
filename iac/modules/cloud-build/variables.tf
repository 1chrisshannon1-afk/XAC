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

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "trigger_branch" {
  type    = string
  default = "staging"
}

variable "cloudbuild_config" {
  type        = string
  description = "Path to cloudbuild yaml in repo"
}

variable "service_account_email" {
  type        = string
  description = "CI deployer SA (reserved for future IAM; Cloud Build uses default SA today)"
}
