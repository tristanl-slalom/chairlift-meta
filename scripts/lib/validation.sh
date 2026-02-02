#!/bin/bash
# validation.sh - Input validation and requirement checking

# Source dependencies
if [ -z "$GREEN" ]; then
    LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$LIB_DIR/logging.sh"
fi

# Check if a command is available
require_command() {
    local cmd="$1"
    local install_msg="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed"
        if [ -n "$install_msg" ]; then
            log_info "$install_msg"
        fi
        return 1
    fi

    return 0
}

# Require multiple commands
require_commands() {
    local missing=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi

    return 0
}

# Validate item number format
validate_item_number() {
    local item_number="$1"

    if [ -z "$item_number" ]; then
        log_error "Item number is required"
        return 1
    fi

    if ! [[ "$item_number" =~ ^[0-9]+$ ]]; then
        log_error "Item number must be numeric: $item_number"
        return 1
    fi

    return 0
}

# Validate branch name format
validate_branch_name() {
    local branch_name="$1"

    if [ -z "$branch_name" ]; then
        log_error "Branch name is required"
        return 1
    fi

    # Check for invalid characters
    if [[ "$branch_name" =~ [[:space:]] ]] || [[ "$branch_name" =~ [\~\^\:\?\*\[\]\\] ]]; then
        log_error "Invalid branch name: $branch_name"
        log_info "Branch names cannot contain spaces or special characters: ~ ^ : ? * [ ] \\"
        return 1
    fi

    return 0
}

# Validate directory exists
require_directory() {
    local dir="$1"
    local create="${2:-false}"

    if [ ! -d "$dir" ]; then
        if [ "$create" = "true" ]; then
            log_info "Creating directory: $dir"
            mkdir -p "$dir"
            return 0
        else
            log_error "Directory does not exist: $dir"
            return 1
        fi
    fi

    return 0
}

# Validate file exists
require_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        log_error "File does not exist: $file"
        return 1
    fi

    return 0
}

# Check if directory is a git repository
require_git_repo() {
    local dir="${1:-.}"

    if [ ! -d "$dir/.git" ]; then
        log_error "Not a git repository: $dir"
        return 1
    fi

    return 0
}

# Validate GitHub organization format
validate_github_org() {
    local org="$1"

    if [ -z "$org" ]; then
        log_error "GitHub organization is required"
        return 1
    fi

    # Check for invalid characters
    if [[ ! "$org" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        log_error "Invalid GitHub organization name: $org"
        log_info "Organization names can only contain alphanumeric characters and hyphens"
        return 1
    fi

    return 0
}

# Validate service name format
validate_service_name() {
    local service_name="$1"

    if [ -z "$service_name" ]; then
        log_error "Service name is required"
        return 1
    fi

    # Check format (lowercase, hyphens only)
    if [[ ! "$service_name" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Invalid service name: $service_name"
        log_info "Service names must be lowercase with hyphens only"
        return 1
    fi

    return 0
}

# Validate URL format
validate_url() {
    local url="$1"

    if [ -z "$url" ]; then
        log_error "URL is required"
        return 1
    fi

    # Basic URL validation
    if [[ ! "$url" =~ ^(https?|git)://.*$ ]] && [[ ! "$url" =~ ^git@.*$ ]]; then
        log_error "Invalid URL format: $url"
        return 1
    fi

    return 0
}

# Confirm action with user
confirm() {
    local message="$1"
    local default="${2:-n}"

    local prompt="[y/N]"
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    fi

    echo -n -e "${YELLOW}$message $prompt ${NC}"
    read -r response

    # Use default if no response
    if [ -z "$response" ]; then
        response="$default"
    fi

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Require confirmation or exit
require_confirmation() {
    local message="$1"

    if ! confirm "$message"; then
        log_info "Operation cancelled"
        exit 0
    fi
}

# Export all functions
export -f require_command require_commands
export -f validate_item_number validate_branch_name
export -f require_directory require_file require_git_repo
export -f validate_github_org validate_service_name validate_url
export -f confirm require_confirmation
