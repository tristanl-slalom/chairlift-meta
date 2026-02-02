#!/bin/bash
# config.sh - Configuration file parsing and management

# Source dependencies
if [ -z "$GREEN" ]; then
    LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$LIB_DIR/logging.sh"
fi

# Global variables
CONFIG_FILE=""
CONFIG_TYPE=""
CONFIG_LOADED=false

# Initialize config - finds and loads the appropriate config file
config_init() {
    local search_dir="${1:-.}"

    # Look for services.yaml (new format)
    if [ -f "$search_dir/services.yaml" ]; then
        CONFIG_FILE="$search_dir/services.yaml"
        CONFIG_TYPE="yaml"
        CONFIG_LOADED=true
        return 0
    fi

    # Fallback to legacy .openspec/config.json
    if [ -f "$search_dir/.openspec/config.json" ]; then
        CONFIG_FILE="$search_dir/.openspec/config.json"
        CONFIG_TYPE="json"
        CONFIG_LOADED=true
        log_warn "Using legacy config format (.openspec/config.json)"
        log_warn "Consider migrating to services.yaml with: ./scripts/migrate-config.sh"
        return 0
    fi

    log_error "No configuration file found"
    log_info "Expected: services.yaml or .openspec/config.json"
    return 1
}

# Check if config is loaded
config_require() {
    if [ "$CONFIG_LOADED" != "true" ]; then
        log_error "Configuration not loaded. Call config_init first."
        return 1
    fi
    return 0
}

# Get a config value using jq for JSON or yq for YAML
config_get() {
    config_require || return 1

    local path="$1"
    local default="${2:-}"

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        # Check if yq is installed
        if ! command -v yq &> /dev/null; then
            log_error "yq is not installed. Install with: brew install yq"
            return 1
        fi

        local value=$(yq eval "$path" "$CONFIG_FILE" 2>/dev/null)
        if [ "$value" = "null" ] || [ -z "$value" ]; then
            echo "$default"
        else
            echo "$value"
        fi
    else
        # JSON format
        if ! command -v jq &> /dev/null; then
            log_error "jq is not installed. Install with: brew install jq"
            return 1
        fi

        local value=$(jq -r "$path" "$CONFIG_FILE" 2>/dev/null)
        if [ "$value" = "null" ] || [ -z "$value" ]; then
            echo "$default"
        else
            echo "$value"
        fi
    fi
}

# List all service names
config_list_services() {
    config_require || return 1

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        yq eval '.services[].name' "$CONFIG_FILE" 2>/dev/null
    else
        # Legacy format - extract from repositories array
        jq -r '.project.repositories[]' "$CONFIG_FILE" 2>/dev/null | while read -r repo; do
            # Extract just the repo name (after the /)
            echo "${repo##*/}"
        done | grep -v "chairlift-meta"  # Exclude meta repo
    fi
}

# Get service count
config_service_count() {
    config_list_services | wc -l | tr -d ' '
}

# Get service property by name
config_get_service() {
    config_require || return 1

    local service_name="$1"
    local property="$2"

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        yq eval ".services[] | select(.name == \"$service_name\") | .$property" "$CONFIG_FILE" 2>/dev/null
    else
        # Legacy format doesn't have detailed service properties
        echo ""
    fi
}

# Get service dependencies
config_get_service_dependencies() {
    local service_name="$1"

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        yq eval ".services[] | select(.name == \"$service_name\") | .dependencies[]?" "$CONFIG_FILE" 2>/dev/null
    else
        # Legacy format - hardcoded dependencies
        case "$service_name" in
            "chairlift-be-tasks")
                # No dependencies
                ;;
            "chairlift-bff")
                echo "chairlift-be-tasks"
                ;;
            "chairlift-fe")
                echo "chairlift-bff"
                ;;
        esac
    fi
}

# Get service repository URL
config_get_service_repo_url() {
    local service_name="$1"
    local github_org="$2"

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        local url_template=$(yq eval ".services[] | select(.name == \"$service_name\") | .repository.url" "$CONFIG_FILE" 2>/dev/null)
        # Replace {org} placeholder
        echo "${url_template//\{org\}/$github_org}"
    else
        # Legacy format - construct URL
        echo "git@github.com:$github_org/$service_name.git"
    fi
}

# Get service short name
config_get_service_short_name() {
    local service_name="$1"

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        yq eval ".services[] | select(.name == \"$service_name\") | .repository.short_name" "$CONFIG_FILE" 2>/dev/null
    else
        # Legacy format - derive from full name
        echo "${service_name##*-}"
    fi
}

# Get service type
config_get_service_type() {
    local service_name="$1"

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        yq eval ".services[] | select(.name == \"$service_name\") | .type" "$CONFIG_FILE" 2>/dev/null
    else
        # Legacy format - guess from name
        case "$service_name" in
            *-fe) echo "frontend" ;;
            *-bff) echo "backend" ;;
            *-be-*) echo "backend" ;;
            *) echo "backend" ;;
        esac
    fi
}

# Get service deployment order
config_get_service_order() {
    local service_name="$1"

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        yq eval ".services[] | select(.name == \"$service_name\") | .deployment.order" "$CONFIG_FILE" 2>/dev/null
    else
        # Legacy format - hardcoded order
        case "$service_name" in
            "chairlift-be-tasks") echo "1" ;;
            "chairlift-bff") echo "2" ;;
            "chairlift-fe") echo "3" ;;
            *) echo "99" ;;
        esac
    fi
}

# Get GitHub organization
config_get_github_org() {
    config_require || return 1

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        config_get ".project.github.organization"
    else
        config_get ".github.organization"
    fi
}

# Get project name
config_get_project_name() {
    config_require || return 1
    config_get ".project.name"
}

# Get GitHub project number
config_get_github_project_number() {
    config_require || return 1

    if [ "$CONFIG_TYPE" = "yaml" ]; then
        config_get ".project.github.project.number"
    else
        # Legacy format doesn't have this
        echo ""
    fi
}

# Export all functions
export -f config_init config_require config_get
export -f config_list_services config_service_count
export -f config_get_service config_get_service_dependencies
export -f config_get_service_repo_url config_get_service_short_name
export -f config_get_service_type config_get_service_order
export -f config_get_github_org config_get_project_name
export -f config_get_github_project_number

# Export global variables
export CONFIG_FILE CONFIG_TYPE CONFIG_LOADED
