#!/bin/bash
set -e

# Bootstrap Microservice Script
# Creates a new microservice from template with full automation

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/github.sh"
source "$SCRIPT_DIR/lib/services.sh"
source "$SCRIPT_DIR/lib/validation.sh"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")

# Usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap a new microservice for the Chairlift platform.

Options:
    -n, --name NAME         Service name (e.g., users, notifications)
    -t, --type TYPE         Service type (backend or frontend)
    -d, --desc DESC         Service description
    --deps SERVICES         Comma-separated list of dependencies
    --config FILE           Use config file instead of interactive mode
    -h, --help              Show this help message

Interactive Mode (no options):
    ./scripts/bootstrap-microservice.sh

Config-Driven Mode:
    ./scripts/bootstrap-microservice.sh --config bootstrap-config.yaml

Examples:
    # Interactive
    ./scripts/bootstrap-microservice.sh

    # Command line
    ./scripts/bootstrap-microservice.sh -n users -t backend -d "User management service"

    # With dependencies
    ./scripts/bootstrap-microservice.sh -n notifications -t backend --deps tasks,users
EOF
}

# Parse command line arguments
SERVICE_NAME=""
SERVICE_TYPE=""
SERVICE_DESC=""
SERVICE_DEPS=""
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -t|--type)
            SERVICE_TYPE="$2"
            shift 2
            ;;
        -d|--desc)
            SERVICE_DESC="$2"
            shift 2
            ;;
        --deps)
            SERVICE_DEPS="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

log_box "Microservice Bootstrap"

# Load main configuration
config_init "$META_REPO_ROOT" || exit 1
GITHUB_ORG=$(config_get_github_org)

# Interactive mode if no arguments
if [ -z "$SERVICE_NAME" ] && [ -z "$CONFIG_FILE" ]; then
    log_header "Interactive Mode"
    echo ""

    # Get service name
    while true; do
        read -p "Service short name (e.g., users, notifications): " SERVICE_NAME
        if validate_service_name "$SERVICE_NAME" 2>/dev/null; then
            break
        else
            log_error "Invalid service name. Use lowercase letters, numbers, and hyphens only."
        fi
    done

    # Get service type
    while true; do
        read -p "Service type (backend/frontend): " SERVICE_TYPE
        if [ "$SERVICE_TYPE" = "backend" ] || [ "$SERVICE_TYPE" = "frontend" ]; then
            break
        else
            log_error "Invalid type. Choose 'backend' or 'frontend'."
        fi
    done

    # Get description
    read -p "Service description: " SERVICE_DESC

    # Get dependencies
    log_info "Available services:"
    while IFS= read -r service; do
        short=$(config_get_service_short_name "$service")
        log_bullet "$short ($service)"
    done < <(get_services_in_order)
    echo ""
    read -p "Dependencies (comma-separated short names, or press Enter for none): " SERVICE_DEPS
fi

# Validate inputs
validate_service_name "$SERVICE_NAME" || exit 1

if [ "$SERVICE_TYPE" != "backend" ] && [ "$SERVICE_TYPE" != "frontend" ]; then
    log_error "Service type must be 'backend' or 'frontend'"
    exit 1
fi

# Construct full service name
FULL_SERVICE_NAME="chairlift-be-${SERVICE_NAME}"
if [ "$SERVICE_TYPE" = "frontend" ]; then
    FULL_SERVICE_NAME="chairlift-fe-${SERVICE_NAME}"
fi

# Check if service already exists
if service_exists "$FULL_SERVICE_NAME"; then
    log_error "Service '$FULL_SERVICE_NAME' already exists in configuration"
    exit 1
fi

# Summary
echo ""
log_header "Service Configuration"
log_info "Full name: $FULL_SERVICE_NAME"
log_info "Short name: $SERVICE_NAME"
log_info "Type: $SERVICE_TYPE"
log_info "Description: $SERVICE_DESC"
if [ -n "$SERVICE_DEPS" ]; then
    log_info "Dependencies: $SERVICE_DEPS"
else
    log_info "Dependencies: none"
fi
echo ""

if ! confirm "Create this service?" "y"; then
    log_info "Cancelled"
    exit 0
fi

