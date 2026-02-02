#!/bin/bash
# services.sh - Service dependency resolution and ordering

# Source dependencies
if [ -z "$CONFIG_LOADED" ]; then
    LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$LIB_DIR/config.sh"
fi

# Get services in dependency order (topological sort)
get_services_in_order() {
    config_require || return 1

    local services=()
    local ordered_services=()
    local processed=()

    # Get all services
    while IFS= read -r service; do
        services+=("$service")
    done < <(config_list_services)

    # Sort by deployment order
    for service in "${services[@]}"; do
        local order=$(config_get_service_order "$service")
        echo "$order:$service"
    done | sort -n | cut -d: -f2
}

# Get services in reverse order (for cleanup)
get_services_in_reverse_order() {
    get_services_in_order | tac
}

# Check if a service has dependencies
has_dependencies() {
    local service_name="$1"
    local deps=$(config_get_service_dependencies "$service_name")
    [ -n "$deps" ]
}

# Get all dependencies for a service (recursive)
get_all_dependencies() {
    local service_name="$1"
    local seen="${2:-}"

    # Check for circular dependency
    if [[ "$seen" == *"$service_name"* ]]; then
        log_error "Circular dependency detected: $seen -> $service_name"
        return 1
    fi

    local new_seen="$seen $service_name"
    local all_deps=()

    # Get direct dependencies
    while IFS= read -r dep; do
        [ -z "$dep" ] && continue

        # Add dependency's dependencies first (recursive)
        local sub_deps=$(get_all_dependencies "$dep" "$new_seen")
        if [ -n "$sub_deps" ]; then
            for sub_dep in $sub_deps; do
                all_deps+=("$sub_dep")
            done
        fi

        # Add the dependency itself
        all_deps+=("$dep")
    done < <(config_get_service_dependencies "$service_name")

    # Remove duplicates and print
    printf "%s\n" "${all_deps[@]}" | sort -u
}

# Validate service dependencies
validate_dependencies() {
    config_require || return 1

    local has_errors=false
    local services=()

    # Get all services
    while IFS= read -r service; do
        services+=("$service")
    done < <(config_list_services)

    log_info "Validating service dependencies..."

    # Check each service
    for service in "${services[@]}"; do
        local deps=$(config_get_service_dependencies "$service")

        for dep in $deps; do
            # Check if dependency exists
            local found=false
            for existing in "${services[@]}"; do
                if [ "$existing" = "$dep" ]; then
                    found=true
                    break
                fi
            done

            if [ "$found" = false ]; then
                log_error "Service '$service' depends on '$dep' which does not exist"
                has_errors=true
            fi
        done

        # Check for circular dependencies
        if ! get_all_dependencies "$service" > /dev/null 2>&1; then
            has_errors=true
        fi
    done

    if [ "$has_errors" = true ]; then
        return 1
    else
        log_check "All dependencies valid"
        return 0
    fi
}

# Check if service exists
service_exists() {
    local service_name="$1"

    while IFS= read -r service; do
        if [ "$service" = "$service_name" ]; then
            return 0
        fi
    done < <(config_list_services)

    return 1
}

# Get service info (formatted output)
service_info() {
    local service_name="$1"

    if ! service_exists "$service_name"; then
        log_error "Service '$service_name' not found"
        return 1
    fi

    local type=$(config_get_service_type "$service_name")
    local short_name=$(config_get_service_short_name "$service_name")
    local order=$(config_get_service_order "$service_name")
    local deps=$(config_get_service_dependencies "$service_name")

    echo "Service: $service_name"
    echo "  Type: $type"
    echo "  Short name: $short_name"
    echo "  Deployment order: $order"
    if [ -n "$deps" ]; then
        echo "  Dependencies:"
        for dep in $deps; do
            echo "    - $dep"
        done
    else
        echo "  Dependencies: none"
    fi
}

# List all services with info
list_services() {
    config_require || return 1

    log_info "Services in deployment order:"
    echo ""

    while IFS= read -r service; do
        local order=$(config_get_service_order "$service")
        local type=$(config_get_service_type "$service")
        local deps=$(config_get_service_dependencies "$service")

        printf "  %d. %s (%s)\n" "$order" "$service" "$type"

        if [ -n "$deps" ]; then
            for dep in $deps; do
                echo "     └─ depends on: $dep"
            done
        fi
    done < <(get_services_in_order)

    echo ""
}

# Export all functions
export -f get_services_in_order get_services_in_reverse_order
export -f has_dependencies get_all_dependencies validate_dependencies
export -f service_exists service_info list_services
