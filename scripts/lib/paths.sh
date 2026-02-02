#!/bin/bash
# paths.sh - Path discovery and management functions

# Get the directory where a script is located
get_script_dir() {
    local source="${BASH_SOURCE[1]}"
    local dir="$( cd "$( dirname "$source" )" && pwd )"
    echo "$dir"
}

# Get the meta repo root directory
get_meta_repo_root() {
    local script_dir="${1:-$(get_script_dir)}"
    local meta_root="$( cd "$script_dir/.." && pwd )"
    echo "$meta_root"
}

# Get the workspace directory (repos/)
get_workspace_dir() {
    local meta_root="${1:-$(get_meta_repo_root)}"
    echo "$meta_root/repos"
}

# Get the feature workspace directory for an item
get_feature_workspace_dir() {
    local item_id="$1"
    local meta_root="${2:-$(get_meta_repo_root)}"
    echo "$meta_root/features/workspaces/$item_id"
}

# Get the feature repos directory for an item
get_feature_repos_dir() {
    local item_id="$1"
    local workspace_dir="$(get_feature_workspace_dir "$item_id")"
    echo "$workspace_dir/repos"
}

# Get the specs directory
get_specs_dir() {
    local meta_root="${1:-$(get_meta_repo_root)}"
    echo "$meta_root/features/specs"
}

# Get the implementation plans directory
get_plans_dir() {
    local meta_root="${1:-$(get_meta_repo_root)}"
    echo "$meta_root/features/implementation-plans"
}

# Get the transcripts directory
get_transcripts_dir() {
    local meta_root="${1:-$(get_meta_repo_root)}"
    echo "$meta_root/features/transcripts"
}

# Get spec file path for an item
get_spec_file() {
    local item_id="$1"
    local specs_dir="$(get_specs_dir)"
    echo "$specs_dir/$item_id.md"
}

# Get plan file path for an item
get_plan_file() {
    local item_id="$1"
    local plans_dir="$(get_plans_dir)"
    echo "$plans_dir/$item_id.md"
}

# Check if a directory exists and is a git repo
is_git_repo() {
    local dir="$1"
    if [ -d "$dir/.git" ]; then
        return 0
    else
        return 1
    fi
}

# Export all functions
export -f get_script_dir get_meta_repo_root get_workspace_dir
export -f get_feature_workspace_dir get_feature_repos_dir
export -f get_specs_dir get_plans_dir get_transcripts_dir
export -f get_spec_file get_plan_file is_git_repo
