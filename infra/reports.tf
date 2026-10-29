# Weekly report: Scheduler / make report-now -> SQS -> builder Lambda (VPC) -> S3 -> mailer Lambda -> SES.
# Was infra/reports.yaml (Lab 5).

data "aws_caller_identity" "current" {}

# The report builder runs the same image and uses the same database and token keys as the API.
data "aws_lambda_function" "backend" {
  function_name = "${var.project_name}-backend"
}

locals {
  reports_bucket = "${var.project_name}-reports-${data.aws_caller_identity.current.account_id}"
  backend_env    = data.aws_lambda_function.backend.environment[0].variables
  policy_vpc     = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  policy_sqs     = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  policy_basic   = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---- S3 gateway endpoint with its own route table for the two private subnets
resource "aws_route_table" "reports" {
  vpc_id = var.vpc_id
}

resource "aws_route_table_association" "a" {
  subnet_id      = var.private_subnet_a
  route_table_id = aws_route_table.reports.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = var.private_subnet_b
  route_table_id = aws_route_table.reports.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.reports.id]
}

# ---- Bucket. In Terraform the bucket, the Lambda permission and the notification are three
# separate resources, so Lab 5's circular dependency (and its explicit-name trick) is gone.
resource "aws_s3_bucket" "reports" {
  bucket = local.reports_bucket
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    id     = "expire-90d"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_notification" "reports" {
  bucket = aws_s3_bucket.reports.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.mailer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.mailer_s3]
}

resource "aws_lambda_permission" "mailer_s3" {
  statement_id   = "${var.project_name}-reports-MailerPermission-AUlOLAigkDPg"
  function_name  = aws_lambda_function.mailer.function_name
  action         = "lambda:InvokeFunction"
  principal      = "s3.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "arn:aws:s3:::${local.reports_bucket}"
}

# ---- Queue + dead-letter queue
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-report-requests-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "requests" {
  name                       = "${var.project_name}-report-requests"
  visibility_timeout_seconds = 600 # at least 6 x builder timeout (90 s)

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# ---- Builder (in the VPC, same image as the API)
resource "aws_cloudwatch_log_group" "builder" {
  name              = "/${var.project_name}/report-builder"
  retention_in_days = 7
}

resource "aws_iam_role" "builder" {
  name = "${var.project_name}-reports-BuilderRole-GVqsR8fxnuZ3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "builder_vpc" {
  role       = aws_iam_role.builder.name
  policy_arn = local.policy_vpc
}

resource "aws_iam_role_policy_attachment" "builder_sqs" {
  role       = aws_iam_role.builder.name
  policy_arn = local.policy_sqs
}

resource "aws_iam_role_policy" "builder_put_reports" {
  name = "put-reports"
  role = aws_iam_role.builder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "arn:aws:s3:::${local.reports_bucket}/reports/*"
    }]
  })
}

resource "aws_lambda_function" "builder" {
  function_name = "${var.project_name}-report-builder"
  package_type  = "Image"
  image_uri     = var.report_image_uri
  architectures = ["arm64"]
  memory_size   = 512
  timeout       = 90
  role          = aws_iam_role.builder.arn

  vpc_config {
    subnet_ids         = [var.private_subnet_a, var.private_subnet_b]
    security_group_ids = [var.function_security_group_id]
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.builder.name
  }

  environment {
    variables = {
      DATABASE_URL                 = local.backend_env["DATABASE_URL"]
      CORS_ORIGINS                 = var.report_cors_origins
      COGNITO_USER_POOL_ID         = aws_cognito_user_pool.main.id
      COGNITO_CLIENT_ID            = aws_cognito_user_pool_client.web.id
      COGNITO_JWKS                 = local.backend_env["COGNITO_JWKS"]
      REPORTS_WORKER               = "1"
      REPORTS_BUCKET               = local.reports_bucket
      FAIL_WEEK                    = var.fail_week
      AWS_LWA_PORT                 = "8000"
      AWS_LWA_READINESS_CHECK_PATH = "/api/health"
      AWS_LWA_ASYNC_INIT           = "true"
      AWS_LWA_PASS_THROUGH_PATH    = "/events"
    }
  }

  depends_on = [aws_vpc_endpoint.s3, aws_route_table_association.a, aws_route_table_association.b]

  lifecycle {
    # The application pipeline deploys new images; Terraform must not roll them back.
    ignore_changes = [image_uri]
  }
}

resource "aws_lambda_event_source_mapping" "queue" {
  event_source_arn        = aws_sqs_queue.requests.arn
  function_name           = aws_lambda_function.builder.arn
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]
}

# ---- Schedule
resource "aws_iam_role" "scheduler" {
  name = "${var.project_name}-reports-SchedulerRole-9aMzI8z8KAtr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_send" {
  name = "send"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.requests.arn
    }]
  })
}

resource "aws_scheduler_schedule" "weekly" {
  name                         = "${var.project_name}-weekly-report"
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = "Europe/Kyiv"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sqs_queue.requests.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{\"week\": null, \"source\": \"schedule\"}"
  }
}

# ---- Mailer (outside the VPC)
data "archive_file" "mailer" {
  type        = "zip"
  source_file = "${path.module}/mailer/index.py"
  output_path = "${path.module}/mailer.zip"
}

resource "aws_cloudwatch_log_group" "mailer" {
  name              = "/${var.project_name}/report-mailer"
  retention_in_days = 7
}

resource "aws_iam_role" "mailer" {
  name = "${var.project_name}-reports-MailerRole-7N2LjeEdrVoh"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mailer_basic" {
  role       = aws_iam_role.mailer.name
  policy_arn = local.policy_basic
}

resource "aws_iam_role_policy" "mailer_read_and_send" {
  name = "read-and-send"
  role = aws_iam_role.mailer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${local.reports_bucket}/reports/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "mailer" {
  function_name    = "${var.project_name}-report-mailer"
  runtime          = "python3.13"
  handler          = "index.handler"
  timeout          = 30
  role             = aws_iam_role.mailer.arn
  filename         = data.archive_file.mailer.output_path
  source_code_hash = data.archive_file.mailer.output_base64sha256

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.mailer.name
  }

  environment {
    variables = {
      SENDER     = var.report_email
      RECIPIENTS = var.report_email
    }
  }
}

# ---- SES (sandbox: the address is already verified)
resource "aws_sesv2_email_identity" "report" {
  email_identity = var.report_email
}
