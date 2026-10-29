# Cognito: the user pool, its app client, its domain and the Google identity provider.
# These resources were created by CloudFormation (Lab 4) and hold real accounts, so they are
# imported (imports.tf), never re-created. ignore_changes = all keeps Terraform from touching
# their settings until the HCL is tightened with `terraform plan -generate-config-out`.
# The managed-login branding is left outside Terraform (retained when the old stack is deleted).

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project_name}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }

  lifecycle {
    ignore_changes = all
  }
}