# Determine template source
TEMPLATE_SOURCE="chairlift-be-tasks"
if [ "$SERVICE_TYPE" = "frontend" ]; then
    TEMPLATE_SOURCE="chairlift-fe"
fi

TEMPLATE_PATH="$META_REPO_ROOT/repos/$TEMPLATE_SOURCE"
NEW_SERVICE_PATH="$META_REPO_ROOT/repos/$FULL_SERVICE_NAME"

# Check if template exists
if [ ! -d "$TEMPLATE_PATH" ]; then
    log_error "Template not found: $TEMPLATE_PATH"
    log_info "Run ./scripts/setup-workspace.sh first"
    exit 1
fi

# Step 1: Clone template
log_step "1" "6" "Cloning template from $TEMPLATE_SOURCE..."
if [ -d "$NEW_SERVICE_PATH" ]; then
    log_error "Directory already exists: $NEW_SERVICE_PATH"
    exit 1
fi

cp -r "$TEMPLATE_PATH" "$NEW_SERVICE_PATH"
cd "$NEW_SERVICE_PATH"

# Remove git history
rm -rf .git

log_check "Template cloned"
echo ""

# Step 2: Process template replacements
log_step "2" "6" "Processing template replacements..."

# Convert service name to PascalCase for class names (e.g., "user-auth" -> "UserAuth")
to_pascal_case() {
    echo "$1" | awk -F'-' '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1' OFS=''
}
SERVICE_NAME_PASCAL=$(to_pascal_case "$SERVICE_NAME")

# Define replacements
if [ "$SERVICE_TYPE" = "backend" ]; then
    # Backend replacements
    declare -A REPLACEMENTS=(
        ["chairlift-be-tasks"]="$FULL_SERVICE_NAME"
        ["chairlift-tasks"]="chairlift-${SERVICE_NAME}"
        ["ChairliftTasksServiceStack"]="Chairlift${SERVICE_NAME_PASCAL}ServiceStack"
        ["TasksServiceStack"]="${SERVICE_NAME_PASCAL}ServiceStack"
        ["tasks-service-stack"]="${SERVICE_NAME}-service-stack"
        ["Tasks microservice"]="$SERVICE_DESC"
        ["ChairliftTasksApiUrl"]="Chairlift${SERVICE_NAME_PASCAL}ApiUrl"
    )
else
    # Frontend replacements
    declare -A REPLACEMENTS=(
        ["chairlift-fe"]="$FULL_SERVICE_NAME"
        ["ChairliftFrontendStack"]="Chairlift${SERVICE_NAME_PASCAL}Stack"
        ["Chairlift Frontend"]="$SERVICE_DESC"
    )
fi

# Replace in all files
log_info "Replacing placeholders..."
for old in "${!REPLACEMENTS[@]}"; do
    new="${REPLACEMENTS[$old]}"

    # Find and replace in files (using perl for cross-platform compatibility)
    find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.json" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" \) -exec perl -i -pe "s/\Q$old\E/$new/g" {} +

    log_info "  $old → $new"
done

# Rename files if needed
if [ "$SERVICE_TYPE" = "backend" ]; then
    if [ -f "infrastructure/lib/tasks-service-stack.ts" ]; then
        mv "infrastructure/lib/tasks-service-stack.ts" "infrastructure/lib/${SERVICE_NAME}-service-stack.ts"
        log_info "Renamed stack file"
    fi
fi

log_check "Template processed"
echo ""

# Step 3: Update services.yaml
log_step "3" "6" "Updating services.yaml..."

cd "$META_REPO_ROOT"

# Get next deployment order
MAX_ORDER=0
while IFS= read -r service; do
    order=$(config_get_service_order "$service")
    if [ "$order" -gt "$MAX_ORDER" ]; then
        MAX_ORDER=$order
    fi
done < <(config_list_services)
NEW_ORDER=$((MAX_ORDER + 1))

# Parse dependencies
DEPS_YAML=""
if [ -n "$SERVICE_DEPS" ]; then
    IFS=',' read -ra DEPS_ARRAY <<< "$SERVICE_DEPS"
    DEPS_YAML="    dependencies:"
    for dep_short in "${DEPS_ARRAY[@]}"; do
        # Find full service name
        while IFS= read -r service; do
            svc_short=$(config_get_service_short_name "$service")
            if [ "$svc_short" = "$dep_short" ]; then
                DEPS_YAML="${DEPS_YAML}
      - \"$service\""
                break
            fi
        done < <(config_list_services)
    done
