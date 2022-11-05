variable "GCLOUD_PROJECT" {
    type = string
    description = "The project to terraform in"
}

provider "google" {
  project = GCLOUD_PROJECT
  region = "europe-west1"
}
