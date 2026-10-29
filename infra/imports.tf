# Existing resources handed over from CloudFormation. Delete this file after the migration.

import {
  to = aws_cognito_user_pool.main
  id = "eu-north-1_3FBlS7oHH"
}
import {
  to = aws_cognito_user_pool_client.web
  id = "eu-north-1_3FBlS7oHH/64usc6h4nq6lchltq7bcuhbhd7"
}
import {
  to = aws_cognito_user_pool_domain.main
  id = "new-project-ustymer-426592734182"
}
import {
  to = aws_cognito_identity_provider.google
  id = "eu-north-1_3FBlS7oHH:Google"
}

import {
  to = aws_route_table.reports
  id = "rtb-052444ce0703b5ca3"
}
import {
  to = aws_route_table_association.a
  id = "subnet-03b600c3f67382d6f/rtb-052444ce0703b5ca3"
}
import {
  to = aws_route_table_association.b
  id = "subnet-01bc8fa4191ddd305/rtb-052444ce0703b5ca3"
}
import {
  to = aws_vpc_endpoint.s3
  id = "vpce-07c81841d1b35bcab"
}

import {
  to = aws_s3_bucket.reports
  id = "new-project-ustymer-reports-426592734182"
}
import {
  to = aws_s3_bucket_public_access_block.reports
  id = "new-project-ustymer-reports-426592734182"
}
import {
  to = aws_s3_bucket_lifecycle_configuration.reports
  id = "new-project-ustymer-reports-426592734182"
}
import {
  to = aws_s3_bucket_notification.reports
  id = "new-project-ustymer-reports-426592734182"
}
import {
  to = aws_lambda_permission.mailer_s3
  id = "new-project-ustymer-report-mailer/new-project-ustymer-reports-MailerPermission-AUlOLAigkDPg"
}

import {
  to = aws_sqs_queue.dlq
  id = "https://sqs.eu-north-1.amazonaws.com/426592734182/new-project-ustymer-report-requests-dlq"
}
import {
  to = aws_sqs_queue.requests
  id = "https://sqs.eu-north-1.amazonaws.com/426592734182/new-project-ustymer-report-requests"
}

import {
  to = aws_cloudwatch_log_group.builder
  id = "/new-project-ustymer/report-builder"
}
import {
  to = aws_cloudwatch_log_group.mailer
  id = "/new-project-ustymer/report-mailer"
}

import {
  to = aws_iam_role.builder
  id = "new-project-ustymer-reports-BuilderRole-GVqsR8fxnuZ3"
}
import {
  to = aws_iam_role_policy_attachment.builder_vpc
  id = "new-project-ustymer-reports-BuilderRole-GVqsR8fxnuZ3/arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
import {
  to = aws_iam_role_policy_attachment.builder_sqs
  id = "new-project-ustymer-reports-BuilderRole-GVqsR8fxnuZ3/arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}
import {
  to = aws_iam_role_policy.builder_put_reports
  id = "new-project-ustymer-reports-BuilderRole-GVqsR8fxnuZ3:put-reports"
}
import {
  to = aws_iam_role.mailer
  id = "new-project-ustymer-reports-MailerRole-7N2LjeEdrVoh"
}
import {
  to = aws_iam_role_policy_attachment.mailer_basic
  id = "new-project-ustymer-reports-MailerRole-7N2LjeEdrVoh/arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
import {
  to = aws_iam_role_policy.mailer_read_and_send
  id = "new-project-ustymer-reports-MailerRole-7N2LjeEdrVoh:read-and-send"
}
import {
  to = aws_iam_role.scheduler
  id = "new-project-ustymer-reports-SchedulerRole-9aMzI8z8KAtr"
}
import {
  to = aws_iam_role_policy.scheduler_send
  id = "new-project-ustymer-reports-SchedulerRole-9aMzI8z8KAtr:send"
}

import {
  to = aws_lambda_function.builder
  id = "new-project-ustymer-report-builder"
}
import {
  to = aws_lambda_function.mailer
  id = "new-project-ustymer-report-mailer"
}
import {
  to = aws_lambda_event_source_mapping.queue
  id = "09ae6664-a3bf-4853-9815-20717ed3b0e2"
}
import {
  to = aws_scheduler_schedule.weekly
  id = "default/new-project-ustymer-weekly-report"
}
import {
  to = aws_sesv2_email_identity.report
  id = "trukhin.pn@ucu.edu.ua"
}