else
    DEPS_YAML="    dependencies: []"
fi

# Append new service to services.yaml
cat >> services.yaml << EOF

  - name: "$FULL_SERVICE_NAME"
    type: "$SERVICE_TYPE"
    description: "$SERVICE_DESC"
    repository:
      url: "git@github.com:{org}/$FULL_SERVICE_NAME.git"
      short_name: "$SERVICE_NAME"
$DEPS_YAML
    exports:
      - name: "Chairlift${SERVICE_NAME_PASCAL}ApiUrl"
        description: "API Gateway URL for $SERVICE_NAME service"
    deployment:
      order: $NEW_ORDER
      runtime: "nodejs20.x"
      framework: "aws-cdk"
EOF

log_check "services.yaml updated"
echo ""

# Step 4: Validate configuration
log_step "4" "6" "Validating configuration..."
if ./scripts/validate-config.sh > /dev/null 2>&1; then
    log_check "Configuration valid"
else
    log_error "Configuration validation failed"
    log_info "Reverting changes to services.yaml..."
    git checkout services.yaml
    rm -rf "$NEW_SERVICE_PATH"
    exit 1
fi
echo ""

# Step 5: Initialize git repository
log_step "5" "6" "Initializing git repository..."
cd "$NEW_SERVICE_PATH"

git init --quiet
git add .
git commit -m "Initial commit: Bootstrap $FULL_SERVICE_NAME

Generated from template: $TEMPLATE_SOURCE
Service type: $SERVICE_TYPE
Description: $SERVICE_DESC

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" --quiet

log_check "Git repository initialized"
echo ""

# Step 6: Create GitHub repository
log_step "6" "6" "Creating GitHub repository..."

if require_gh_cli; then
    REPO_URL="git@github.com:${GITHUB_ORG}/${FULL_SERVICE_NAME}.git"

    if repo_exists "$GITHUB_ORG" "$FULL_SERVICE_NAME"; then
        log_warn "Repository already exists on GitHub"
    else
        log_info "Creating GitHub repository..."
        gh repo create "${GITHUB_ORG}/${FULL_SERVICE_NAME}" \
            --public \
            --description "$SERVICE_DESC" \
            --source=. \
            --remote=origin \
            --push

        log_check "GitHub repository created and pushed"
    fi
else
    log_warn "gh CLI not available - skipping GitHub repo creation"
    log_info "Create repository manually:"
    log_info "  gh repo create ${GITHUB_ORG}/${FULL_SERVICE_NAME} --public"
    log_info "  git remote add origin git@github.com:${GITHUB_ORG}/${FULL_SERVICE_NAME}.git"
    log_info "  git push -u origin main"
fi

cd "$META_REPO_ROOT"
echo ""

# Success!
log_section "Service Bootstrap Complete!"

log_header "What was created:"
log_bullet "Service directory: repos/$FULL_SERVICE_NAME"
log_bullet "Configuration: services.yaml (updated)"
log_bullet "GitHub repository: https://github.com/${GITHUB_ORG}/${FULL_SERVICE_NAME}"
echo ""

log_header "Next steps:"
log_bullet "Review the generated service code"
log_bullet "Update README.md with service-specific details"
log_bullet "Customize handlers and business logic"
log_bullet "Update infrastructure/lib/${SERVICE_NAME}-service-stack.ts"
log_bullet "Test locally: cd repos/$FULL_SERVICE_NAME && npm install && npm test"
log_bullet "Deploy: cd repos/$FULL_SERVICE_NAME && npm run cdk:deploy"
echo ""

log_header "Integration:"
log_bullet "Service is registered in services.yaml"
log_bullet "All automation scripts will now include this service"
log_bullet "Run ./scripts/setup-workspace.sh to clone in other workspaces"
log_bullet "Use ./scripts/create-feature-branch.sh to include in feature work"
echo ""

log_success "🎉 New microservice '$FULL_SERVICE_NAME' is ready!"
