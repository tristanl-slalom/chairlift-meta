# ADR-004: Avoid DynamoDB Scan Operations

## Status

Accepted

## Context

DynamoDB Scan operations are costly and inefficient compared to Query operations. Scans read every item in a table or index, consuming significant read capacity and incurring higher costs. In contrast, Query operations use partition keys to efficiently retrieve only the items needed.

For the Concepto task management application, we need to implement list operations that can retrieve all tasks regardless of status. The naive approach would use a Scan operation, but this violates performance and cost best practices.

## Decision

The application will **never use DynamoDB Scan operations**. This is a hard rule across all repositories.

When retrieving all items without a specific partition key filter, we will:
1. Query each known partition individually using the GSI
2. Execute queries in parallel using `Promise.all()`
3. Merge results from all partitions

For the tasks service specifically:
- When listing tasks without a status filter, query GSI1 for each status (TODO, IN_PROGRESS, DONE) individually
- Execute the three queries in parallel
- Merge and return the combined results

## Consequences

### Positive Consequences

- **Predictable Performance**: Query operations have consistent, fast response times based on partition size
- **Lower Costs**: Queries consume only the capacity needed for the items returned, not the entire table
- **Better Scalability**: Performance doesn't degrade as the table grows, since we're querying specific partitions
- **More Efficient**: Only reads the items we need rather than filtering after reading everything

### Negative Consequences

- **More Complex Code**: Requires querying multiple partitions and merging results instead of a single Scan call
- **Fixed Partition Count**: Adding new statuses requires code changes to include them in the parallel queries
- **Multiple Network Calls**: Three API calls to DynamoDB instead of one (mitigated by parallel execution)
- **Potential for Inconsistency**: If statuses are added to the enum but not to the query list, those items won't appear in "list all" results

## Alternatives Considered

### Alternative 1: Use Scan with FilterExpression

**Description**: Use DynamoDB Scan with a FilterExpression to retrieve all tasks by filtering on the PK prefix (`TASK#`).

**Pros**:
- Simple to implement (single API call)
- Automatically includes any items regardless of status
- Fewer lines of code

**Cons**:
- Reads entire table, consuming high read capacity
- Performance degrades linearly with table size
- Higher AWS costs due to reading all items
- Unpredictable response times under load

**Decision**: Not chosen because it violates DynamoDB best practices and incurs unnecessary costs.

### Alternative 2: Maintain a Separate "All Items" Partition

**Description**: Duplicate each task into a special partition (e.g., `ALL#TASK`) specifically for listing all items.

**Pros**:
- Single Query operation to list all tasks
- Predictable performance
- Maintains no-Scan rule

**Cons**:
- Doubles storage costs (every task stored twice)
- More complex write operations (must write to two partitions)
- Risk of data inconsistency between partitions
- Increased write capacity consumption

**Decision**: Not chosen because the storage and complexity costs outweigh the benefit, especially when we have a small, known set of statuses to query.

### Alternative 3: Change Data Model to Single Partition

**Description**: Store all tasks in a single partition (e.g., PK=`TASK`, SK=`{uuid}`) to enable single Query.

**Pros**:
- Single Query operation
- Simple code

**Cons**:
- Partition size limit of 10GB becomes a hard constraint
- Hot partition under high load (all reads/writes to same partition)
- Loses ability to efficiently filter by status without GSI
- Poor scalability as application grows

**Decision**: Not chosen because it creates a scalability bottleneck and limits future growth.

## References

- [DynamoDB Best Practices: Use Query, Not Scan](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-query-scan.html)
- [Implementation: task.repository.ts:154-184](../../../concepto-be-tasks/src/repositories/task.repository.ts)

## Date

2026-02-01

## Authors

Tristan Langford, Claude Sonnet 4.5
