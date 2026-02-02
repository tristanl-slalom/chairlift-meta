#!/bin/bash
set -e

# Migrate Configuration Script
# Migrates from legacy .openspec/config.json to services.yaml

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Initialize
log_section "Configuration Migration"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")
LEGACY_CONFIG="$META_REPO_ROOT/.openspec/config.json"
NEW_CONFIG="$META_REPO_ROOT/services.yaml"

# Check if new config already exists
if [ -f "$NEW_CONFIG" ]; then
    log_warn "services.yaml already exists"
    if ! confirm "Overwrite existing services.yaml?" "n"; then
        log_info "Migration cancelled"
        exit 0
    fi
    log_info "Creating backup..."
    cp "$NEW_CONFIG" "$NEW_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Check if legacy config exists
if [ ! -f "$LEGACY_CONFIG" ]; then
    log_error "Legacy config not found: $LEGACY_CONFIG"
    exit 1
fi

log_info "Migrating from: $LEGACY_CONFIG"
log_info "To: $NEW_CONFIG"
echo ""

# Check for jq
require_command "jq" "Install with: brew install jq" || exit 1

# Read legacy config
log_info "Reading legacy configuration..."

PROJECT_NAME=$(jq -r '.project.name' "$LEGACY_CONFIG")
GITHUB_ORG=$(jq -r '.github.organization' "$LEGACY_CONFIG")

log_info "Project: $PROJECT_NAME"
log_info "GitHub org: $GITHUB_ORG"
echo ""

# Create new config
log_info "Creating services.yaml..."

cat > "$NEW_CONFIG" << 'EOF'
version: "2.0"

project:
  name: "Chairlift"
  description: "Serverless task management application"
  github:
    organization: "tristanl-slalom"
    project:
      number: 1
      name: "Chairlift Development"

services:
  - name: "chairlift-be-tasks"
    type: "backend"
    description: "Tasks microservice"
    repository:
      url: "git@github.com:{org}/chairlift-be-tasks.git"
      short_name: "tasks"
    dependencies: []
    exports:
      - name: "ChairliftTasksApiUrl"
        description: "API Gateway URL for Tasks service"
    deployment:
      order: 1
      runtime: "nodejs20.x"
      framework: "aws-cdk"
      database: "dynamodb"

  - name: "chairlift-bff"
    type: "backend"
    description: "Backend for Frontend"
    repository:
      url: "git@github.com:{org}/chairlift-bff.git"
      short_name: "bff"
    dependencies:
      - "chairlift-be-tasks"
    imports:
      - name: "ChairliftTasksApiUrl"
        from: "chairlift-be-tasks"
    exports:
      - name: "ChairliftBFFApiUrl"
        description: "API Gateway URL for BFF service"
    deployment:
      order: 2
      runtime: "nodejs20.x"
      framework: "aws-cdk"

  - name: "chairlift-fe"
    type: "frontend"
    description: "React frontend"
    repository:
      url: "git@github.com:{org}/chairlift-fe.git"
      short_name: "fe"
    dependencies:
      - "chairlift-bff"
    imports:
      - name: "ChairliftBFFApiUrl"
        from: "chairlift-bff"
    deployment:
      order: 3
      runtime: "nodejs20.x"
      framework: "react"
      bundler: "vite"
      hosting: "s3-cloudfront"

workspace:
  root_dir: "repos"
  feature_root: "features/workspaces"

testing:
  backend:
    framework: "jest"
    coverage_threshold: 80
  frontend:
    framework: "vitest"
    library: "react-testing-library"
    coverage_threshold: 80
EOF

# Update with actual values from legacy config
if command -v yq &> /dev/null; then
    yq eval -i ".project.name = \"$PROJECT_NAME\"" "$NEW_CONFIG"
    yq eval -i ".project.github.organization = \"$GITHUB_ORG\"" "$NEW_CONFIG"
    log_check "Updated project name and GitHub organization"
else
    log_warn "yq not installed - could not update values from legacy config"
    log_info "Install yq with: brew install yq"
    log_info "Then manually update project.name and project.github.organization"
fi

log_check "services.yaml created"
echo ""

# Validate new config
log_info "Validating new configuration..."
if [ -x "$SCRIPT_DIR/validate-config.sh" ]; then
    "$SCRIPT_DIR/validate-config.sh"
else
    log_warn "validate-config.sh not found or not executable"
fi

echo ""
log_section "Migration Complete!"

log_info "Next steps:"
log_bullet "Review services.yaml"
log_bullet "Test scripts with new configuration"
log_bullet "Legacy config remains at $LEGACY_CONFIG (safe to keep for rollback)"
log_bullet "All scripts will now use services.yaml by default"
echo ""

log_info "To rollback migration:"
log_bullet "rm services.yaml"
log_bullet "Scripts will automatically fall back to .openspec/config.json"
echo ""
