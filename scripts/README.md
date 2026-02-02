# Concepto Automation Scripts

Complete reference for all automation scripts and shared libraries in the Concepto meta repository.

## Quick Start

```bash
# Validate configuration
./scripts/validate-config.sh

# Set up workspace
./scripts/setup-workspace.sh

# Check workspace status
./scripts/workspace-status.sh

# Start working on an item
./scripts/start-item.sh 42
```

## Overview

The Concepto automation system uses a **config-driven architecture** where all scripts read from `services.yaml` (or legacy `.openspec/config.json`) to determine which services to operate on. This eliminates hardcoded service lists and enables N-service scalability.

### Architecture

```
scripts/
├── lib/                    # Shared libraries (sourced by all scripts)
│   ├── colors.sh          # Color definitions
│   ├── logging.sh         # Logging functions
│   ├── paths.sh           # Path management
│   ├── config.sh          # Configuration parsing
│   ├── github.sh          # GitHub operations
│   ├── services.sh        # Service dependency resolution
│   └── validation.sh      # Input validation
├── setup-workspace.sh      # Clone service repos
├── workspace-status.sh     # Show git status
├── create-feature-branch.sh # Create feature branches
├── push-feature-branch.sh  # Push feature branches
├── start-item.sh          # Full item orchestration
├── create-prs.sh          # Create pull requests
├── validate-config.sh     # Validate services.yaml
├── migrate-config.sh      # Migrate from legacy config
└── github-projects.sh     # GitHub Projects integration

services.yaml              # Service configuration (root)
```

## Core Scripts

### setup-workspace.sh

Clones all service repositories to the `repos/` directory.

**Usage:**
```bash
./scripts/setup-workspace.sh
```

**What it does:**
1. Reads service list from configuration
2. Detects GitHub organization from git remote
3. Clones or updates each service repository
4. Checks out main branch and pulls latest

**Config-driven:** Dynamically processes all services defined in `services.yaml`

### workspace-status.sh

Shows git status for all service repositories.

**Usage:**
```bash
./scripts/workspace-status.sh
```

**Output:**
- Current branch
- Working directory status (clean/uncommitted changes)
- Sync status with remote (up to date/ahead/behind/diverged)
- List of modified files (if any)

**Config-driven:** Iterates over all services from configuration

### create-feature-branch.sh

Creates feature branches across service repositories.

**Usage:**
```bash
# Create branch in all services
./scripts/create-feature-branch.sh feature/my-feature

# Create branch in specific services (by short name)
./scripts/create-feature-branch.sh feature/my-feature tasks,bff

# Using 'all' explicitly
./scripts/create-feature-branch.sh feature/my-feature all
```

**What it does:**
1. Validates branch name
2. Checks out main and pulls latest
3. Creates feature branch (or checks out if exists)
4. Reports success for each service

**Config-driven:**
- Resolves short names (tasks, bff, fe) to full service names
- Supports `all` to process every service in configuration

### push-feature-branch.sh

Pushes feature branches to remote repositories.

**Usage:**
```bash
# Push all services
./scripts/push-feature-branch.sh feature/my-feature

# Push specific services
./scripts/push-feature-branch.sh feature/my-feature tasks,bff

# Force push (with lease)
./scripts/push-feature-branch.sh feature/my-feature all --force
```

**What it does:**
1. Checks if on correct branch
2. Detects uncommitted changes
3. Pushes to remote (creates upstream tracking)
4. Skips services with no changes

**Config-driven:** Processes services based on configuration

### start-item.sh

Full orchestration workflow for starting work on a GitHub Projects item.

**Usage:**
```bash
./scripts/start-item.sh 42
```

