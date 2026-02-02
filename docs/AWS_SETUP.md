# AWS Setup Guide for Chairlift Platform

This guide explains how to configure AWS credentials for automated deployments using GitHub Actions.

## Overview

All Chairlift services use **OIDC (OpenID Connect)** for secure AWS authentication from GitHub Actions. This approach:
- ✅ No long-lived AWS access keys
- ✅ Automatic credential rotation
- ✅ Fine-grained permissions per service
- ✅ Audit trail in CloudTrail

## Prerequisites

- AWS Account with administrator access
- GitHub repository access
- AWS CLI installed and configured

## Step 1: Create OIDC Identity Provider in AWS

Run this **once per AWS account** (not per service):

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Verify it exists:**
```bash
aws iam list-open-id-connect-providers
```

## Step 2: Create IAM Role for Each Service

Each service needs its own IAM role with specific permissions. Create one role per service:

### A. Flights Service Role

```bash
# Create trust policy
cat > trust-policy-flights.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:tristanl-slalom/chairlift-be-flights:*"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name GitHubActions-ChairliftFlights \
  --assume-role-policy-document file://trust-policy-flights.json

# Attach policies (adjust as needed)
aws iam attach-role-policy \
  --role-name GitHubActions-ChairliftFlights \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Note the role ARN
aws iam get-role \
  --role-name GitHubActions-ChairliftFlights \
  --query 'Role.Arn' \
  --output text
```

### B. Customers Service Role

```bash
cat > trust-policy-customers.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:tristanl-slalom/chairlift-be-customers:*"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name GitHubActions-ChairliftCustomers \
  --assume-role-policy-document file://trust-policy-customers.json

aws iam attach-role-policy \
  --role-name GitHubActions-ChairliftCustomers \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

### C. Bookings Service Role

```bash
cat > trust-policy-bookings.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:tristanl-slalom/chairlift-be-bookings:*"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name GitHubActions-ChairliftBookings \
  --assume-role-policy-document file://trust-policy-bookings.json

aws iam attach-role-policy \
  --role-name GitHubActions-ChairliftBookings \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

### D. BFF Service Role

```bash
cat > trust-policy-bff.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:tristanl-slalom/chairlift-bff:*"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name GitHubActions-ChairliftBFF \
  --assume-role-policy-document file://trust-policy-bff.json

aws iam attach-role-policy \
  --role-name GitHubActions-ChairliftBFF \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

### E. Frontend Service Role

```bash
cat > trust-policy-fe.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:tristanl-slalom/chairlift-fe:*"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name GitHubActions-ChairliftFrontend \
  --assume-role-policy-document file://trust-policy-fe.json

aws iam attach-role-policy \
  --role-name GitHubActions-ChairliftFrontend \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

## Step 3: Configure GitHub Secrets

For **each repository**, add these secrets:

### Via GitHub Web UI

1. Go to repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add these secrets:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `AWS_ROLE_ARN` | IAM Role ARN | `arn:aws:iam::123456789012:role/GitHubActions-ChairliftFlights` |
| `AWS_REGION` | AWS Region | `us-west-2` |

### Via GitHub CLI

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Set region (change as needed)
AWS_REGION="us-west-2"

# Flights
gh secret set AWS_ROLE_ARN \
  --repo tristanl-slalom/chairlift-be-flights \
  --body "arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActions-ChairliftFlights"
gh secret set AWS_REGION \
  --repo tristanl-slalom/chairlift-be-flights \
  --body "${AWS_REGION}"

# Customers
gh secret set AWS_ROLE_ARN \
  --repo tristanl-slalom/chairlift-be-customers \
  --body "arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActions-ChairliftCustomers"
gh secret set AWS_REGION \
  --repo tristanl-slalom/chairlift-be-customers \
  --body "${AWS_REGION}"

# Bookings
gh secret set AWS_ROLE_ARN \
  --repo tristanl-slalom/chairlift-be-bookings \
  --body "arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActions-ChairliftBookings"
gh secret set AWS_REGION \
  --repo tristanl-slalom/chairlift-be-bookings \
  --body "${AWS_REGION}"

# BFF
gh secret set AWS_ROLE_ARN \
  --repo tristanl-slalom/chairlift-bff \
  --body "arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActions-ChairliftBFF"
gh secret set AWS_REGION \
  --repo tristanl-slalom/chairlift-bff \
  --body "${AWS_REGION}"

# Frontend
gh secret set AWS_ROLE_ARN \
  --repo tristanl-slalom/chairlift-fe \
  --body "arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActions-ChairliftFrontend"
