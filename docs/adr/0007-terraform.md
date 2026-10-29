# ADR 0007: Terraform for the project's infrastructure

Status: accepted

## Context
Cognito (Lab 4) and the weekly report (Lab 5) were CloudFormation stacks. They hold live data: the
user pool has real accounts and the reports bucket has reports, so they could not be deleted and
re-created. The project already reaches outside one AWS account (Google OAuth, GitHub), needs more
than one environment, and the team wants a plan to review before anything changes.

## Decision
- Terraform with one root module in `infra/` (`auth.tf`, `reports.tf`) and one HCP Terraform
  workspace, `new-project-lab7`, connected to this repository (working directory `infra`).
  The Lab 6 parser was never deployed as its own stack, so there is no `ai.tf`.
- Nothing was re-created. Every CloudFormation resource got `DeletionPolicy: Retain`, the two
  stacks were deleted, and 31 `import` blocks handed the resources to Terraform. The apply was
  started by a push and finished as "Apply finished"; the next plan said "No changes". The
  managed-login branding of Cognito stays outside Terraform (retained).
- The Cognito resources use `ignore_changes = all` (they were imported as they are in AWS);
  tightening them with `terraform plan -generate-config-out` is a follow-up. The report builder
  ignores `image_uri`, because the application pipeline deploys new images.
- HCP Terraform reaches AWS with dynamic credentials (OIDC, a short-lived role per run), so there
  are no AWS keys in the workspace or in Git.

## Alternatives considered
- CloudFormation (status quo): AWS-only and no plan step; it cannot manage the Google and GitHub
  parts of the same system.
- CDK: still produces CloudFormation, keeps the AWS-only limit and adds a build step.
- OpenTofu: same language and workflow; HCP Terraform gives hosted state, locking and VCS runs out
  of the box, so Terraform was the shorter path.
- Delete the stacks and apply fresh: would delete the user accounts and the reports. Rejected.

## Consequences
- Who changes the infrastructure: anyone through a pull request or a push to the branch; HCP
  Terraform plans it and a person confirms the apply. The laptop is for emergencies only.
- Secrets: `google_client_secret` is a sensitive workspace variable. The state is stored in HCP
  Terraform (encrypted, access controlled, versioned, locked during a run); it contains the
  database URL and the secret, so access to the workspace is access to those secrets. The state
  is never committed to Git.
- If HCP Terraform is down, nothing running stops: Cognito, the queue, the Lambdas and the schedule
  live in AWS. Only changes to the infrastructure wait. In an emergency the console can be used and
  the change written back into the code afterwards (the next plan shows it as drift).
- The role used by HCP Terraform has `AdministratorAccess`. The next step is to narrow its trust
  to `workspace:new-project-lab7` (done in the trust policy) and its permissions to Cognito, S3,
  SQS, Lambda, IAM, EC2 networking, CloudWatch Logs, EventBridge Scheduler and SES.
- Scripts that read the outputs of the deleted stacks (`deploy-auth`, `deploy-reports`, parts of
  `deploy-backend` and `report-now`) have to read `terraform output` or `.env` instead.
