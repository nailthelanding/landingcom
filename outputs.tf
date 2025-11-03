output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_name_servers" {
  description = "Route53 name servers - UPDATE YOUR DOMAIN REGISTRAR WITH THESE"
  value       = aws_route53_zone.main.name_servers
}

output "acm_certificate_arn" {
  description = "ARN of the wildcard ACM certificate (in us-east-1)"
  value       = aws_acm_certificate.wildcard.arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.wildcard.status
}

output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_lock_table" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "github_actions_user" {
  description = "IAM user name for GitHub Actions"
  value       = aws_iam_user.github_actions.name
}

output "github_actions_access_key_id" {
  description = "Access Key ID for GitHub Actions user - SAVE THIS SECURELY"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "Secret Access Key for GitHub Actions user - SAVE THIS SECURELY"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}

output "backend_environment_variables" {
  description = "Environment variables to add to your backend service"
  value = <<-EOT

  Add these to your backend .env file:

  AWS_ACCESS_KEY_ID=${aws_iam_access_key.github_actions.id}
  AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.github_actions.secret}
  AWS_REGION=${var.aws_region}
  ROOT_DOMAIN=${var.domain_name}
  TF_STATE_BUCKET=${aws_s3_bucket.terraform_state.id}
  TF_STATE_LOCK_TABLE=${aws_dynamodb_table.terraform_locks.name}
  EOT
  sensitive = true
}

output "next_steps" {
  description = "What to do next"
  value = <<-EOT

  ✅ Infrastructure provisioned successfully!

  📋 NEXT STEPS:

  1. UPDATE YOUR DOMAIN REGISTRAR
     Point ${var.domain_name} to these nameservers:
     ${join("\n     ", aws_route53_zone.main.name_servers)}

  2. SAVE CREDENTIALS
     Run: terraform output -json > credentials.json
     Then extract AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

  3. UPDATE BACKEND SERVICE
     Run: terraform output backend_environment_variables
     Copy the output to your backend .env file

  4. VERIFY DNS PROPAGATION
     Wait 5-30 minutes, then run: dig NS ${var.domain_name}

  5. DEPLOY YOUR FIRST SITE!
     Your platform is ready to deploy sites.

  EOT
}
