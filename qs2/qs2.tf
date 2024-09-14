provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
  credentials = file(var.credentials_file)
}

variable "project_id" {
  type        = string
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
}

variable "credentials_file" {
  type        = string
}

resource "google_compute_network" "vpc_network" {
  name                    = "dev-staging-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "dev_subnet" {
  name          = "dev-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "staging_subnet" {
  name          = "staging-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_router" "router" {
  name    = "dev-staging-router"
  region  = var.region
  network = google_compute_network.vpc_network.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "dev-staging-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_vpn_gateway" "vpn_gateway" {
  name    = "dev-staging-vpn-gateway"
  network = google_compute_network.vpc_network.id
}


resource "google_container_cluster" "dev_cluster" {
  name     = "dev-cluster"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.dev_subnet.id
}

resource "google_container_node_pool" "dev_nodes" {
  name       = "dev-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.dev_cluster.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
  }
}

resource "google_container_cluster" "staging_cluster" {
  name     = "staging-cluster"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.staging_subnet.id
}

resource "google_container_node_pool" "staging_nodes" {
  name       = "staging-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.staging_cluster.name
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
  }
}

resource "google_storage_bucket" "dev_storage" {
  name     = "${var.project_id}-dev-storage"
  location = var.region
}

resource "google_storage_bucket" "staging_storage" {
  name     = "${var.project_id}-staging-storage"
  location = var.region
}

resource "google_firestore_database" "dev_firestore" {
  project                     = var.project_id
  name                        = "(default)"
  location_id                 = var.region
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
}

# Container Registry
resource "google_container_registry" "registry" {
  project  = var.project_id
  location = "US"
}
# Output
output "dev_cluster_endpoint" {
  value = google_container_cluster.dev_cluster.endpoint
}

output "staging_cluster_endpoint" {
  value = google_container_cluster.staging_cluster.endpoint
}
