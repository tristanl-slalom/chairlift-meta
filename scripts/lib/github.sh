#!/bin/bash
# github.sh - GitHub operations and utilities

# Source dependencies
if [ -z "$GREEN" ]; then
    LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$LIB_DIR/logging.sh"
fi

# Detect GitHub organization/user from git remote
detect_github_org() {
    local repo_dir="${1:-.}"

    cd "$repo_dir" || return 1
    local git_remote=$(git remote get-url origin 2>/dev/null)

    if [ -z "$git_remote" ]; then
        log_error "No git remote found"
        return 1
    fi

    # Extract org/user from git URL (supports both SSH and HTTPS)
    if [[ $git_remote =~ github.com[:/]([^/]+)/ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    else
        log_warn "Could not detect GitHub org from remote URL: $git_remote"
        return 1
    fi
}

# Get GitHub organization with fallback to user input
get_github_org() {
    local repo_dir="${1:-.}"
    local github_org

    github_org=$(detect_github_org "$repo_dir")

    if [ -z "$github_org" ]; then
        log_warn "Could not detect GitHub org from remote URL"
        echo "Please enter GitHub organization/user:"
        read github_org
    fi

    echo "$github_org"
}

# Clone or update a repository
clone_or_update_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local target_dir="$3"
    local repo_path="$target_dir/$repo_name"

    if [ -d "$repo_path" ]; then
        log_warn "$repo_name already exists, updating..."
        cd "$repo_path" || return 1
        git fetch --all
        git checkout main 2>/dev/null || git checkout master 2>/dev/null
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
    else
        log_info "Cloning $repo_name..."
        cd "$target_dir" || return 1
        git clone "$repo_url" "$repo_name"
    fi

    log_check "$repo_name ready"
    echo ""
}

# Check if gh CLI is installed
require_gh_cli() {
    if ! command -v gh &> /dev/null; then
        log_error "gh CLI is not installed"
        log_info "Install with: brew install gh"
        log_info "Or visit: https://cli.github.com/"
        return 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        log_error "gh CLI is not authenticated"
        log_info "Run: gh auth login"
        return 1
    fi

    return 0
}

# Check if a GitHub repository exists
repo_exists() {
    local org="$1"
    local repo="$2"

    gh repo view "$org/$repo" &> /dev/null
    return $?
}

# Create a GitHub repository
create_repo() {
    local org="$1"
    local repo="$2"
    local description="$3"
    local private="${4:-false}"

    local visibility_flag=""
    if [ "$private" = "true" ]; then
        visibility_flag="--private"
    else
        visibility_flag="--public"
    fi

    log_info "Creating GitHub repository: $org/$repo"
    gh repo create "$org/$repo" $visibility_flag --description "$description"
}

# Export all functions
export -f detect_github_org get_github_org clone_or_update_repo
export -f require_gh_cli repo_exists create_repo
