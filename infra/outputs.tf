output "aws_region" {
  description = "AWS region managed by Terraform"
  value       = var.aws_region
}

output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "reports_bucket" {
  value = aws_s3_bucket.reports.bucket
}

output "report_queue_url" {
  value = aws_sqs_queue.requests.url
}

output "report_dlq_url" {
  value = aws_sqs_queue.dlq.url
}
