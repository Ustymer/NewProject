variable "aws_region" {
  description = "AWS region containing the existing application infrastructure"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Prefix of all resource names; every resource is tagged PROJECT_NAME"
  type        = string
  default     = "new-project-ustymer"
}

variable "report_email" {
  description = "Verified SES address, sender and recipient of the weekly report"
  type        = string
  default     = "trukhin.pn@ucu.edu.ua"
}

variable "vpc_id" {
  type    = string
  default = "vpc-09c571e7e587a023f"
}

variable "private_subnet_a" {
  type    = string
  default = "subnet-03b600c3f67382d6f"
}

variable "private_subnet_b" {
  type    = string
  default = "subnet-01bc8fa4191ddd305"
}

variable "function_security_group_id" {
  type    = string
  default = "sg-0adb1700e00b48861"
}

variable "report_image_uri" {
  description = "Image of the report builder; the application pipeline updates it, so Terraform ignores later changes"
  type        = string
  default     = "426592734182.dkr.ecr.eu-north-1.amazonaws.com/new-project-ustymer-backend:33bde1c-dirty-20261015171220"
}

variable "report_cors_origins" {
  type    = string
  default = "https://d1r5v0drnol8ds.cloudfront.net"
}

variable "schedule_expression" {
  type    = string
  default = "cron(0 7 ? * MON *)"
}

variable "fail_week" {
  type    = string
  default = ""
}

variable "google_client_id" {
  description = "Public OAuth client id of the Google sign-in"
  type        = string
  default     = "493112844555-kfjmcfcd16co4ittdj01r52as7qlm8gj.apps.googleusercontent.com"
}

variable "google_client_secret" {
  description = "Set as a sensitive variable in the HCP Terraform workspace, never in Git"
  type        = string
  sensitive   = true
  default     = ""
}
