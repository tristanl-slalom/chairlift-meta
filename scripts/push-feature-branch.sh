#!/bin/bash
set -e

# Push Feature Branch Script
# Pushes feature branches to remote across service repositories

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
    echo "Usage: ./push-feature-branch.sh <branch-name> [repos] [--force]"
    echo ""
    echo "Examples:"
    echo "  ./push-feature-branch.sh feature/new-api"
    echo "  ./push-feature-branch.sh feature/new-api tasks,bff"
    echo "  ./push-feature-branch.sh feature/new-api all --force"
    echo ""
    echo "Available repos: tasks, bff, fe (default: all)"
    exit 1
fi

BRANCH_NAME=$1
REPOS_TO_PUSH=${2:-"all"}
FORCE_PUSH=${3:-""}

# Validate branch name
validate_branch_name "$BRANCH_NAME" || exit 1

# Initialize
log_section "Pushing Feature Branch: $BRANCH_NAME"

if [ "$FORCE_PUSH" == "--force" ]; then
    log_warn "⚠ Force push enabled"
    echo ""
fi

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")
REPOS_DIR=$(get_workspace_dir "$META_REPO_ROOT")

# Load configuration
config_init "$META_REPO_ROOT" || exit 1

# Get GitHub organization
GITHUB_ORG=$(config_get_github_org)

# Function to push branch in a repo
push_branch() {
    local service_name=$1
    local short_name=$(config_get_service_short_name "$service_name")
    local repo_path="$REPOS_DIR/$service_name"

    if [ ! -d "$repo_path" ]; then
        log_warn "⚠ $service_name not found, skipping"
        return
    fi

    log_info "Processing $service_name..."
    cd "$repo_path"

    # Check if on correct branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
        log_warn "  Not on branch $BRANCH_NAME (currently on $CURRENT_BRANCH), skipping"
        echo ""
        return
    fi

    # Check if there are changes to push
    if git diff-index --quiet HEAD --; then
        # Check if branch exists on remote
        if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
            # Check if we're ahead of remote
            LOCAL=$(git rev-parse @)
            REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")

            if [ "$LOCAL" == "$REMOTE" ]; then
                log_warn "  No changes to push (up to date with remote)"
                echo ""
                return
            fi
        else
            log_warn "  No local changes to commit"
            echo ""
            return
        fi
    fi

    # Push to remote
    if [ "$FORCE_PUSH" == "--force" ]; then
        log_warn "  Force pushing to origin"
        git push --force-with-lease origin "$BRANCH_NAME"
    else
        log_success "  Pushing to origin"
        git push -u origin "$BRANCH_NAME"
    fi

    log_check "$service_name pushed"
    echo ""
}

# Determine which repos to push
if [ "$REPOS_TO_PUSH" = "all" ]; then
    # Push all repos
    while IFS= read -r service; do
        push_branch "$service"
    done < <(config_list_services)
else
    # Parse specific repos
    IFS=',' read -ra SHORT_NAMES <<< "$REPOS_TO_PUSH"

    for short_name in "${SHORT_NAMES[@]}"; do
        # Find service by short name
        found=false
        while IFS= read -r service; do
            svc_short=$(config_get_service_short_name "$service")
            if [ "$svc_short" = "$short_name" ]; then
                push_branch "$service"
                found=true
                break
            fi
        done < <(config_list_services)

        if [ "$found" = false ]; then
            log_warn "Service with short name '$short_name' not found"
        fi
    done
fi

# Return to meta repo
cd "$META_REPO_ROOT"

log_section "Feature branches pushed!"

log_info "Check GitHub Actions:"
while IFS= read -r service; do
    echo -e "  • https://github.com/$GITHUB_ORG/$service/actions"
done < <(config_list_services)
echo ""
