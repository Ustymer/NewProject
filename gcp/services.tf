locals {
  services = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
  ]
}

resource "google_project_service" "enabled_services" {
  for_each = toset(locals.services)

  project = var.gcp_project_id
  service = each.key

  disable_on_destroy = false
}
