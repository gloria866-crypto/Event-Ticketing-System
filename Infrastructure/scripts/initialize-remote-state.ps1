# initialize-remote-state.ps1
# Run this ONCE locally before the first GitHub Actions deployment.
# Prerequisites: AWS CLI configured with sufficient IAM permissions.

$ACCOUNT_ID  = (aws sts get-caller-identity --query Account --output text)
$REGION      = "us-east-1"
$BUCKET_NAME = "event-ticketing-terraform-state-$ACCOUNT_ID"

Write-Host "Account : $ACCOUNT_ID"
Write-Host "Bucket  : $BUCKET_NAME"
Write-Host "Region  : $REGION"
Write-Host ""

# ── 1. Create S3 bucket ───────────────────────────────────────────────────────
Write-Host "Creating S3 state bucket..."
aws s3api create-bucket `
    --bucket $BUCKET_NAME `
    --region $REGION

# Enable versioning so every state change is recoverable
aws s3api put-bucket-versioning `
    --bucket $BUCKET_NAME `
    --versioning-configuration Status=Enabled

# Enable AES-256 encryption at rest
aws s3api put-bucket-encryption `
    --bucket $BUCKET_NAME `
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Block all public access
aws s3api put-public-access-block `
    --bucket $BUCKET_NAME `
    --public-access-block-configuration `
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

Write-Host "S3 bucket ready."

# ── 2. Migrate local state to S3 ─────────────────────────────────────────────
Write-Host "Migrating local Terraform state to S3..."
Set-Location "$PSScriptRoot\.."

terraform init -migrate-state -force-copy

Write-Host ""
Write-Host "Remote state setup complete."
Write-Host "Bucket : s3://$BUCKET_NAME"
Write-Host ""
Write-Host "You can now push to main and GitHub Actions will use the shared remote state."