**Workflow:**
1. **Fetch item** from GitHub Projects (#42)
2. **Generate spec** in `features/specs/item-42.md`
3. **Prompt for spec review** (Claude fills in details)
4. **Generate plan** in `features/implementation-plans/item-42.md`
5. **Prompt for plan review** (Claude creates detailed plan)
6. **Clone repos** to `features/workspaces/item-42/repos/`
7. **Create feature branches** (`feature/item-42`)

**Config-driven:**
- Generates service list in spec/plan templates
- Clones all services from configuration
- Creates branches across all services

### create-prs.sh

Creates pull requests across all service repositories.

**Usage:**
```bash
./scripts/create-prs.sh 42
```

**What it does:**
1. Fetches item details from GitHub Projects
2. For each service with changes:
   - Stages all changes
   - Commits with standard message
   - Pushes to remote
   - Creates PR (or reports existing PR)
3. Commits spec and plan to meta repo
4. Shows summary with PR URLs

**Config-driven:**
- Processes services in deployment order
- Generates PR list dynamically

## Configuration Scripts

### validate-config.sh

Validates `services.yaml` for correctness.

**Usage:**
```bash
./scripts/validate-config.sh
```

**Validates:**
- ✅ Required fields present (name, type, order, etc.)
- ✅ No circular dependencies
- ✅ All dependencies exist
- ✅ Unique deployment orders
- ✅ Valid service names
- ✅ Export/import consistency

**Exit codes:**
- `0` - Configuration is valid
- `1` - Validation errors found

### migrate-config.sh

Migrates from legacy `.openspec/config.json` to `services.yaml`.

**Usage:**
```bash
./scripts/migrate-config.sh
```

**What it does:**
1. Checks if `services.yaml` already exists
2. Reads legacy `.openspec/config.json`
3. Generates `services.yaml` with current 3 services
4. Updates project name and GitHub org
5. Validates new configuration
6. Keeps legacy config for rollback

**Backwards compatibility:** Scripts automatically fall back to legacy config if `services.yaml` doesn't exist.

## Shared Libraries

All scripts source libraries from `scripts/lib/` to eliminate code duplication and provide consistent functionality.

### colors.sh

Standard color definitions for terminal output.

**Colors available:**
```bash
GREEN, BLUE, YELLOW, RED, CYAN, NC (No Color)
BOLD, DIM, UNDERLINE
LIGHT_RED, LIGHT_GREEN, etc.
```

**Usage in scripts:**
```bash
source "$SCRIPT_DIR/lib/colors.sh"
echo -e "${GREEN}Success!${NC}"
```

### logging.sh

Standardized logging functions.

**Functions:**
- `log_info "message"` - Blue informational message
- `log_success "message"` - Green success message
- `log_error "message"` - Red error message (to stderr)
- `log_warn "message"` - Yellow warning message
- `log_header "message"` - Cyan header
- `log_section "message"` - Section with borders
- `log_box "message"` - Boxed message with borders
- `log_step "1" "5" "message"` - Step counter [1/5]
- `log_bullet "message"` - Bullet point
- `log_check "message"` - Success with checkmark ✓
- `log_cross "message"` - Error with cross ✗
- `log_arrow "message"` - Arrow pointer →

**Usage:**
```bash
source "$SCRIPT_DIR/lib/logging.sh"
log_success "Operation completed!"
log_error "Something went wrong"
```

### paths.sh

Path discovery and management functions.

**Functions:**
- `get_script_dir` - Get script directory
- `get_meta_repo_root` - Get meta repo root
- `get_workspace_dir` - Get repos/ directory
- `get_feature_workspace_dir "item-42"` - Get feature workspace
- `get_feature_repos_dir "item-42"` - Get feature repos directory
- `get_specs_dir` - Get features/specs directory
- `get_plans_dir` - Get features/implementation-plans directory
- `get_spec_file "item-42"` - Get spec file path
- `get_plan_file "item-42"` - Get plan file path
- `is_git_repo "path"` - Check if directory is git repo

**Usage:**
```bash
source "$SCRIPT_DIR/lib/paths.sh"
META_ROOT=$(get_meta_repo_root)
SPEC_FILE=$(get_spec_file "item-42")
```

### config.sh

Configuration file parsing (supports YAML and JSON).

**Functions:**
- `config_init "."` - Initialize config (finds services.yaml or .openspec/config.json)
- `config_list_services` - List all service names
- `config_get_service_type "service-name"` - Get service type
- `config_get_service_dependencies "service-name"` - Get dependencies
- `config_get_service_repo_url "service-name" "org"` - Get repo URL
- `config_get_service_short_name "service-name"` - Get short name
- `config_get_service_order "service-name"` - Get deployment order
- `config_get_github_org` - Get GitHub organization
- `config_get_project_name` - Get project name

**Usage:**
```bash
source "$SCRIPT_DIR/lib/config.sh"
config_init "."
while IFS= read -r service; do
    echo "Processing $service"
done < <(config_list_services)
```

**Automatic fallback:** If `services.yaml` doesn't exist, falls back to `.openspec/config.json` with warning.

### github.sh

GitHub operations and utilities.

**Functions:**
- `detect_github_org "repo-dir"` - Detect org from git remote
- `get_github_org "repo-dir"` - Get org with fallback to user input
- `clone_or_update_repo "name" "url" "target-dir"` - Clone or update repo
- `require_gh_cli` - Check if gh CLI is installed and authenticated
- `repo_exists "org" "repo"` - Check if GitHub repo exists
- `create_repo "org" "repo" "description" "private"` - Create GitHub repo

**Usage:**
```bash
source "$SCRIPT_DIR/lib/github.sh"
GITHUB_ORG=$(get_github_org ".")
clone_or_update_repo "my-service" "$repo_url" "$target_dir"
```

### services.sh

Service dependency resolution and ordering.

**Functions:**
- `get_services_in_order` - Get services in deployment order (topological sort)
- `get_services_in_reverse_order` - Get services in reverse order (for cleanup)
- `has_dependencies "service-name"` - Check if service has dependencies
- `get_all_dependencies "service-name"` - Get all dependencies recursively
- `validate_dependencies` - Validate no circular dependencies
- `service_exists "service-name"` - Check if service exists in config
- `service_info "service-name"` - Show service information
- `list_services` - List all services with dependencies

**Usage:**
```bash
source "$SCRIPT_DIR/lib/services.sh"
while IFS= read -r service; do
    deploy_service "$service"
done < <(get_services_in_order)
```

### validation.sh

Input validation and requirement checking.

**Functions:**
- `require_command "cmd" "install-msg"` - Check if command exists
- `require_commands "cmd1" "cmd2" ...` - Check multiple commands
- `validate_item_number "42"` - Validate item number format
- `validate_branch_name "feature/test"` - Validate branch name
- `require_directory "path" "create"` - Check directory exists (optionally create)
- `require_file "path"` - Check file exists
- `require_git_repo "path"` - Check if directory is git repo
- `validate_github_org "org-name"` - Validate GitHub org format
- `validate_service_name "service-name"` - Validate service name format
- `validate_url "url"` - Validate URL format
- `confirm "message" "default"` - Ask user for confirmation
- `require_confirmation "message"` - Require confirmation or exit

**Usage:**
```bash
source "$SCRIPT_DIR/lib/validation.sh"
validate_item_number "$ITEM_NUMBER" || exit 1
if confirm "Continue?" "y"; then
    echo "Proceeding..."
fi
```

## Configuration File: services.yaml

All scripts read from `services.yaml` (or fall back to `.openspec/config.json`).

**Example:**
```yaml
version: "2.0"
project:
  name: "Concepto"
  github:
    organization: "tristanl-slalom"
    project:
      number: 1

services:
  - name: "concepto-be-tasks"
    type: "backend"
    description: "Tasks microservice"
    repository:
      url: "git@github.com:{org}/concepto-be-tasks.git"
      short_name: "tasks"
    dependencies: []
    deployment:
      order: 1

  - name: "concepto-bff"
    type: "backend"
    dependencies:
      - "concepto-be-tasks"
    deployment:
      order: 2

  - name: "concepto-fe"
    type: "frontend"
    dependencies:
      - "concepto-bff"
    deployment:
      order: 3
```

See [docs/development/config-schema.md](../docs/development/config-schema.md) for complete schema reference.

## Adding a New Service

To add a new service to the platform:

1. **Edit services.yaml:**
   ```yaml
   - name: "concepto-be-users"
     type: "backend"
     repository:
       url: "git@github.com:{org}/concepto-be-users.git"
       short_name: "users"
     dependencies:
       - "concepto-be-tasks"
     deployment:
       order: 4
   ```

2. **Validate configuration:**
   ```bash
   ./scripts/validate-config.sh
   ```

3. **Set up workspace:**
   ```bash
   ./scripts/setup-workspace.sh
   ```

All scripts will automatically detect and process the new service!

See [docs/development/adding-microservices.md](../docs/development/adding-microservices.md) for detailed guide.

## Backwards Compatibility

All scripts support both configuration formats:

**Priority:**
1. `services.yaml` (new format) - Used if present
2. `.openspec/config.json` (legacy format) - Fallback with warning

**Migration:**
```bash
./scripts/migrate-config.sh
```

## Common Workflows

### Starting Work on a New Feature

```bash
# 1. Start item orchestration
./scripts/start-item.sh 42

# 2. Claude fills in spec (prompted by script)
# 3. Claude creates plan (prompted by script)

# 4. Implement changes in feature workspace
cd features/workspaces/item-42/repos/concepto-be-tasks
# ... make changes ...

# 5. Create PRs
./scripts/create-prs.sh 42
```

### Working with Feature Branches

```bash
# Create branches
./scripts/create-feature-branch.sh feature/my-feature

# Check status
./scripts/workspace-status.sh

# Push branches
./scripts/push-feature-branch.sh feature/my-feature
```

### Configuration Management

```bash
# Validate configuration
./scripts/validate-config.sh

# Migrate from legacy config
./scripts/migrate-config.sh

# View service list
source scripts/lib/services.sh
config_init .
list_services
```

## Troubleshooting

### "Configuration not loaded" error

**Solution:** Ensure you call `config_init` before using config functions:
```bash
source "$SCRIPT_DIR/lib/config.sh"
config_init "." || exit 1
```

### "yq is not installed" error

**Solution:** Install yq for YAML parsing:
```bash
brew install yq
```

### "Service not found" error

**Solution:** Check that the service is defined in `services.yaml`:
```bash
./scripts/validate-config.sh
```

### Scripts using legacy config

**Solution:** Create `services.yaml` or migrate:
```bash
./scripts/migrate-config.sh
```

### Circular dependency error

**Solution:** Check dependencies in `services.yaml`:
```bash
source scripts/lib/services.sh
config_init .
validate_dependencies
```

## Best Practices

1. **Always validate config after changes:**
   ```bash
   ./scripts/validate-config.sh
   ```

2. **Use library functions instead of duplicating code:**
   ```bash
   source "$SCRIPT_DIR/lib/logging.sh"
   log_success "Done!"  # Instead of echo -e "${GREEN}Done!${NC}"
   ```

3. **Handle errors gracefully:**
   ```bash
   config_init "$META_REPO_ROOT" || exit 1
   ```

4. **Use config-driven loops:**
   ```bash
   while IFS= read -r service; do
       process "$service"
   done < <(get_services_in_order)
   ```

5. **Test with both config formats:**
   - Test with `services.yaml`
   - Test with `.openspec/config.json`
   - Verify warning messages

## Development

### Creating a New Script

Template for config-driven scripts:

```bash
#!/bin/bash
set -e

# Source libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/services.sh"

# Initialize
META_REPO_ROOT=$(get_meta_repo_root "$SCRIPT_DIR")
config_init "$META_REPO_ROOT" || exit 1

# Your script logic here
while IFS= read -r service; do
    log_info "Processing $service"
    # ... do something with service ...
done < <(get_services_in_order)

log_success "Done!"
```

### Testing Scripts

```bash
# Test with main config
./scripts/your-script.sh

# Test with legacy config
mv services.yaml services.yaml.tmp
./scripts/your-script.sh
mv services.yaml.tmp services.yaml

# Validate no syntax errors
bash -n scripts/your-script.sh
```

## References

- [Configuration Schema Reference](../docs/development/config-schema.md)
- [Adding Microservices Guide](../docs/development/adding-microservices.md)
- [Implementation Summary](../IMPLEMENTATION_SUMMARY.md)
- [CLAUDE.md](../CLAUDE.md) - Claude Code instructions