gh secret set AWS_REGION \
  --repo tristanl-slalom/chairlift-fe \
  --body "${AWS_REGION}"
```

## Step 4: Verify Configuration

```bash
# Check secrets are set (you won't see values, just names)
gh secret list --repo tristanl-slalom/chairlift-be-flights
gh secret list --repo tristanl-slalom/chairlift-be-customers
gh secret list --repo tristanl-slalom/chairlift-be-bookings
gh secret list --repo tristanl-slalom/chairlift-bff
gh secret list --repo tristanl-slalom/chairlift-fe
```

## Step 5: Create GitHub Environments

Each repository needs a `production` environment for deployment protection:

```bash
# Create production environment for each repo
for repo in chairlift-be-flights chairlift-be-customers chairlift-be-bookings chairlift-bff chairlift-fe; do
  gh api repos/tristanl-slalom/${repo}/environments/production -X PUT
done
```

**Optional**: Add environment protection rules via GitHub UI:
- Settings → Environments → production
- Add required reviewers
- Add deployment branches (e.g., only `main`)

## Step 6: Trigger Deployments

Push to `main` branch to trigger automatic deployment:

```bash
cd repos/chairlift-be-flights
git push origin main
# Check GitHub Actions tab in repository
```

Or manually trigger:

```bash
gh workflow run cd.yml --repo tristanl-slalom/chairlift-be-flights
```

## Automated Setup Script

Save this as `setup-aws-oidc.sh` in the meta repo:

```bash
#!/bin/bash
set -e

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="${AWS_REGION:-us-west-2}"

echo "Setting up AWS OIDC for GitHub Actions"
echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"

# Services array
SERVICES=("chairlift-be-flights" "chairlift-be-customers" "chairlift-be-bookings" "chairlift-bff" "chairlift-fe")
ROLE_NAMES=("GitHubActions-ChairliftFlights" "GitHubActions-ChairliftCustomers" "GitHubActions-ChairliftBookings" "GitHubActions-ChairliftBFF" "GitHubActions-ChairliftFrontend")

# Create OIDC provider (if not exists)
echo "Creating OIDC provider..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 2>/dev/null || echo "OIDC provider already exists"

# Create roles and set secrets for each service
for i in "${!SERVICES[@]}"; do
  SERVICE="${SERVICES[$i]}"
  ROLE_NAME="${ROLE_NAMES[$i]}"

  echo ""
  echo "Setting up $SERVICE..."

  # Create trust policy
  cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:tristanl-slalom/${SERVICE}:*"
        }
      }
    }
  ]
}
EOF

  # Create role
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/trust-policy.json 2>/dev/null || echo "Role $ROLE_NAME already exists"

  # Attach policy
  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/PowerUserAccess 2>/dev/null || true

  # Get role ARN
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

  # Set GitHub secrets
  gh secret set AWS_ROLE_ARN --repo "tristanl-slalom/${SERVICE}" --body "$ROLE_ARN"
  gh secret set AWS_REGION --repo "tristanl-slalom/${SERVICE}" --body "$AWS_REGION"

  # Create production environment
  gh api "repos/tristanl-slalom/${SERVICE}/environments/production" -X PUT || true

  echo "✓ $SERVICE configured with role: $ROLE_ARN"
done

rm /tmp/trust-policy.json
echo ""
echo "✅ All services configured!"
```

Make it executable and run:

```bash
chmod +x setup-aws-oidc.sh
./setup-aws-oidc.sh
```

## Troubleshooting

### Error: "No OIDC provider found"

Create the OIDC provider first (Step 1).

### Error: "User is not authorized to perform: sts:AssumeRoleWithWebIdentity"

Check the trust policy includes correct repository name and OIDC provider ARN.

### Error: "Unable to locate credentials"

Verify GitHub secrets are set correctly and environment is named `production`.

### Error: "Access Denied" during CDK deploy

The IAM role needs broader permissions. Consider using `AdministratorAccess` for initial setup, then restrict later.

## Security Best Practices

1. **Use least privilege**: Replace `PowerUserAccess` with custom policies
2. **Separate environments**: Use different AWS accounts for dev/staging/prod
3. **Enable CloudTrail**: Monitor all API calls
4. **Rotate credentials**: OIDC handles this automatically
5. **Review permissions**: Regularly audit IAM roles

## Summary

After completing this setup:
- ✅ OIDC provider created in AWS
- ✅ IAM role per service with trust policy
- ✅ GitHub secrets configured for each repo
- ✅ Production environment created
- ✅ Automatic deployment on push to main

All services will automatically deploy to AWS when code is pushed to the `main` branch.
