# ADR 005: Feature Branch Orchestration with Centralized Cleanup

## Status

Accepted

## Context

Developers need isolated infrastructure environments to test feature branches without:
- Manually provisioning AWS resources
- Interfering with other developers' work
- Affecting production (main branch)
- Leaving orphaned infrastructure that increases costs

The Concepto platform consists of three interdependent services:
- `concepto-be-tasks` (Tasks microservice with DynamoDB)
- `concepto-bff` (Backend for Frontend, proxies to Tasks)
- `concepto-fe` (React frontend, consumes BFF API)

Requirements:
1. Push feature branch → Auto-deploy isolated infrastructure
2. Each branch gets separate CloudFront distribution (per product requirements)
3. Each branch gets separate DynamoDB tables for data isolation
4. Delete branch → Auto-cleanup infrastructure
5. BFF/Frontend should fall back to main branch if dependency doesn't exist

## Decision

We will implement **automated feature branch infrastructure deployment** with **centralized cleanup orchestration** using the following approach:

### 1. Decentralized Deployment

Each service repository (`concepto-be-tasks`, `concepto-bff`, `concepto-fe`) handles its own deployment:

- **Branch Config Module**: Identical `infrastructure/lib/branch-config.ts` in each repo
  - Detects branch name from GitHub Actions or git
  - Normalizes to CloudFormation-safe format
  - Generates PascalCase for exports
  - Not a shared npm package (simplicity over DRY)

- **CDK Stack Modifications**: Accept `BranchConfig` parameter
  - Resource names include branch suffix (e.g., `concepto-tasks-feature-auth`)
  - Export names include branch suffix (e.g., `ConceptoTasksApiUrlFeatureAuth`)
  - RemovalPolicy: RETAIN for main, DESTROY for feature branches
  - All resources tagged with branch name

- **GitHub Actions CD Workflow**: Trigger on all branches
  - Detect and normalize branch name
  - Check if dependency exports exist (BFF checks Tasks, Frontend checks BFF)
  - Set environment variable with export name to use
  - Deploy via CDK

### 2. Centralized Cleanup Orchestration

The `concepto-meta` repository owns cleanup:

- **Webhook Trigger**: Each service repo sends webhook on branch deletion
  - Uses `on: delete` GitHub event
  - Sends `repository_dispatch` to meta repo
  - Payload includes branch name and source repo

- **Cleanup Workflow**: Meta repo's `.github/workflows/cleanup-branch-stacks.yml`
  - Normalizes branch name (same logic as deployment)
  - Deletes stacks in reverse dependency order: Frontend → BFF → Tasks
  - Uses `continue-on-error: true` for resilience
  - Checks stack existence before deletion
  - Waits for completion before next deletion

### 3. Dependency Resolution Strategy

Services resolve dependencies with fallback:

- **BFF Service**:
  1. Workflow checks if `ConceptoTasksApiUrl{Branch}` export exists
  2. If yes: Set `TASKS_EXPORT_NAME` env var to branch-specific export
  3. If no: Set `TASKS_EXPORT_NAME` to `ConceptoTasksApiUrl` (main)
  4. CDK imports using env var value

- **Frontend Service**:
  1. Workflow checks if `ConceptoBffApiUrl{Branch}` export exists
  2. If yes: Use branch-specific BFF stack for URL
  3. If no: Use main BFF stack
  4. Fetch BFF URL and pass to Vite build
  5. CDK imports using env var value

### 4. Resource Management

- **Main Branch**: RETAIN policy, point-in-time recovery enabled
- **Feature Branches**: DESTROY policy, auto-delete enabled
- **Tagging**: All resources tagged with `Branch` and `ManagedBy`

## Alternatives Considered

### Alternative 1: Shared npm Package for Branch Config

**Rejected because**:
- Adds dependency management overhead
- Version mismatches between repos
- Build/publish pipeline needed
- Deployment complexity (ensure package updated first)

**Current approach**: Copy identical file to three repos
- Simple to understand
- No dependencies
- Easy to update (copy changes)
- Each repo independently deployable

### Alternative 2: Each Repo Cleans Up Its Own Stack

**Rejected because**:
- No coordination for deletion order
- BFF deletion fails if Frontend still references it
- Each repo needs to know about dependents
- No single manual override point
- Circular dependency problem

**Current approach**: Meta repo orchestrates cleanup
- Knows all repos and dependencies
- Controls deletion order
- Single point for manual cleanup
- Resilient to partial failures

### Alternative 3: Shared DynamoDB with Branch Prefix Keys

**Rejected because**:
- Complex queries (need to filter by prefix)
- Risk of cross-branch data leakage
- Harder to delete (need to scan and delete items)
- No true isolation

