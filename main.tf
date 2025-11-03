terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# Route53 Hosted Zone
# ============================================================================

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = var.domain_name
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "cloud-landing-platform"
  }
}

# ============================================================================
# ACM Wildcard Certificate (for CloudFront - must be in us-east-1)
# ============================================================================

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "wildcard" {
  provider          = aws.us_east_1
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"

  tags = {
    Name        = "wildcard-${var.domain_name}"
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "cloud-landing-platform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS validation records in Route53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "wildcard" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ============================================================================
# Terraform State Backend - S3 Bucket
# ============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket

  tags = {
    Name        = var.terraform_state_bucket
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "terraform-state-storage"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# DynamoDB Table for State Locking
# ============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.terraform_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = var.terraform_lock_table
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "terraform-state-locking"
  }
}

# ============================================================================
# IAM User for GitHub Actions Deployments
# ============================================================================

resource "aws_iam_user" "github_actions" {
  name = var.github_actions_user

  tags = {
    Name        = var.github_actions_user
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "github-actions-deployment"
  }
}

resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

# IAM Policy for GitHub Actions user
resource "aws_iam_user_policy" "github_actions" {
  name = "DeploymentPolicy"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3SiteManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketWebsite",
          "s3:PutBucketVersioning",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:ListBucketVersions"
        ]
        Resource = [
          "arn:aws:s3:::site-*",
          "arn:aws:s3:::site-*/*"
        ]
      },
      {
        Sid    = "S3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Sid    = "S3StateListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn
        ]
      },
      {
        Sid    = "CloudFrontManagement"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:TagResource",
          "cloudfront:ListTagsForResource",
          "cloudfront:CreateOriginAccessIdentity",
          "cloudfront:GetOriginAccessIdentity",
          "cloudfront:DeleteOriginAccessIdentity",
          "cloudfront:CreateCachePolicy",
          "cloudfront:GetCachePolicy",
          "cloudfront:DeleteCachePolicy",
          "cloudfront:CreateOriginRequestPolicy",
          "cloudfront:GetOriginRequestPolicy",
          "cloudfront:DeleteOriginRequestPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53Management"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${aws_route53_zone.main.zone_id}",
          "arn:aws:route53:::change/*"
        ]
      },
      {
        Sid    = "Route53List"
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      },
      {
        Sid    = "ACMReadAccess"
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListCertificates"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBStateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = aws_dynamodb_table.terraform_locks.arn
      }
    ]
  })
}
