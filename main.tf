variable "GCLOUD_PROJECT" {
  type        = string
  description = "The project to terraform in"
}

variable "RUN_IMAGE" {
  type        = string
  description = "The image tag to use in Cloud Run"
}

provider "google" {
  project = var.GCLOUD_PROJECT
  region  = "europe-west1"
  zone    = "europe-west1-d"
}

provider "google-beta" {
  project = var.GCLOUD_PROJECT
  region  = "europe-west1"
  zone    = "europe-west1-d"
}

terraform {
  backend "gcs" {
    bucket = "sadl-mastodon-tf"
    prefix = "terraform/state"
  }
}

resource "google_project_service" "build_api" {
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
}

resource "google_project_service" "sqladmin_api" {
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "servicenetworking_api" {
  service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "redis_api" {
  service = "redis.googleapis.com"
}

resource "google_project_service" "vpcaccess_api" {
  service = "vpcaccess.googleapis.com"
}

# resource "google_cloud_run_service" "default" {
#   name     = "sadl-mastodon-srv"
#   location = "europe-west1"

#   metadata {
#     namespace = "sadl-mastodon"
#   }

#   template {
#     spec {
#       containers {
#         image = var.RUN_IMAGE
#       }
#     }
#   }

#   traffic {
#     percent         = 100
#     latest_revision = true
#   }
# }

resource "google_compute_network" "private_network" {
  provider = google-beta

  depends_on = [
    google_project_service.compute_api
  ]

  name = "private-network"
}

resource "google_compute_global_address" "private_ip_address" {
  provider = google-beta

  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  depends_on = [
    google_project_service.servicenetworking_api
  ]

  network                 = google_compute_network.private_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "instance" {
  provider = google-beta
  depends_on = [
    google_project_service.sqladmin_api,
    google_service_networking_connection.private_vpc_connection
  ]

  name             = "sadl-mastodon-sql"
  region           = "europe-west1"
  database_version = "POSTGRES_14"

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.private_network.id
    }
  }

  deletion_protection = "true"
}

resource "google_sql_database" "database" {
  name     = "mastodon"
  instance = google_sql_database_instance.instance.name
}

resource "google_redis_instance" "redis" {
  name           = "mastodon-redis"
  tier           = "BASIC"
  memory_size_gb = 1

  location_id = "europe-west1-d"

  authorized_network = google_compute_network.private_network.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  depends_on = [
    google_project_service.redis_api,
    google_service_networking_connection.private_vpc_connection
  ]
}

resource "google_vpc_access_connector" "connector" {
  depends_on = [
    google_project_service.vpcaccess_api
  ]
  name          = "sadl-mastodon-connector"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.private_network.id
}
