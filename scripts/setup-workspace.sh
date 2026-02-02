#!/bin/bash
set -e

# Setup Multi-Repo Workspace
# Clones all service repositories to the repos/ directory

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/github.sh"
source "$SCRIPT_DIR/lib/services.sh"

# Initialize
log_section "Chairlift Multi-Repo Workspace Setup"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")
REPOS_DIR=$(get_workspace_dir "$META_REPO_ROOT")

log_info "Meta repo: $META_REPO_ROOT"
log_info "Repos directory: $REPOS_DIR"
echo ""

# Create repos directory if it doesn't exist
if [ ! -d "$REPOS_DIR" ]; then
    log_info "Creating repos directory..."
    mkdir -p "$REPOS_DIR"
fi

# Load configuration
config_init "$META_REPO_ROOT" || exit 1

# Get GitHub organization
GITHUB_ORG=$(get_github_org "$META_REPO_ROOT")
log_info "GitHub org/user: $GITHUB_ORG"
echo ""

# Clone/update service repositories
while IFS= read -r service; do
    repo_url=$(config_get_service_repo_url "$service" "$GITHUB_ORG")
    clone_or_update_repo "$service" "$repo_url" "$REPOS_DIR"
done < <(get_services_in_order)

# Return to meta repo
cd "$META_REPO_ROOT"

log_section "Workspace setup complete!"

log_info "Service repositories are available at:"
while IFS= read -r service; do
    log_bullet "$REPOS_DIR/$service"
done < <(get_services_in_order)

echo ""
log_info "Next steps:"
log_bullet "Create OpenSpec spec in .openspec/specs/"
log_bullet "Create implementation plan in .openspec/implementation-plans/"
log_bullet "Start Claude Code from meta repo"
log_bullet "Reference the plan to make changes across repos"
echo ""
