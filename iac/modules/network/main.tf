locals {
  standard_labels = {
    project     = var.project_name
    company     = var.company
    environment = var.environment
    managed_by  = "terraform"
    repo        = "IAC"
  }
}

resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = false
  description             = "VPC for ${var.project_name}"
}

resource "google_compute_subnetwork" "main" {
  project       = var.project_id
  region        = var.region
  name          = "${var.vpc_name}-${var.region}"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.main.id
  private_ip_google_access = var.enable_private_google_access
  labels        = local.standard_labels
}

resource "google_vpc_access_connector" "main" {
  project       = var.project_id
  region        = var.region
  name          = "run-connector"
  ip_cidr_range = var.connector_cidr
  min_instances = var.connector_min_instances
  max_instances = var.connector_max_instances
  network       = google_compute_network.main.name
  labels        = local.standard_labels
}

resource "google_compute_router" "main" {
  count = var.enable_cloud_nat ? 1 : 0

  project = var.project_id
  region  = var.region
  name    = "router-${var.region}"
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  count = var.enable_cloud_nat ? 1 : 0

  project                            = var.project_id
  region                             = var.region
  name                               = "nat-${var.region}"
  router                             = google_compute_router.main[0].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Allow internal traffic within VPC (priority higher than deny)
resource "google_compute_firewall" "allow_internal" {
  project  = var.project_id
  name     = "${var.vpc_name}-allow-internal"
  network  = google_compute_network.main.name
  priority = 100
  labels   = local.standard_labels

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = [var.subnet_cidr, var.connector_cidr]
}

# Allow Cloud Run health check probes (GCP health check IP ranges) (priority higher than deny)
resource "google_compute_firewall" "allow_health_checks" {
  project     = var.project_id
  name        = "${var.vpc_name}-allow-health-checks"
  network     = google_compute_network.main.name
  priority    = 100
  description = "Cloud Run and Load Balancer health checks"
  labels      = local.standard_labels

  allow {
    protocol = "tcp"
    ports    = ["8080", "3000"]
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

# Default deny ingress from internet (Cloud Run has its own LB)
resource "google_compute_firewall" "deny_ingress_internet" {
  project     = var.project_id
  name        = "${var.vpc_name}-deny-ingress-internet"
  network     = google_compute_network.main.name
  priority    = 1000
  direction   = "INGRESS"
  labels      = local.standard_labels

  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
}
