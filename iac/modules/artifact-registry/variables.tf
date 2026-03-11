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

variable "repo_id" {
  type        = string
  description = "Repository ID, e.g. contractorscope-apps"
}

variable "reader_members" {
  type        = list(string)
  default     = []
  description = "Additional IAM members with read access (e.g. Cloud Run SA)"
}

variable "ci_service_account_email" {
  type        = string
  description = "CI deployer service account email (gets writer access)"
}
