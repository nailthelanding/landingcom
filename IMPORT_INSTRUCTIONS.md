# Import Existing Route53 Zone into Terraform

## Step 1: Create IAM User in AWS Console

1. Go to AWS Console → IAM → Users → Create User
2. User name: `terraform-admin`
3. Select "Provide user access to the AWS Management Console" - OPTIONAL (only if you want console access)
4. Click Next

## Step 2: Attach Permissions

1. Select "Attach policies directly"
2. Click "Create policy"
3. Select JSON tab
4. Paste the contents of `iam-policy.json` (in this directory)
5. Click Next
6. Name: `TerraformLandingcomAdmin`
7. Click "Create policy"
8. Go back to user creation, refresh policies, search for `TerraformLandingcomAdmin`
9. Check the box next to it
10. Click "Create user"

## Step 3: Create Access Keys

1. Click on the newly created user
2. Go to "Security credentials" tab
3. Scroll down to "Access keys"
4. Click "Create access key"
5. Select "Command Line Interface (CLI)"
6. Check the confirmation box
7. Click "Create access key"
8. **IMPORTANT:** Save both the Access Key ID and Secret Access Key (you can't see the secret again)

## Step 4: Configure AWS CLI

Run this in your terminal:

```bash
aws configure --profile terraform-admin
```

Enter:
- AWS Access Key ID: [paste from Step 3]
- AWS Secret Access Key: [paste from Step 3]
- Default region name: us-east-1
- Default output format: json

## Step 5: Find Your Existing Route53 Hosted Zone ID

```bash
aws route53 list-hosted-zones --profile terraform-admin
```

Look for the zone with domain `landing.com` and copy the zone ID (format: `/hostedzone/Z1234567890ABC`)

## Step 6: Prepare Terraform

```bash
cd /tmp/landingcom
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
```
domain_name = "landing.com"
```

## Step 7: Initialize Terraform (WITHOUT Backend)

Since the S3 bucket and DynamoDB table don't exist yet, we'll initialize without backend first:

```bash
terraform init
```

## Step 8: Import the Existing Hosted Zone

Replace `Z1234567890ABC` with your actual zone ID:

```bash
export AWS_PROFILE=terraform-admin
terraform import aws_route53_zone.main Z1234567890ABC
```

## Step 9: Review What Terraform Will Do

```bash
terraform plan
```

This will show:
- Existing Route53 zone: No changes (already imported)
- ACM certificate: Will be created
- S3 bucket: Will be created
- DynamoDB table: Will be created
- IAM user: Will be created

**IMPORTANT:** Review the Route53 records section. Terraform should NOT try to delete or modify existing DNS records for landing.com. If it does, we need to adjust the config.

## Step 10: Apply (When Ready)

```bash
terraform apply
```

Type `yes` to confirm.

## Step 11: Migrate to Remote Backend

After the S3 bucket and DynamoDB table are created, we can migrate state to remote backend:

1. Uncomment the `backend "s3"` block in `main.tf`
2. Run:
```bash
terraform init -migrate-state
```
3. Type `yes` to confirm migration

## Troubleshooting

**If you get "zone already exists":**
- Make sure you ran `terraform import` first
- Check `terraform.tfstate` to see if the zone is already tracked

**If Terraform wants to delete DNS records:**
- We need to import those records individually or add `lifecycle { ignore_changes }` rules
- Let me know which records it wants to delete

**If you don't have an existing hosted zone:**
- Skip Step 8
- Terraform will create a new hosted zone
- You'll need to update your domain registrar with the new nameservers
