#!/bin/bash
set -e

# Create Feature Branch Script
# Creates a new feature branch across service repositories

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Check if branch name provided
if [ -z "$1" ]; then
    log_error "Branch name required"
    echo ""
    echo "Usage: ./create-feature-branch.sh <branch-name> [repos]"
    echo ""
    echo "Examples:"
    echo "  ./create-feature-branch.sh feature/new-api"
    echo "  ./create-feature-branch.sh feature/new-api tasks,bff"
    echo ""
    echo "Available repos: tasks, bff, fe (default: all)"
    exit 1
fi

BRANCH_NAME=$1
REPOS_TO_UPDATE=${2:-"all"}

# Validate branch name
validate_branch_name "$BRANCH_NAME" || exit 1

# Initialize
log_section "Creating Feature Branch: $BRANCH_NAME"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")
REPOS_DIR=$(get_workspace_dir "$META_REPO_ROOT")

# Check if repos directory exists
require_directory "$REPOS_DIR" || {
    log_info "Run ./setup-workspace.sh first"
    exit 1
}

# Load configuration
config_init "$META_REPO_ROOT" || exit 1

# Function to create branch in a repo
create_branch() {
    local service_name=$1
    local short_name=$(config_get_service_short_name "$service_name")
    local repo_path="$REPOS_DIR/$service_name"

    if [ ! -d "$repo_path" ]; then
        log_warn "⚠ $service_name not found, skipping"
        return
    fi

    log_info "Processing $service_name..."
    cd "$repo_path"

    # Ensure we're on main and up to date
    git checkout main 2>/dev/null || git checkout master 2>/dev/null
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null

    # Check if branch already exists locally
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        log_warn "  Branch already exists locally, checking out"
        git checkout "$BRANCH_NAME"
    else
        # Check if branch exists on remote
        if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
            log_warn "  Branch exists on remote, checking out"
            git checkout -b "$BRANCH_NAME" "origin/$BRANCH_NAME"
        else
            log_success "  Creating new branch"
            git checkout -b "$BRANCH_NAME"
        fi
    fi

    log_check "$service_name ready on branch $BRANCH_NAME"
    echo ""
}

# Determine which repos to update
if [ "$REPOS_TO_UPDATE" = "all" ]; then
    # Create branch in all repos
    while IFS= read -r service; do
        create_branch "$service"
    done < <(config_list_services)
else
    # Parse specific repos
    IFS=',' read -ra SHORT_NAMES <<< "$REPOS_TO_UPDATE"

    for short_name in "${SHORT_NAMES[@]}"; do
        # Find service by short name
        while IFS= read -r service; do
            svc_short=$(config_get_service_short_name "$service")
            if [ "$svc_short" = "$short_name" ]; then
                create_branch "$service"
                break
            fi
        done < <(config_list_services)
    done
fi

# Return to meta repo
cd "$META_REPO_ROOT"

log_section "Feature branches created!"

log_info "Next steps:"
log_bullet "Make changes in repos/ directory"
log_bullet "Commit and push changes"
log_bullet "Use push-feature-branch.sh to push to remote"
echo ""
