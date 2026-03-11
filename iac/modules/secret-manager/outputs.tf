output "secret_id" {
  value = google_secret_manager_secret.main.secret_id
}

output "secret_name" {
  value = google_secret_manager_secret.main.name
}
