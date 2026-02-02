#!/bin/bash
set -e

# Project Item Orchestration Script
# Automates: fetch item -> generate spec -> generate plan -> clone repos -> ready for Claude

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/github.sh"
source "$SCRIPT_DIR/lib/validation.sh"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")

# Check arguments
if [ -z "$1" ]; then
    log_error "Item number required"
    echo ""
    echo "Usage: $0 <item-number>"
    echo ""
    echo "Example: $0 42"
    echo ""
    echo "This will:"
    echo "  1. Fetch item #42 from GitHub Projects"
    echo "  2. Generate spec in features/specs/"
    echo "  3. Prompt for your review"
    echo "  4. Generate implementation plan"
    echo "  5. Prompt for your review"
    echo "  6. Clone repos to features/workspaces/item-42/"
    echo "  7. Ready for Claude Code to implement"
    exit 1
fi

ITEM_NUMBER=$1
validate_item_number "$ITEM_NUMBER" || exit 1

ITEM_ID="item-$ITEM_NUMBER"
WORKSPACE_DIR=$(get_feature_workspace_dir "$ITEM_ID" "$META_REPO_ROOT")
SPEC_FILE=$(get_spec_file "$ITEM_ID")
PLAN_FILE=$(get_plan_file "$ITEM_ID")

# Load configuration
config_init "$META_REPO_ROOT" || exit 1

log_box "Project Item Orchestration - Item #$ITEM_NUMBER"

# Step 1: Fetch item from GitHub Projects
log_step "1" "7" "Fetching item from GitHub Projects..."
ITEM_DATA=$(./scripts/github-projects.sh get "$ITEM_NUMBER")

if [ -z "$ITEM_DATA" ]; then
    log_error "Could not fetch item #$ITEM_NUMBER"
    exit 1
fi

ITEM_TITLE=$(echo "$ITEM_DATA" | jq -r '.title')
ITEM_BODY=$(echo "$ITEM_DATA" | jq -r '.body // ""')
ITEM_URL=$(echo "$ITEM_DATA" | jq -r '.url')

log_check "Fetched: $ITEM_TITLE"
echo -e "  URL: $ITEM_URL"
echo ""

# Step 2: Check if spec already exists
if [ -f "$SPEC_FILE" ]; then
    log_warn "[2/7] Spec already exists"
    echo -e "  File: $SPEC_FILE"
    echo ""
    if confirm "Do you want to regenerate the spec?" "n"; then
        rm "$SPEC_FILE"
    else
        log_info "Using existing spec"
    fi
fi

# Step 3: Generate spec (if doesn't exist)
if [ ! -f "$SPEC_FILE" ]; then
    log_step "2" "7" "Generating specification..."

    # Ensure directory exists
    mkdir -p "$(dirname "$SPEC_FILE")"

    # Create spec from template
    cat > "$SPEC_FILE" << EOF
# $ITEM_TITLE - Specification

## Metadata

- **ID**: $ITEM_ID
- **GitHub Issue**: #$ITEM_NUMBER
- **Created**: $(date +%Y-%m-%d)
- **Status**: Draft
- **Related Implementation Plan**: [implementation-plans/$ITEM_ID.md](../implementation-plans/$ITEM_ID.md)

## Overview

$ITEM_BODY

## User Stories

[TO BE FILLED BY CLAUDE - Use Claude to expand on the overview and create detailed user stories]

## Requirements

### Functional Requirements

[TO BE FILLED BY CLAUDE - Based on the GitHub issue description]

### Non-Functional Requirements

[TO BE FILLED BY CLAUDE - Performance, security, scalability considerations]

## API Changes

[TO BE FILLED BY CLAUDE - New or modified endpoints]

## Data Model Changes

[TO BE FILLED BY CLAUDE - Database schema changes]

## Architecture Impact

### Services Affected

$(while IFS= read -r service; do
    echo "- [ ] $service"
done < <(config_list_services))

