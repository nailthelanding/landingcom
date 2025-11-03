variable "domain_name" {
  description = "Root domain name for the platform (e.g., 'landing.com')"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources (except ACM certificate which is always us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state storage"
  type        = string
  default     = "terraform-state-landing"
}

variable "terraform_lock_table" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "terraform-locks"
}

variable "github_actions_user" {
  description = "Name of the IAM user for GitHub Actions deployments"
  type        = string
  default     = "github-actions-deployer"
}
