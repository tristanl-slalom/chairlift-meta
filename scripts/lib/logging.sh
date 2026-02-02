#!/bin/bash
# logging.sh - Standardized logging functions for all scripts

# Source colors if not already loaded
if [ -z "$GREEN" ]; then
    LIB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "$LIB_DIR/colors.sh"
fi

# Log functions with consistent formatting
log_info() {
    echo -e "${BLUE}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}" >&2
}

log_warn() {
    echo -e "${YELLOW}$1${NC}"
}

log_header() {
    echo -e "${CYAN}$1${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

log_box() {
    local message="$1"
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $message${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_step() {
    local step="$1"
    local total="$2"
    local message="$3"
    echo -e "${BLUE}[$step/$total] $message${NC}"
}

log_bullet() {
    echo -e "  • $1"
}

log_check() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_cross() {
    echo -e "${RED}✗ $1${NC}"
}

log_arrow() {
    echo -e "${BLUE}→${NC} $1"
}

# Export all functions
export -f log_info log_success log_error log_warn log_header
export -f log_section log_box log_step log_bullet
export -f log_check log_cross log_arrow
