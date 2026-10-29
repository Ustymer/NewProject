# ADR 0007: Manage AWS infrastructure with Terraform

## Status
Proposed — pending successful migration and verification.

## Context
The application infrastructure is currently managed by AWS CloudFormation.
The project needs Terraform configuration and HCP Terraform remote execution
while preserving existing AWS resources and application data.

## Decision
Use Terraform with the AWS provider in eu-north-1.
Store Terraform configuration in the repository and use an HCP Terraform
workspace connected to GitHub for remote plans and applies.
Use dynamic AWS credentials for remote runs.
Import existing resources into Terraform state instead of recreating them.
Keep credentials and sensitive values out of version control.

## Safety
Do not remove CloudFormation stacks or apply infrastructure changes until
resource retention, import mappings, and the Terraform plan have been reviewed.
Protect existing databases, object storage, and identity resources.

## Consequences
Infrastructure changes become reviewable through version control and
HCP Terraform plans. Migration requires careful state adoption and
verification that subsequent plans report no changes.
