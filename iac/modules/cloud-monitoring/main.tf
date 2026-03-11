locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "XAC"
  }
  runbook_base = var.runbook_base_url
  service_filter = "resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.service_name}\""
}

# Email notification channels
resource "google_monitoring_notification_channel" "email" {
  for_each     = toset(var.alert_email_addresses)
  project      = var.project_id
  display_name = "Email - ${each.value}"
  type         = "email"
  labels = {
    email_address = each.value
  }
}

locals {
  channel_ids = [for ch in google_monitoring_notification_channel.email : ch.id]
}

# Alert 1: High error rate (5xx)
resource "google_monitoring_alert_policy" "high_error_rate" {
  project      = var.project_id
  display_name = "${var.service_name} - High error rate"
  combiner     = "OR"
  conditions {
    display_name = "5xx rate > ${var.error_rate_threshold_pct}%"
    condition_threshold {
      filter          = "${local.service_filter} metric.type=\"run.googleapis.com/request_count\" metric.labels.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold_pct / 100
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  documentation {
    content   = "5xx error rate exceeded ${var.error_rate_threshold_pct}% over 5 minutes. **Runbook:** ${local.runbook_base}/HIGH_ERROR_RATE.md"
    mime_type = "text/markdown"
  }
  notification_channels = local.channel_ids
}

# Alert 2: High P95 latency
resource "google_monitoring_alert_policy" "high_p95_latency" {
  project      = var.project_id
  display_name = "${var.service_name} - High P95 latency"
  combiner     = "OR"
  conditions {
    display_name = "P95 latency > ${var.latency_p95_threshold_ms}ms"
    condition_threshold {
      filter          = "${local.service_filter} metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_p95_threshold_ms / 1000
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }
    }
  }
  documentation {
    content   = "P95 response time exceeded ${var.latency_p95_threshold_ms}ms. **Runbook:** ${local.runbook_base}/HIGH_LATENCY.md"
    mime_type = "text/markdown"
  }
  notification_channels = local.channel_ids
}

# Alert 3: High P99 latency
resource "google_monitoring_alert_policy" "high_p99_latency" {
  project      = var.project_id
  display_name = "${var.service_name} - High P99 latency"
  combiner     = "OR"
  conditions {
    display_name = "P99 latency > ${var.latency_p99_threshold_ms}ms"
    condition_threshold {
      filter          = "${local.service_filter} metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_p99_threshold_ms / 1000
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_99"
      }
    }
  }
  documentation {
    content   = "P99 response time exceeded ${var.latency_p99_threshold_ms}ms. **Runbook:** ${local.runbook_base}/HIGH_LATENCY.md"
    mime_type = "text/markdown"
  }
  notification_channels = local.channel_ids
}

# Alert 4: Deployment failure (Cloud Build)
resource "google_monitoring_alert_policy" "deployment_failed" {
  project      = var.project_id
  display_name = "${var.service_name} - Deployment failed"
  combiner     = "OR"
  conditions {
    display_name = "Cloud Build failure in 10m"
    condition_threshold {
      filter          = "resource.type=\"cloud_build\" metric.type=\"cloudbuild.googleapis.com/builds/count\" metric.labels.status=\"FAILURE\""
      duration        = "600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      aggregations {
        alignment_period   = "600s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }
  documentation {
    content   = "A Cloud Build job failed. **Runbook:** ${local.runbook_base}/DEPLOYMENT_FAILED.md"
    mime_type = "text/markdown"
  }
  notification_channels = local.channel_ids
}

# Alert 5: Instance count anomaly (current count above threshold; full 7-day rolling avg requires MQL in Console)
resource "google_monitoring_alert_policy" "instance_anomaly" {
  project      = var.project_id
  display_name = "${var.service_name} - Instance count anomaly"
  combiner     = "OR"
  conditions {
    display_name = "Instance count > ${var.instance_anomaly_threshold_absolute}"
    condition_threshold {
      filter          = "${local.service_filter} metric.type=\"run.googleapis.com/container/instance_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.instance_anomaly_threshold_absolute
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  documentation {
    content   = "Instance count is unusually high. For 7-day rolling average comparison use MQL in Console. **Runbook:** ${local.runbook_base}/INSTANCE_ANOMALY.md"
    mime_type = "text/markdown"
  }
  notification_channels = local.channel_ids
}

# Alert 5: No healthy instances (only if min_instances > 0)
resource "google_monitoring_alert_policy" "no_healthy_instances" {
  count = var.min_instances > 0 ? 1 : 0

  project      = var.project_id
  display_name = "${var.service_name} - No healthy instances"
  combiner     = "OR"
  conditions {
    display_name = "Instance count 0 for > 2 minutes"
    condition_threshold {
      filter          = "${local.service_filter} metric.type=\"run.googleapis.com/container/instance_count\""
      duration        = "120s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  documentation {
    content   = "No instances running despite min_instances > 0. **Runbook:** ${local.runbook_base}/HIGH_ERROR_RATE.md"
    mime_type = "text/markdown"
  }
  notification_channels = local.channel_ids
}

# Dashboard (path from _XAC/iac/modules/cloud-monitoring to _XAC/monitoring/dashboards)
resource "google_monitoring_dashboard" "main" {
  project        = var.project_id
  dashboard_json = templatefile("${path.module}/../../../monitoring/dashboards/cloud-run-baseline.json", {
    service_name = var.service_name
    project_id   = var.project_id
    region       = var.region
  })
}
