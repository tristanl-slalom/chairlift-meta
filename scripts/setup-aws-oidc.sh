#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Initialize configuration
config_init "$(dirname "$SCRIPT_DIR")"

AWS_REGION="${AWS_REGION:-us-west-2}"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AWS OIDC Setup for GitHub Actions${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Get AWS account ID
log_info "Getting AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    log_error "Failed to get AWS account ID. Make sure AWS CLI is configured."
    exit 1
fi

log_success "AWS Account ID: $AWS_ACCOUNT_ID"
log_info "AWS Region: $AWS_REGION"
echo ""

# Get GitHub organization from config
GITHUB_ORG=$(yq eval '.project.github.organization' services.yaml 2>/dev/null)
if [ -z "$GITHUB_ORG" ] || [ "$GITHUB_ORG" = "null" ]; then
    log_error "GitHub organization not found in services.yaml"
    exit 1
fi

log_info "GitHub Organization: $GITHUB_ORG"
echo ""

# Create OIDC provider
log_info "Creating OIDC provider..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 2>/dev/null \
  && log_success "OIDC provider created" \
  || log_info "OIDC provider already exists"
echo ""

# Process each service
while IFS= read -r service_name; do
    log_info "Setting up $service_name..."

    # Convert service name to role name (e.g., chairlift-be-flights -> ChairliftFlights)
    # Remove hyphens and capitalize each word
    ROLE_NAME="GitHubActions-$(echo "$service_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' | sed 's/ //g')"

    # Create trust policy
    cat > /tmp/trust-policy-$service_name.json <<EOF
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
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${service_name}:*"
        }
      }
    }
  ]
}
EOF

    # Create role
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "file:///tmp/trust-policy-$service_name.json" 2>/dev/null \
        && log_success "Created role $ROLE_NAME" \
        || log_info "Role $ROLE_NAME already exists"

    # Attach policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/PowerUserAccess 2>/dev/null || true

    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

    # Set GitHub secrets
    log_info "Setting GitHub secrets for ${GITHUB_ORG}/${service_name}..."
    gh secret set AWS_ROLE_ARN --repo "${GITHUB_ORG}/${service_name}" --body "$ROLE_ARN" 2>/dev/null \
        && log_success "Set AWS_ROLE_ARN" \
        || log_error "Failed to set AWS_ROLE_ARN"

    gh secret set AWS_REGION --repo "${GITHUB_ORG}/${service_name}" --body "$AWS_REGION" 2>/dev/null \
        && log_success "Set AWS_REGION" \
        || log_error "Failed to set AWS_REGION"

    # Create production environment
    gh api "repos/${GITHUB_ORG}/${service_name}/environments/production" -X PUT 2>/dev/null \
        && log_success "Created production environment" \
        || log_info "Production environment already exists"

    log_success "✓ $service_name configured (Role: $ROLE_ARN)"
    echo ""

    # Cleanup
    rm -f "/tmp/trust-policy-$service_name.json"

done < <(get_services_in_order)

log_success "✅ All services configured!"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Push code to main branch to trigger deployment"
echo "  2. Check GitHub Actions tab to monitor deployment"
echo "  3. View CloudFormation stacks in AWS Console"
