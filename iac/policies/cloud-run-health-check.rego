package terraform

# Deny any Cloud Run service that does not define a health check
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "google_cloud_run_v2_service"
  resource.change.actions[_] == "create"

  container := resource.change.after.template[0].containers[0]
  not container.liveness_probe
  not container.startup_probe

  msg := sprintf(
    "Cloud Run service '%s' must define a liveness_probe or startup_probe. See docs/HEALTH_CHECK_CONTRACT.md",
    [resource.address]
  )
}
