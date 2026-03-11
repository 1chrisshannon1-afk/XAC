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

variable "service_name" {
  type        = string
  description = "Cloud Run service name"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "error_rate_threshold_pct" {
  type    = number
  default = 1
}

variable "latency_p95_threshold_ms" {
  type    = number
  default = 2000
}

variable "latency_p99_threshold_ms" {
  type    = number
  default = 5000
}

variable "instance_anomaly_multiplier" {
  type        = number
  default     = 3
  description = "Alert if instance count is this many times the 7-day average (used in docs; threshold below is absolute)"
}

variable "instance_anomaly_threshold_absolute" {
  type        = number
  default     = 20
  description = "Alert when instance count exceeds this (simplified; for 7-day rolling use MQL in Console)"
}

variable "alert_email_addresses" {
  type = list(string)
}

variable "slack_webhook_url" {
  type        = string
  default     = ""
  description = "Optional; reserved for future Slack notification channel integration. When set, a notification channel can be created linking to this webhook."
}

variable "min_instances" {
  type    = number
  default = 0
  description = "Cloud Run min instances; used for 'no healthy instances' alert"
}

variable "runbook_base_url" {
  type    = string
  default = ""
  description = "Base URL for runbook links in alert notifications"
}
