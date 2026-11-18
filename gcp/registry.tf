resource "google_artifact_registry_repository" "repo" {
  location      = var.gcp_region
  repository_id = "${var.project_name}-repo"
  description   = "Docker repository for ${var.project_name} container images"
  format        = "DOCKER"

  depends_on = [google_project_service.enabled_services]
}
