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

resource "google_cloud_run_service" "default" {
  name     = "sadl-mastodon-srv"
  location = "europe-west1"

  template {
    spec {
      containers {
        image = var.RUN_IMAGE
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_sql_database_instance" "instance" {
  name             = "sadl-mastodon-sql"
  region           = "europe-west1"
  database_version = "POSTGRES_14"
  settings {
    tier = "db-f1-micro"
  }

  deletion_protection = "true"
}
