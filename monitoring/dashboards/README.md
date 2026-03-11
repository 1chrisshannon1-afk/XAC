# Dashboards

Templates used by the `cloud-monitoring` Terraform module.

## cloud-run-baseline.json

Cloud Monitoring dashboard for a Cloud Run service. Template variables (replaced by `templatefile()`):

- `${service_name}` — Cloud Run service name
- `${project_id}` — GCP project ID
- `${region}` — Region

Widgets: request rate, error rate %, P50/P95/P99 latency, instance count, CPU utilization, memory utilization, build history.
