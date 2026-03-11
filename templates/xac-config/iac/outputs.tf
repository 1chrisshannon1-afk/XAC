output "wif_provider" {
  value = module.staging.wif_provider
}

output "ci_service_account" {
  value = module.staging.ci_service_account
}

output "artifact_registry_url" {
  value = module.staging.artifact_registry_url
}

output "service_urls" {
  value = module.staging.service_urls
}
