#!/bin/bash

# Workspace Status Script
# Shows git status for all service repositories

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Initialize
log_section "Workspace Status"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")
REPOS_DIR=$(get_workspace_dir "$META_REPO_ROOT")

# Check if repos directory exists
if [ ! -d "$REPOS_DIR" ]; then
    log_error "Repos directory not found"
    log_info "Run ./setup-workspace.sh first"
    exit 1
fi

# Load configuration
config_init "$META_REPO_ROOT" || exit 1

# Function to show repo status
show_repo_status() {
    local repo_name=$1
    local repo_path="$REPOS_DIR/$repo_name"

    if [ ! -d "$repo_path" ]; then
        log_cross "$repo_name - NOT FOUND"
        echo ""
        return
    fi

    cd "$repo_path"

    # Get current branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        CHANGES="${RED}[UNCOMMITTED CHANGES]${NC}"
    else
        CHANGES="${GREEN}[CLEAN]${NC}"
    fi

    # Check if ahead/behind remote
    git fetch origin "$BRANCH" 2>/dev/null || true
    LOCAL=$(git rev-parse @ 2>/dev/null || echo "")
    REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
    BASE=$(git merge-base @ @{u} 2>/dev/null || echo "")

    if [ -z "$REMOTE" ]; then
        SYNC="${YELLOW}[NO REMOTE]${NC}"
    elif [ "$LOCAL" = "$REMOTE" ]; then
        SYNC="${GREEN}[UP TO DATE]${NC}"
    elif [ "$LOCAL" = "$BASE" ]; then
        SYNC="${YELLOW}[BEHIND REMOTE]${NC}"
    elif [ "$REMOTE" = "$BASE" ]; then
        SYNC="${YELLOW}[AHEAD OF REMOTE]${NC}"
    else
        SYNC="${RED}[DIVERGED]${NC}"
    fi

    log_info "$repo_name"
    echo -e "  Branch: ${GREEN}$BRANCH${NC}"
    echo -e "  Status: $CHANGES $SYNC"

    # Show uncommitted files if any
    if ! git diff-index --quiet HEAD --; then
        echo -e "  ${YELLOW}Modified files:${NC}"
        git status --short | sed 's/^/    /'
    fi

    echo ""
}

# Show status for each repo
while IFS= read -r service; do
    show_repo_status "$service"
done < <(config_list_services)

# Return to meta repo
cd "$META_REPO_ROOT"

echo -e "${BLUE}========================================${NC}"
