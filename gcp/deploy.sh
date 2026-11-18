#!/usr/bin/env bash
set -euo pipefail

# Deployment script for Spry on Google Cloud Platform
# Usage: ./gcp/deploy.sh [PROJECT_ID] [REGION]

PROJECT_ID="${1:-${GCP_PROJECT_ID:-}}"
REGION="${2:-${GCP_REGION:-us-central1}}"

if [ -z "$PROJECT_ID" ]; then
  # Try to read from gcloud config if set
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
fi

if [ -z "$PROJECT_ID" ]; then
  echo "Error: GCP Project ID is required."
  echo "Usage: ./gcp/deploy.sh <GCP_PROJECT_ID> [REGION]"
  echo "   or: export GCP_PROJECT_ID=<your-project-id>"
  exit 1
fi

echo "=========================================================="
echo " Deploying Spry to Google Cloud Platform"
echo " Project: $PROJECT_ID"
echo " Region:  $REGION"
echo "=========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Step 1: Initialize and apply Terraform
echo ""
echo "==> Step 1: Running Terraform in gcp/..."
cd "$SCRIPT_DIR"

if [ ! -d ".terraform" ]; then
  terraform init
fi

terraform apply -auto-approve \
  -var="gcp_project_id=$PROJECT_ID" \
  -var="gcp_region=$REGION"

REPO_URI="$(terraform output -raw artifact_registry_repo)"
CLOUD_RUN_URL="$(terraform output -raw cloud_run_url)"
DB_INSTANCE="$(terraform output -raw cloud_sql_instance_name)"

echo ""
echo "==> Step 2: Configuring Docker for Artifact Registry..."
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet || true

echo ""
echo "==> Step 3: Building & pushing backend container..."
IMAGE_TAG="$REPO_URI/backend:latest"
cd "$ROOT_DIR"
docker build -t "$IMAGE_TAG" -f backend/Dockerfile.gcp backend/
docker push "$IMAGE_TAG"

echo ""
echo "==> Step 4: Updating Cloud Run with backend container..."
gcloud run deploy spry-api \
  --image "$IMAGE_TAG" \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --quiet

CLOUD_RUN_URL="$(gcloud run services describe spry-api --region "$REGION" --project "$PROJECT_ID" --format='value(status.url)')"

echo ""
echo "==> Step 5: Building and deploying frontend to Firebase..."
cd "$ROOT_DIR/frontend"
VITE_API_URL="$CLOUD_RUN_URL" npm run build

cd "$ROOT_DIR"
if command -v firebase >/dev/null 2>&1; then
  firebase deploy --only hosting --project "$PROJECT_ID"
else
  echo "Notice: firebase CLI not found in PATH."
  echo "To deploy frontend: npm install -g firebase-tools && firebase deploy --only hosting --project $PROJECT_ID"
fi

echo ""
echo "=========================================================="
echo " Deployment Complete!"
echo " Cloud Run API: $CLOUD_RUN_URL"
echo " API Docs:      $CLOUD_RUN_URL/api/docs"
echo " Cloud SQL DB:  $DB_INSTANCE"
echo ""
echo " IMPORTANT: Stop Cloud SQL when idle to avoid hourly charges:"
echo "   make gcp-stop-db"
echo "=========================================================="
