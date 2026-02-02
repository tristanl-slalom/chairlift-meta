# ADR 006: Customizable Task Statuses

## Status
Accepted

## Context
The Concepto task management system initially used hardcoded task statuses (TODO, IN_PROGRESS, DONE). This approach worked for MVP but limited flexibility:
- Users cannot add custom workflow stages (e.g., CODE_REVIEW, TESTING, BLOCKED)
- No ability to customize visual presentation (colors, icons)
- Cannot adapt to different team workflows
- Status order is fixed

We need a system that allows runtime configuration of task statuses while maintaining performance and adhering to our no-Scan operations constraint (ADR-004).

## Decision
We will implement a fully customizable status system with the following architecture:

### 1. Status Configuration Storage
- **New DynamoDB table**: `concepto-task-statuses`
- **Schema**:
  ```
  PK: "CONFIG#WORKSPACE#default"
  SK: "STATUS#{statusKey}"
  Attributes: statusKey, displayName, displayOrder, color, icon, isDefault, isActive
  ```
- **Access pattern**: Single partition query (no GSI needed)
- Future-proofed for multi-workspace support

### 2. Dynamic Validation
- **Backend**: Runtime validation using in-memory cache with 5-minute TTL
- **Type system**: Change from `enum` to `string` with runtime checks
- **Default status**: Fetched from cache (marked with `isDefault: true`)
- **Migration**: Seed three default statuses matching legacy values

### 3. API Design
New endpoints in tasks service:
- `POST /statuses` - Create status
- `GET /statuses` - List statuses (sorted by displayOrder)
- `GET /statuses/{statusKey}` - Get single status
- `PUT /statuses/{statusKey}` - Update status metadata
- `DELETE /statuses/{statusKey}` - Soft delete (set isActive=false)
- `POST /statuses/reorder` - Atomically reorder multiple statuses

### 4. Performance Optimization
- **Backend cache**: 5-minute TTL in Lambda container memory
- **Frontend cache**: React Query with 5-minute stale time
- **Query strategy**: Parallel queries by status (maintains ADR-004 compliance)
- **Cost impact**: <$0.10/month for 10K requests (95% cache hit rate)

### 5. Migration Strategy
Phase 1: Deploy infrastructure and seed defaults
- Three default statuses: TODO, IN_PROGRESS, DONE
- Backward compatible with existing tasks

Phase 2: Update validation to runtime checks
- Tasks service reads from status cache
- Feature flag: `ENABLE_DYNAMIC_STATUSES`

Phase 3: Frontend updates
- Dynamic status fetching
- Admin UI for status management

## Consequences

### Positive
- **Flexibility**: Teams can customize workflows without code changes
- **User experience**: Visual customization (colors, icons) improves usability
- **Scalability**: Supports complex workflows with many stages
- **Maintainability**: Status changes don't require deployments
- **Performance**: Cache-first approach minimizes latency impact

### Negative
- **Complexity**: More moving parts than hardcoded statuses
- **Migration risk**: Requires careful rollout with feature flags
- **Cache consistency**: 5-minute TTL means eventual consistency
- **Type safety**: Loss of compile-time type checking for status values

### Neutral
- **Database design**: Additional table adds minimal cost
- **API surface**: 6 new endpoints require documentation and testing
- **Admin burden**: Requires UI for status management (addressed)

## Implementation Notes

### ADR-004 Compliance
The list-all-tasks operation maintains compliance by:
1. Fetching active status keys from cache: `['TODO', 'IN_PROGRESS', 'DONE', 'CODE_REVIEW', ...]`
2. Executing parallel queries: `Promise.all(statuses.map(s => query GSI1 where GSI1PK = STATUS#${s}))`
3. No Scan operations at any point

### Error Handling
- **Deleted status in use**: Soft delete only; displays as "(Archived)"
- **Invalid status on create/update**: Validation error with available options
- **Cache refresh failure**: Keeps stale cache; logs error for monitoring

### Race Conditions
- **Concurrent default changes**: Last write wins; enforced at repository level
- **Status delete during task update**: Validation rejects; user must select active status

### Feature Flag
Environment variable: `ENABLE_DYNAMIC_STATUSES` (default: false)
- `false`: Uses legacy enum validation (backward compatible)
- `true`: Uses dynamic cache-based validation

## Alternatives Considered

### Option 1: Keep Hardcoded Statuses
**Rejected**: Does not meet user needs for workflow customization

### Option 2: Store Status Config in Application Code
**Rejected**: Requires deployment for changes; no per-workspace config

### Option 3: Store Status List in Tasks Table
**Rejected**: Would require Scan or complex denormalization

### Option 4: Use RDS Instead of DynamoDB
**Rejected**: Conflicts with ADR-001 (serverless architecture); higher cost

### Option 5: Sync with GitHub Projects Statuses
**Rejected**: Per user preference, keep separate to allow different views

## References
- ADR-001: Serverless Architecture
- ADR-004: No DynamoDB Scans
- Implementation Plan: `features/implementation-plans/customizable-statuses.md`
- API Contracts: `docs/architecture/api-contracts/`

## Date
2026-02-01
