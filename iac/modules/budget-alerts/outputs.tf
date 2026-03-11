output "budget_name" {
  value = google_billing_budget.main.display_name
}

output "pubsub_topic_name" {
  value = var.alert_pubsub_topic != "" ? var.alert_pubsub_topic : (length(google_pubsub_topic.budget_alerts) > 0 ? google_pubsub_topic.budget_alerts[0].name : "")
}
