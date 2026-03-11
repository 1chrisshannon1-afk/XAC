package terraform

# Deny any Cloud Run service that sets secret-looking env vars as plaintext
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "google_cloud_run_v2_service"
  resource.change.actions[_] == "create"

  container := resource.change.after.template[0].containers[0]
  env := container.env[_]

  regex.match("(?i)(secret|key|token|password|credential|api_key)", env.name)

  env.value != null
  env.value != ""
  not env.value_source

  msg := sprintf(
    "Cloud Run service '%s': env var '%s' looks like a secret but is set as plaintext. Use Secret Manager instead. See docs/SECRET_NAMING.md",
    [resource.address, env.name]
  )
}
