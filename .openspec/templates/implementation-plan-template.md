# [Feature Name] - Implementation Plan

## Metadata

- **ID**: PLAN-XXXX
- **Created**: YYYY-MM-DD
- **Author**: [Your Name]
- **Status**: Draft | Ready | In Progress | Completed
- **Related Spec**: [Link to specification]
- **Feature Branch**: `feature/branch-name`

## Overview

Brief description of what will be implemented and the approach.

## Implementation Strategy

### Phase 1: [Phase Name]

**Objective**: [What this phase achieves]

**Repos Affected**:
- [ ] concepto-be-tasks
- [ ] concepto-bff
- [ ] concepto-fe

**Files to Create/Modify**:
1. `repo/path/to/file1.ts` - [Description]
2. `repo/path/to/file2.ts` - [Description]

**Tasks**:
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

### Phase 2: [Phase Name]

[Same structure as Phase 1]

## Detailed Changes

### concepto-be-tasks

#### New Files

**`src/handlers/new-handler.ts`**
```typescript
// Implementation preview
export const handler = async (event) => {
  // ...
};
```

#### Modified Files

**`src/existing-file.ts`**
- Line 45: Add new import
- Line 100-120: Modify existing function

### concepto-bff

#### New Files

[List new files]

#### Modified Files

[List modifications]

### concepto-fe

#### New Files

[List new files]

#### Modified Files

[List modifications]

## Database Migrations

### Migration: `YYYY-MM-DD-migration-name`

**Up Migration**:
```sql
CREATE TABLE new_table (
  id UUID PRIMARY KEY,
  field VARCHAR(255) NOT NULL
);
```

**Down Migration**:
```sql
DROP TABLE new_table;
```

## Dependencies

### New npm Packages

**concepto-be-tasks**:
- `package-name@version` - Purpose

**concepto-bff**:
- `package-name@version` - Purpose

**concepto-fe**:
- `package-name@version` - Purpose

### AWS Resources

- New Lambda function: `concepto-new-function`
- New DynamoDB table: `concepto-new-table`
- Modified IAM policies: [List changes]

## Testing Plan

### Unit Tests

**concepto-be-tasks**:
- [ ] `tests/handlers/new-handler.test.ts`

**concepto-bff**:
- [ ] `tests/handlers/new-handler.test.ts`

**concepto-fe**:
- [ ] `tests/components/NewComponent.test.tsx`

### Integration Tests

- [ ] Test scenario 1
- [ ] Test scenario 2

### E2E Tests

- [ ] User flow 1
- [ ] User flow 2

## Deployment Steps

### Pre-Deployment

1. [ ] Create feature branch across all repos
2. [ ] Update dependencies in all repos
3. [ ] Run database migrations in feature environment

### Deployment

1. [ ] Deploy concepto-be-tasks
   - Wait for deployment to complete
   - Verify CloudFormation export created

2. [ ] Deploy concepto-bff
   - Verify it finds Tasks export
   - Test BFF API endpoints

3. [ ] Deploy concepto-fe
   - Verify it finds BFF export
   - Test frontend functionality

### Post-Deployment

1. [ ] Smoke test all endpoints
2. [ ] Verify logs in CloudWatch
3. [ ] Check metrics in CloudWatch
4. [ ] Test end-to-end user flow

## Rollback Plan

### If Deployment Fails

1. Delete feature branch (triggers auto-cleanup)
2. Investigate failure in logs
3. Fix issues locally
4. Re-deploy

### If Bug Discovered After Deployment

1. Stop work on feature branch
2. Create hotfix branch from main
3. Deploy hotfix
4. Return to feature branch with fix

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking change in existing API | Add feature flag, gradual rollout |
| Database migration fails | Test migration in feature environment first |
| Performance degradation | Load test before merging to main |

## Success Criteria

- [ ] All tests pass
- [ ] Feature deployed to feature environment
- [ ] Manual testing completed
- [ ] Code review approved
- [ ] Documentation updated

## Timeline

| Phase | Estimated Duration | Actual Duration |
|-------|-------------------|-----------------|
| Phase 1 | 2 days | - |
| Phase 2 | 3 days | - |
| Testing | 1 day | - |
| **Total** | **6 days** | **-** |

## Notes

### Implementation Notes

- Note 1
- Note 2

### Lessons Learned

- Lesson 1
- Lesson 2

## Checklist

### Before Starting

- [ ] Spec reviewed and approved
- [ ] Implementation plan reviewed
- [ ] Feature branch created
- [ ] Dependencies identified
- [ ] Team notified

### During Implementation

- [ ] Regular commits with clear messages
- [ ] Tests written alongside code
- [ ] Documentation updated
- [ ] Code follows style guide
- [ ] No console.log or debug code

### Before Merge

- [ ] All tests pass
- [ ] Code reviewed
- [ ] Documentation complete
- [ ] Changelog updated
- [ ] Feature tested end-to-end

## Related Documents

- Specification: [Link]
- ADR: [Link]
- Design docs: [Link]
