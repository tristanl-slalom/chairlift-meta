# ADR-003: Use AWS CDK for Infrastructure as Code

## Status

Accepted

## Context

We need to manage AWS infrastructure reliably with version control, repeatable deployments, and type safety. Options include CloudFormation templates (YAML/JSON), Terraform, AWS SAM, or AWS CDK.

## Decision

We will use AWS CDK (Cloud Development Kit) with TypeScript for all infrastructure:
- Define infrastructure in TypeScript (same language as application)
- Use L2/L3 constructs for higher-level abstractions
- Synthesize to CloudFormation for deployment
- Version infrastructure code alongside application code

## Consequences

### Positive Consequences

- **Type safety**: Catch errors at compile time
- **Code reuse**: Share constructs across stacks
- **Better IDE support**: Autocomplete and refactoring
- **Familiar language**: TypeScript used across stack
- **Higher-level abstractions**: L2/L3 constructs hide complexity
- **Built-in best practices**: Constructs include AWS best practices
- **Testable**: Can write unit tests for infrastructure

### Negative Consequences

- **Learning curve**: Developers must learn CDK concepts
- **Compilation required**: Extra step vs YAML
- **Less portable**: Harder to migrate to other clouds
- **Generated CloudFormation**: Hard to debug generated templates
- **CDK version updates**: May require code changes

## Alternatives Considered

### Alternative 1: CloudFormation (YAML)

**Pros**: Native AWS, no dependencies, portable
**Cons**: Verbose, no type safety, hard to reuse

**Decision**: Not chosen due to lack of type safety and reusability.

### Alternative 2: Terraform

**Pros**: Multi-cloud, mature ecosystem, HCL is declarative
**Cons**: Separate language to learn, state management complexity

**Decision**: Not chosen because we're AWS-only and want type safety.

### Alternative 3: AWS SAM

**Pros**: Simpler than CDK, good for serverless
**Cons**: YAML-based, less flexible, limited to serverless

**Decision**: Not chosen because we want programmatic infrastructure.

## References

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [CDK Best Practices](https://docs.aws.amazon.com/cdk/v2/guide/best-practices.html)

## Date

2024-01-01

## Authors

Concepto Development Team
