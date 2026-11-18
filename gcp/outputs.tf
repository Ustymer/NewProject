output "cloud_run_url" {
  description = "The public HTTPS URL of the Cloud Run FastAPI backend"
  value       = google_cloud_run_v2_service.api.uri
}

output "artifact_registry_repo" {
  description = "Docker repository URI in Artifact Registry"
  value       = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL instance identifier"
  value       = google_sql_database_instance.db.name
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name (PROJECT:REGION:INSTANCE)"
  value       = google_sql_database_instance.db.connection_name
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "database_user" {
  description = "Database username"
  value       = google_sql_user.user.name
}

output "stop_db_command" {
  description = "Command to stop Cloud SQL instance to eliminate compute charges when idle"
  value       = "gcloud sql instances patch ${google_sql_database_instance.db.name} --activation-policy=NEVER --project=${var.gcp_project_id}"
}

output "start_db_command" {
  description = "Command to resume Cloud SQL instance"
  value       = "gcloud sql instances patch ${google_sql_database_instance.db.name} --activation-policy=ALWAYS --project=${var.gcp_project_id}"
}
