output "wif_provider" {
  value = module.wif.wif_provider
}

output "ci_service_account" {
  value = module.wif.service_account_email
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "service_urls" {
  value = { for k, v in module.cloud_run : k => v.service_url }
}

output "vpc_connector_name" {
  value = var.enable_vpc && length(module.network) > 0 ? module.network[0].connector_name : ""
}