**Current approach**: Separate DynamoDB table per branch
- Complete data isolation
- Simple queries (no prefix filtering)
- Clean deletion (drop entire table)
- Follows "infrastructure as code immutability" principle

### Alternative 4: Lambda Function for Cleanup

**Rejected because**:
- Less transparent (Lambda logs vs. GitHub Actions UI)
- Workflow timeout limits (but sufficient for our use case)
- Need to deploy/maintain Lambda function
- Harder to debug

**Current approach**: GitHub Actions workflow
- Visible in GitHub UI
- Easy to debug (step-by-step logs)
- Can be manually triggered
- No additional infrastructure

### Alternative 5: GitHub App Instead of PAT

**Rejected because**:
- More complex setup (app registration, webhooks)
- More moving parts
- Overkill for simple webhook trigger
- Harder to rotate credentials

**Current approach**: Personal Access Token
- Simple setup
- Easy to rotate
- Sufficient security for webhook
- Standard GitHub pattern

## Consequences

### Positive

- ✅ **Developer Productivity**: Push branch, get isolated environment
- ✅ **Parallel Development**: No conflicts between feature branches
- ✅ **Automatic Cleanup**: No manual infrastructure management
- ✅ **Cost Control**: Auto-delete prevents forgotten resources
- ✅ **True Isolation**: Separate CloudFront, DynamoDB, Lambda per branch
- ✅ **Flexible Deployment**: Can deploy 1, 2, or 3 services independently
- ✅ **Production Safety**: Main branch always protected (RETAIN policy)
- ✅ **Observable**: GitHub Actions UI, CloudFormation events, resource tags

### Negative

- ⚠️ **CloudFormation Export Limit**: 200 per region (~60-100 concurrent branches max)
- ⚠️ **Branch Rename**: Orphaned stacks require manual cleanup
- ⚠️ **Cost**: Each branch creates full infrastructure (but minimal without traffic)
- ⚠️ **Deployment Time**: CloudFront takes 10-15 minutes
- ⚠️ **Code Duplication**: Branch config file copied to three repos
- ⚠️ **PAT Management**: Need to rotate Personal Access Token periodically

### Mitigation Strategies

| Risk | Mitigation |
|------|------------|
| Export limit reached | Monitor count, alert at 150, document cleanup procedure |
| Branch rename orphans stack | Document in runbook, provide manual cleanup workflow |
| Cost overrun | Tag resources for cost tracking, auto-delete on branch deletion |
| PAT expiration | Document rotation procedure, use long-lived token |
| Code duplication (branch-config.ts) | Accept trade-off for simplicity, update all repos together |

## Implementation

### Repositories Affected

- `concepto-be-tasks`: 5 files (branch-config, app, stack, cd.yml, trigger-cleanup)
- `concepto-bff`: 5 files (branch-config, app, stack, cd.yml, trigger-cleanup)
- `concepto-fe`: 5 files (branch-config, app, stack, cd.yml, trigger-cleanup)
- `concepto-meta`: 1 file (cleanup-branch-stacks.yml)

### Configuration Required

**GitHub Environments** (all service repos):
- `production` - For main branch
- `feature` - For feature branches

**GitHub Secrets** (all service repos):
- `AWS_ROLE_ARN` - IAM role for deployments
- `AWS_REGION` - Target region
- `META_REPO_TRIGGER_TOKEN` - PAT for webhook

**GitHub Secrets** (meta repo):
- `AWS_ROLE_ARN` - IAM role for cleanup
- `AWS_REGION` - Target region

### Deployment Order

For full-stack features:
1. Tasks (no dependencies)
2. BFF (depends on Tasks)
3. Frontend (depends on BFF)

Cleanup order: Reverse (Frontend → BFF → Tasks)

## Future Considerations

Potential enhancements not in current scope:

1. **Time-based Cleanup**: Auto-delete branches older than N days
2. **Cost Dashboard**: Per-branch cost visualization
3. **Slack Notifications**: Deployment/cleanup alerts
4. **Preview URLs in PRs**: Auto-comment CloudFront URL
5. **Stack Snapshots**: Backup before deletion
6. **Export Count Monitoring**: Auto-alert near limit

## References

- [Feature Branch Orchestration Architecture](../architecture/feature-branch-orchestration.md)
- [Feature Branch Workflow Guide](../development/feature-branch-workflow.md)
- [AWS CloudFormation Limits](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cloudformation-limits.html)
- [GitHub Actions `delete` Event](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#delete)
- [CloudFormation Export/Import](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-stack-exports.html)

## Decision Makers

- Architecture Team
- Platform Team
- Development Team

## Date

2025-02-01
