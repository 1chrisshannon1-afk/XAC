variable "billing_account_id" {
  type = string
}

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

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly budget in USD. Alert fires at 50%, 90%, 100%, 120%."
}

variable "alert_email_addresses" {
  type        = list(string)
  description = "Email addresses to notify when budget thresholds are crossed"
}

variable "alert_pubsub_topic" {
  type        = string
  default     = ""
  description = "Optional Pub/Sub topic for programmatic budget alerts"
}
