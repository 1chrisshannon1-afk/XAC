locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "XAC"
  }
}

# Email notification channels for budget alerts
resource "google_monitoring_notification_channel" "email" {
  for_each     = toset(var.alert_email_addresses)
  project      = var.project_id
  display_name = "Budget alert - ${each.value}"
  type         = "email"
  labels = {
    email_address = each.value
  }
}

# Optional: create Pub/Sub topic for production if not provided
resource "google_pubsub_topic" "budget_alerts" {
  count = var.alert_pubsub_topic == "" && var.environment == "production" ? 1 : 0

  project = var.project_id
  name    = "billing-budget-alerts"
}

resource "google_billing_budget" "main" {
  billing_account = var.billing_account_id
  display_name    = "Budget - ${var.project_name} (${var.environment})"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.monthly_budget_usd))
      nanos         = 0
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.2
  }

  all_updates_rule {
    monitoring_notification_channels = [for ch in google_monitoring_notification_channel.email : ch.id]
    disable_default_iam_recipients   = var.environment == "production"
  }
}
