package terraform

required_labels := {"project", "company", "environment", "managed_by"}

deny[msg] {
  resource := input.resource_changes[_]
  resource.change.actions[_] == "create"

  startswith(resource.type, "google_")
  resource.type != "google_project_iam_member"
  resource.type != "google_project_iam_binding"

  missing := required_labels - {k | resource.change.after.labels[k]}
  count(missing) > 0

  msg := sprintf(
    "Resource '%s' is missing required labels: %v. All resources must carry: %v",
    [resource.address, missing, required_labels]
  )
}
