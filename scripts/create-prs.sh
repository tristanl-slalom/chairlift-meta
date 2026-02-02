#!/bin/bash
set -e

# Create Pull Requests for a project item
# Commits changes and creates PRs across all repos

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/paths.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/services.sh"

META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")

# Check arguments
if [ -z "$1" ]; then
    log_error "Item number required"
    echo ""
    echo "Usage: $0 <item-number>"
    echo ""
    echo "Example: $0 42"
    exit 1
fi

ITEM_NUMBER=$1
validate_item_number "$ITEM_NUMBER" || exit 1

ITEM_ID="item-$ITEM_NUMBER"
BRANCH_NAME="feature/$ITEM_ID"
WORKSPACE_DIR=$(get_feature_workspace_dir "$ITEM_ID" "$META_REPO_ROOT")
SPEC_FILE=$(get_spec_file "$ITEM_ID")
PLAN_FILE=$(get_plan_file "$ITEM_ID")

# Load configuration
config_init "$META_REPO_ROOT" || exit 1

log_box "Creating Pull Requests - Item #$ITEM_NUMBER"

# Check if workspace exists
if [ ! -d "$WORKSPACE_DIR" ]; then
    log_error "Workspace not found"
    log_info "Run: ./scripts/start-item.sh $ITEM_NUMBER"
    exit 1
fi

# Get item details from GitHub
log_step "1" "4" "Fetching item details..."
ITEM_DATA=$(./scripts/github-projects.sh get "$ITEM_NUMBER")
ITEM_TITLE=$(echo "$ITEM_DATA" | jq -r '.title')
ITEM_URL=$(echo "$ITEM_DATA" | jq -r '.url')

log_check "Item: $ITEM_TITLE"
echo ""

# Function to create PR for a repo
create_pr() {
    local service_name=$1
    local repo_path="$WORKSPACE_DIR/repos/$service_name"

    if [ ! -d "$repo_path" ]; then
        log_warn "  ⚠ $service_name not found, skipping"
        return
    fi

    log_info "Processing $service_name..."
    cd "$repo_path"

    # Check if on correct branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
        log_warn "  ⚠ Not on $BRANCH_NAME (currently on $CURRENT_BRANCH), skipping"
        return
    fi

    # Check if there are changes
    if git diff-index --quiet HEAD --; then
        log_warn "  ⚠ No changes to commit"

        # Check if branch exists on remote
        if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
            log_info "  Branch exists on remote, checking for PR..."

            # Check if PR already exists
            if gh pr list --head "$BRANCH_NAME" --json number | grep -q "number"; then
                PR_URL=$(gh pr list --head "$BRANCH_NAME" --json url -q '.[0].url')
                log_check "  PR already exists: $PR_URL"
            else
                log_warn "  No changes and no PR found"
            fi
        else
            log_warn "  No changes to push"
        fi

        echo ""
        return
    fi

    # Stage all changes
    log_info "  Staging changes..."
    git add .

    # Commit changes
    log_info "  Committing changes..."
    git commit -m "Implement $ITEM_TITLE (#$ITEM_NUMBER)

Implements features from GitHub issue #$ITEM_NUMBER

See spec: features/specs/$ITEM_ID.md
See plan: features/implementation-plans/$ITEM_ID.md

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

    log_check "  Changes committed"

    # Push to remote
    log_info "  Pushing to origin..."
    git push -u origin "$BRANCH_NAME"
    log_check "  Pushed to origin"

    # Create PR
    log_info "  Creating pull request..."

    # Check if PR already exists
    if gh pr list --head "$BRANCH_NAME" --json number | grep -q "number"; then
        PR_URL=$(gh pr list --head "$BRANCH_NAME" --json url -q '.[0].url')
        log_check "  PR already exists: $PR_URL"
    else
        # Create PR with template
        PR_BODY="## Summary

Implements: $ITEM_TITLE

Closes #$ITEM_NUMBER

## Related Documents

- Specification: [features/specs/$ITEM_ID.md](../chairlift-meta/features/specs/$ITEM_ID.md)
- Implementation Plan: [features/implementation-plans/$ITEM_ID.md](../chairlift-meta/features/implementation-plans/$ITEM_ID.md)

## Changes

$(git log --oneline main..$BRANCH_NAME 2>/dev/null || git log --oneline master..$BRANCH_NAME 2>/dev/null | sed 's/^/- /')

## Testing

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Feature branch deployed and tested

## Deployment Notes

Feature branch: \`$BRANCH_NAME\`

The feature branch will automatically deploy isolated infrastructure for testing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

        gh pr create \
            --title "$ITEM_TITLE (#$ITEM_NUMBER)" \
            --body "$PR_BODY" \
            --base main \
            --head "$BRANCH_NAME"

        PR_URL=$(gh pr list --head "$BRANCH_NAME" --json url -q '.[0].url')
        log_check "  PR created: $PR_URL"
    fi

    echo ""
}

# Create PRs for each repo in deployment order
log_step "2" "4" "Creating pull requests..."
echo ""

while IFS= read -r service; do
    create_pr "$service"
done < <(get_services_in_order)

# Return to meta repo
cd "$META_REPO_ROOT"

# Commit spec and plan to meta repo if not already committed
log_step "3" "4" "Committing spec and plan to meta repo..."

if git status --porcelain | grep -q "features/"; then
    git add features/specs/$ITEM_ID.md features/implementation-plans/$ITEM_ID.md 2>/dev/null || true

    if git diff --cached --quiet; then
        log_warn "No changes to commit in meta repo"
    else
        git commit -m "Add spec and implementation plan for #$ITEM_NUMBER

$ITEM_TITLE

GitHub Issue: $ITEM_URL"
        git push
        log_check "Spec and plan committed to meta repo"
    fi
else
    log_warn "No changes to commit in meta repo"
fi

echo ""

# Summary
log_step "4" "4" "Summary"
echo ""
log_section "Pull Requests Created!"

log_header "GitHub Issue:"
echo -e "  $ITEM_URL"
echo ""
log_header "Pull Requests:"

# Show PRs for all services
while IFS= read -r service; do
    repo_path="$WORKSPACE_DIR/repos/$service"
    if [ -d "$repo_path" ]; then
        cd "$repo_path"
        if gh pr list --head "$BRANCH_NAME" --json url,number 2>/dev/null | grep -q "number"; then
            PR_INFO=$(gh pr list --head "$BRANCH_NAME" --json url,number -q '.[0] | "\(.url) (#\(.number))"')
            short_name=$(config_get_service_short_name "$service")
            echo -e "${YELLOW}  • $short_name: $PR_INFO${NC}"
        fi
    fi
done < <(get_services_in_order)

cd "$META_REPO_ROOT"

echo ""
log_header "Next Steps:"
log_bullet "Review PRs"
log_bullet "Test feature branch deployment"
log_bullet "Merge PRs when ready"
log_bullet "Delete feature branches to trigger cleanup"
echo ""