[TO BE FILLED BY CLAUDE - Describe impact on each service]

## Testing Strategy

[TO BE FILLED BY CLAUDE - Unit, integration, and E2E test plans]

## Deployment Considerations

[TO BE FILLED BY CLAUDE - Feature flags, migrations, configuration]

## Success Metrics

[TO BE FILLED BY CLAUDE - How will we measure success?]

---

**Next Step**: Run Claude Code from meta repo and ask it to:
\`\`\`
Review features/specs/$ITEM_ID.md and fill in all the [TO BE FILLED BY CLAUDE] sections
based on the GitHub issue description. Expand on requirements, architecture impact,
and testing strategy.
\`\`\`
EOF

    log_check "Spec template created"
    echo -e "  File: $SPEC_FILE"
    echo ""
fi

# Step 4: Prompt for spec review/completion
log_header "[3/7] Spec Review"
echo -e "The spec is at: ${YELLOW}$SPEC_FILE${NC}"
echo ""
log_warn "Next step: Use Claude to complete the spec"
echo ""
echo -e "Run from meta repo:"
log_success "claude"
echo ""
echo -e "Then prompt:"
log_info "Review features/specs/$ITEM_ID.md and fill in all the [TO BE FILLED BY CLAUDE]"
log_info "sections based on the GitHub issue. Be thorough and specific."
echo ""
read -p "Press Enter when spec is complete and reviewed..."
echo ""

# Step 5: Check if implementation plan exists
if [ -f "$PLAN_FILE" ]; then
    log_warn "[4/7] Implementation plan already exists"
    echo -e "  File: $PLAN_FILE"
    echo ""
    if confirm "Do you want to regenerate the plan?" "n"; then
        rm "$PLAN_FILE"
    else
        log_info "Using existing plan"
    fi
fi

# Step 6: Generate implementation plan
if [ ! -f "$PLAN_FILE" ]; then
    log_step "4" "7" "Generating implementation plan..."

    # Ensure directory exists
    mkdir -p "$(dirname "$PLAN_FILE")"

    cat > "$PLAN_FILE" << EOF
# $ITEM_TITLE - Implementation Plan

## Metadata

- **ID**: $ITEM_ID
- **GitHub Issue**: #$ITEM_NUMBER
- **Created**: $(date +%Y-%m-%d)
- **Status**: Draft
- **Related Spec**: [specs/$ITEM_ID.md](../specs/$ITEM_ID.md)
- **Feature Branch**: \`feature/$ITEM_ID\`

## Overview

[TO BE FILLED BY CLAUDE - Based on the completed spec]

## Implementation Strategy

### Phase 1: [TO BE FILLED BY CLAUDE]

**Repos Affected**:
$(while IFS= read -r service; do
    echo "- [ ] $service"
done < <(config_list_services))

**Files to Create/Modify**:
[TO BE FILLED BY CLAUDE - List all files with descriptions]

**Tasks**:
- [ ] [TO BE FILLED BY CLAUDE]

### Phase 2: [TO BE FILLED BY CLAUDE]

[Continue pattern...]

## Detailed Changes

$(while IFS= read -r service; do
    echo "### $service"
    echo ""
    echo "[TO BE FILLED BY CLAUDE - List files and specific changes]"
    echo ""
done < <(config_list_services))

## Dependencies

[TO BE FILLED BY CLAUDE - New packages, AWS resources]

## Testing Plan

[TO BE FILLED BY CLAUDE - Unit, integration, E2E tests]

## Deployment Steps

[TO BE FILLED BY CLAUDE - Step-by-step deployment process]

## Success Criteria

- [ ] All tests pass
- [ ] Feature deployed to feature environment
- [ ] Manual testing completed
- [ ] Code review approved
- [ ] Documentation updated

---

**Next Step**: Run Claude Code from meta repo and ask it to:
\`\`\`
Review features/implementation-plans/$ITEM_ID.md and create a detailed implementation
plan based on features/specs/$ITEM_ID.md. Include:
- Specific files to create/modify in each repo
- Exact code changes needed
- Complete testing strategy
- Deployment steps

The cloned repos will be available at:
$(while IFS= read -r service; do
    echo "- features/workspaces/$ITEM_ID/repos/$service"
done < <(config_list_services))
\`\`\`
EOF

    log_check "Implementation plan template created"
    echo -e "  File: $PLAN_FILE"
    echo ""
fi

# Step 7: Prompt for plan review/completion
log_header "[5/7] Implementation Plan Review"
echo -e "The plan is at: ${YELLOW}$PLAN_FILE${NC}"
echo ""
log_warn "Next step: Use Claude to complete the implementation plan"
echo ""
echo -e "Run from meta repo:"
log_success "claude"
echo ""
echo -e "Then prompt:"
log_info "Review features/implementation-plans/$ITEM_ID.md and create a detailed plan"
log_info "based on features/specs/$ITEM_ID.md. List all files to modify, exact changes,"
log_info "testing strategy, and deployment steps."
echo ""
read -p "Press Enter when implementation plan is complete and approved..."
echo ""

# Step 8: Create workspace and clone repos
log_step "6" "7" "Setting up workspace..."

if [ -d "$WORKSPACE_DIR" ]; then
    log_warn "Workspace already exists"
    echo -e "  Location: $WORKSPACE_DIR"
    echo ""
    if confirm "Do you want to recreate it?" "n"; then
        rm -rf "$WORKSPACE_DIR"
    fi
fi

if [ ! -d "$WORKSPACE_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR/repos"

    # Get GitHub org
    GITHUB_ORG=$(get_github_org "$META_REPO_ROOT")

    echo -e "  Cloning repositories..."
    cd "$WORKSPACE_DIR/repos"

    # Clone all services from config
    while IFS= read -r service; do
        repo_url=$(config_get_service_repo_url "$service" "$GITHUB_ORG")
        git clone "$repo_url" --quiet
        log_check "$service"
    done < <(config_list_services)

    cd "$META_REPO_ROOT"
fi

log_check "Workspace ready"
echo -e "  Location: $WORKSPACE_DIR"
echo ""

# Step 9: Create feature branches
log_step "7" "7" "Creating feature branches..."

BRANCH_NAME="feature/$ITEM_ID"

# Create branches in all services
while IFS= read -r service; do
    cd "$WORKSPACE_DIR/repos/$service"
    git checkout main --quiet 2>/dev/null || git checkout master --quiet 2>/dev/null
    git pull origin main --quiet 2>/dev/null || git pull origin master --quiet 2>/dev/null
    git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
    log_check "$service on $BRANCH_NAME"
done < <(config_list_services)

cd "$META_REPO_ROOT"

echo ""
log_section "Setup Complete! Ready for Implementation"

log_header "What was created:"
echo -e "  📄 Spec: ${YELLOW}features/specs/$ITEM_ID.md${NC}"
echo -e "  📋 Plan: ${YELLOW}features/implementation-plans/$ITEM_ID.md${NC}"
echo -e "  📁 Workspace: ${YELLOW}features/workspaces/$ITEM_ID/${NC}"
echo ""
log_header "Next Steps:"
echo -e "  1. Start Claude Code from meta repo: ${GREEN}claude${NC}"
echo -e "  2. Give Claude this prompt:"
echo -e ""
log_info "     Implement the plan in features/implementation-plans/$ITEM_ID.md"
log_info "     "
log_info "     The service repos are at:"
while IFS= read -r service; do
    log_info "     - features/workspaces/$ITEM_ID/repos/$service"
done < <(config_list_services)
log_info "     "
log_info "     Make all the changes specified in the plan."
echo ""
echo -e "  3. When done, run: ${GREEN}./scripts/create-prs.sh $ITEM_NUMBER${NC}"
echo ""
