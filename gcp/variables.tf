variable "gcp_project_id" {
  description = "The Google Cloud project ID (e.g. spry-ustymer-2026)"
  type        = string
}

variable "gcp_region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "spry"
}

variable "db_tier" {
  description = "The Cloud SQL instance machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "meetings"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "meetings"
}

variable "db_activation_policy" {
  description = "Activation policy for Cloud SQL: ALWAYS to run, NEVER to stop and avoid compute billing"
  type        = string
  default     = "ALWAYS"
}

variable "backend_image" {
  description = "Container image for Cloud Run API (Artifact Registry URL). If empty, placeholder is used"
  type        = string
  default     = ""
}

variable "cors_origins" {
  description = "Allowed origins for CORS (comma separated or * for wide access)"
  type        = string
  default     = "*"
}
