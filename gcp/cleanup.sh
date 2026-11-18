#!/usr/bin/env bash
set -euo pipefail

# Cleanup script for Spry on Google Cloud Platform
# Usage: ./gcp/cleanup.sh [stop-db | destroy]

ACTION="${1:-stop-db}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

if [ "$ACTION" = "stop-db" ]; then
  echo "==> Stopping Cloud SQL instance to eliminate compute billing..."
  if terraform output cloud_sql_instance_name >/dev/null 2>&1; then
    DB_NAME="$(terraform output -raw cloud_sql_instance_name)"
    PROJECT_ID="$(terraform output -raw cloud_run_url | sed -E 's|https://[^.]+\.([^.]+)\.run\.app.*|\1|' 2>/dev/null || true)"
    if [ -z "$PROJECT_ID" ]; then
      PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
    fi
    gcloud sql instances patch "$DB_NAME" --activation-policy=NEVER --project="$PROJECT_ID"
    echo "Cloud SQL instance $DB_NAME is now stopped. Storage will continue to bill ~$1.70/month."
    echo "To restart it, run: ./gcp/cleanup.sh start-db"
  else
    echo "Terraform state not found or output missing."
  fi

elif [ "$ACTION" = "start-db" ]; then
  echo "==> Resuming Cloud SQL instance..."
  DB_NAME="$(terraform output -raw cloud_sql_instance_name)"
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
  gcloud sql instances patch "$DB_NAME" --activation-policy=ALWAYS --project="$PROJECT_ID"
  echo "Cloud SQL instance $DB_NAME has resumed."

elif [ "$ACTION" = "destroy" ]; then
  echo "==> Destroying all GCP resources with Terraform..."
  terraform destroy -auto-approve
  echo "All resources destroyed successfully."

else
  echo "Unknown action: $ACTION"
  echo "Usage: ./gcp/cleanup.sh [stop-db | start-db | destroy]"
  exit 1
fi
