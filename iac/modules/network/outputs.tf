output "vpc_id" {
  value = google_compute_network.main.id
}

output "vpc_name" {
  value = google_compute_network.main.name
}

output "subnet_id" {
  value = google_compute_subnetwork.main.id
}

output "connector_id" {
  value = google_vpc_access_connector.main.id
}

output "connector_name" {
  value = google_vpc_access_connector.main.name
}
