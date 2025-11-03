# Landing.com Infrastructure

This repository contains Terraform configuration to provision the shared infrastructure for the Cloud Landing platform.

## What This Provisions

This Terraform configuration sets up the foundational infrastructure that all site deployments depend on:

1. **Route53 Hosted Zone** - DNS management for `landing.com`
2. **ACM Wildcard Certificate** - SSL/TLS for `*.landing.com` (in us-east-1 for CloudFront)
3. **S3 Bucket** - Terraform state storage (`terraform-state-landing`)
4. **DynamoDB Table** - Terraform state locking (`terraform-locks`)
5. **IAM User** - GitHub Actions deployment credentials with scoped permissions

## Prerequisites

- AWS account with administrative access
- Domain name registered (e.g., `landing.com`)
- AWS CLI configured with credentials
- Terraform >= 1.0 installed

## Usage

### 1. Clone and Configure

```bash
git clone https://github.com/nailthelanding/landingcom.git
cd landingcom

# Create your variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your domain
vim terraform.tfvars
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

This will show you exactly what will be created.

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted. This will:
- Create all infrastructure (takes ~5-10 minutes)
- Certificate validation may take up to 30 minutes

### 5. Save Outputs

```bash
# View all outputs
terraform output

# Save credentials securely
terraform output -json > credentials.json
chmod 600 credentials.json

# View specific values
terraform output route53_name_servers
terraform output -raw backend_environment_variables
```

### 6. Update Domain Registrar

Update your domain registrar with the Route53 nameservers:

```bash
terraform output route53_name_servers
```

Copy these nameservers to your domain registrar's DNS settings.

### 7. Verify DNS Propagation

Wait 5-30 minutes, then verify:

```bash
dig NS landing.com
```

### 8. Configure Backend Service

Add the credentials to your backend service:

```bash
terraform output -raw backend_environment_variables
```

Copy the output to your backend `.env` file.

## Outputs

| Output | Description |
|--------|-------------|
| `route53_zone_id` | Hosted zone ID |
| `route53_name_servers` | NS records for domain registrar |
| `acm_certificate_arn` | Certificate ARN for CloudFront |
| `terraform_state_bucket` | State bucket name |
| `terraform_lock_table` | Lock table name |
| `github_actions_access_key_id` | AWS access key (sensitive) |
| `github_actions_secret_access_key` | AWS secret key (sensitive) |

## Security Notes

- The IAM user has permissions scoped to only what's needed for site deployments
- State bucket has versioning and encryption enabled
- State bucket blocks all public access
- Credentials are marked as sensitive outputs
- **Never commit `terraform.tfvars` or `credentials.json` to version control**

## What Happens Next

After this infrastructure is provisioned:

1. Individual site repositories will reference these shared resources
2. Each site gets its own isolated Terraform state file in the state bucket
3. Sites use the DynamoDB table to prevent concurrent deployment conflicts
4. All sites use the wildcard certificate for HTTPS
5. Sites create their own Route53 records as subdomains

## Maintenance

### View Current State

```bash
terraform show
```

### Update Infrastructure

```bash
terraform plan
terraform apply
```

### Destroy (⚠️ DANGEROUS)

```bash
terraform destroy
```

**Warning:** This will delete all shared infrastructure. Only do this if you're tearing down the entire platform.

## Troubleshooting

### Certificate Validation Stuck

If ACM certificate validation takes longer than 30 minutes:

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region us-east-1

# Check DNS validation records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(terraform output -raw route53_zone_id)
```

### DNS Not Propagating

DNS changes can take up to 48 hours, but usually complete in 5-30 minutes:

```bash
# Check nameservers
dig NS landing.com

# Check from multiple locations
dig @8.8.8.8 NS landing.com
dig @1.1.1.1 NS landing.com
```

## Support

For issues or questions, refer to the main Cloud Landing platform documentation.
