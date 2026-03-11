variable "project_id" {
  type    = string
  default = "{{GCP_PROJECT}}"
}

variable "region" {
  type    = string
  default = "{{GCP_REGION}}"
}

variable "billing_account_id" {
  type = string
}

variable "alert_email_addresses" {
  type = list(string)
}

variable "slack_webhook_url" {
  type    = string
  default = ""
}

variable "runbook_base_url" {
  type        = string
  default     = "https://github.com/{{GITHUB_ORG}}/{{GITHUB_REPO}}/blob/main/_XAC_Base/monitoring/runbooks"
  description = "Base URL for runbook links in alerts."
}
