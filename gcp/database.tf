resource "random_id" "db_suffix" {
  byte_length = 4
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "google_sql_database_instance" "db" {
  name             = "${var.project_name}-db-${random_id.db_suffix.hex}"
  database_version = "POSTGRES_16"
  region           = var.gcp_region

  deletion_protection = false

  settings {
    tier              = var.db_tier
    activation_policy = var.db_activation_policy
    disk_type         = "PD_SSD"
    disk_size         = 10

    ip_configuration {
      ipv4_enabled = true
    }

    backup_configuration {
      enabled = false
    }
  }

  depends_on = [google_project_service.enabled_services]
}

resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.db.name
}

resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.db.name
  password = random_password.db_password.result
}

# Secret Manager for database credentials
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_name}-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled_services]
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "${var.project_name}-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled_services]
}

resource "google_secret_manager_secret_version" "database_url_version" {
  secret = google_secret_manager_secret.database_url.id
  # Cloud Run mounts the Cloud SQL Auth Proxy unix socket at /cloudsql/<CONNECTION_NAME>
  secret_data = "postgresql+asyncpg://${var.db_user}:${random_password.db_password.result}@/${var.db_name}?host=/cloudsql/${google_sql_database_instance.db.connection_name}"
}
