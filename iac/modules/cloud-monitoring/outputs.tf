output "alert_policy_ids" {
  value = concat(
    [google_monitoring_alert_policy.high_error_rate.id],
    [google_monitoring_alert_policy.high_p95_latency.id],
    [google_monitoring_alert_policy.high_p99_latency.id],
    [google_monitoring_alert_policy.deployment_failed.id],
    [google_monitoring_alert_policy.instance_anomaly.id],
    var.min_instances > 0 ? [google_monitoring_alert_policy.no_healthy_instances[0].id] : []
  )
}

output "notification_channel_ids" {
  value = local.channel_ids
}

output "dashboard_name" {
  value = google_monitoring_dashboard.main.id
}
