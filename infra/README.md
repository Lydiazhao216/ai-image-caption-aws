# Infrastructure as Code (retrospective)

This Terraform configuration describes the AWS architecture used in the
original deployment (VPC/subnets, ALB + Auto Scaling Group, RDS, S3,
Lambda + EventBridge). It was written **after** the fact, based on the
deployment report and console configuration from the original AWS Academy
sandbox deployment, to document the architecture as code rather than
leaving it as manual click-ops.

**Status:** this has not been re-applied against a live AWS account (the
original sandbox account is no longer active), so treat it as an
as-built architecture reference rather than a verified, ready-to-run
deployment. Before running `terraform apply` against a real account, you
would want to:

- Review the placeholder `user_data` bootstrap script in `compute.tf`
  (the original deployment installed dependencies manually via SSH)
- Attach the Pillow Lambda Layer ARN for your target region/runtime in
  `lambda_and_events.tf` (see the Klayers note in the main README)
- Replace the broad IAM policies in `compute.tf` with scoped,
  least-privilege permissions
- Supply `db_username`, `db_password`, `gemini_api_key`, and
  `s3_bucket_name` via a `terraform.tfvars` file or environment
  variables (`TF_VAR_...`) — never commit these

## Usage

```
terraform init
terraform plan
terraform apply
```
