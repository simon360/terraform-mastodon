variable "GCLOUD_PROJECT" {
  type        = string
  description = "The project to terraform in"
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
