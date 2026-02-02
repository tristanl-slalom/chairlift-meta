#!/bin/bash
set -e

# Validate Configuration Script
# Validates services.yaml for correctness

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/services.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Initialize
log_section "Configuration Validation"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")

# Load configuration
if ! config_init "$META_REPO_ROOT"; then
    log_error "Cannot validate: no configuration file found"
    exit 1
fi

log_info "Validating: $CONFIG_FILE"
log_info "Format: $CONFIG_TYPE"
echo ""

ERRORS=0

# Check required tools
log_info "Checking required tools..."
if [ "$CONFIG_TYPE" = "yaml" ]; then
    if require_command "yq" "Install with: brew install yq"; then
        log_check "yq installed"
    else
        ERRORS=$((ERRORS + 1))
    fi
fi

if require_command "jq" "Install with: brew install jq"; then
    log_check "jq installed"
else
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Validate project name
log_info "Validating project configuration..."
PROJECT_NAME=$(config_get_project_name)
if [ -z "$PROJECT_NAME" ]; then
    log_error "Project name is missing"
    ERRORS=$((ERRORS + 1))
else
    log_check "Project name: $PROJECT_NAME"
fi

GITHUB_ORG=$(config_get_github_org)
if [ -z "$GITHUB_ORG" ]; then
    log_error "GitHub organization is missing"
    ERRORS=$((ERRORS + 1))
else
    log_check "GitHub organization: $GITHUB_ORG"
fi
echo ""

# Validate services
log_info "Validating services..."
SERVICE_COUNT=$(config_service_count)
if [ "$SERVICE_COUNT" -eq 0 ]; then
    log_error "No services defined"
    ERRORS=$((ERRORS + 1))
    exit 1
fi

log_check "Found $SERVICE_COUNT services"
echo ""

# Check each service
while IFS= read -r service; do
    log_info "Validating service: $service"

    # Check required fields
    type=$(config_get_service_type "$service")
    if [ -z "$type" ]; then
        log_error "  Missing type"
        ERRORS=$((ERRORS + 1))
    else
        log_check "  Type: $type"
    fi

    short_name=$(config_get_service_short_name "$service")
    if [ -z "$short_name" ]; then
        log_error "  Missing short name"
        ERRORS=$((ERRORS + 1))
    else
        log_check "  Short name: $short_name"
    fi

    order=$(config_get_service_order "$service")
    if [ -z "$order" ]; then
        log_error "  Missing deployment order"
        ERRORS=$((ERRORS + 1))
    else
        log_check "  Deployment order: $order"
    fi

    repo_url=$(config_get_service_repo_url "$service" "$GITHUB_ORG")
    if [ -z "$repo_url" ]; then
        log_error "  Missing repository URL"
        ERRORS=$((ERRORS + 1))
    else
        log_check "  Repository URL: $repo_url"
    fi

    echo ""
done < <(config_list_services)

# Validate dependencies
log_info "Validating dependencies..."
if validate_dependencies; then
    log_check "All dependencies valid"
else
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check for duplicate deployment orders
log_info "Checking for duplicate deployment orders..."
DUPLICATE_ORDERS=$(while IFS= read -r service; do
    config_get_service_order "$service"
done < <(config_list_services) | sort | uniq -d)

if [ -n "$DUPLICATE_ORDERS" ]; then
    log_error "Duplicate deployment orders found: $DUPLICATE_ORDERS"
    ERRORS=$((ERRORS + 1))
else
    log_check "No duplicate deployment orders"
fi
echo ""

# Summary
log_section "Validation Summary"

if [ $ERRORS -eq 0 ]; then
    log_success "✓ Configuration is valid!"
    log_info "Services in deployment order:"
    list_services
    exit 0
else
    log_error "✗ Configuration has $ERRORS error(s)"
    exit 1
fi
