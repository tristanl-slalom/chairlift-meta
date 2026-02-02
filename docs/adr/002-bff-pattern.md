# ADR-002: Adopt Backend for Frontend (BFF) Pattern

## Status

Accepted

## Context

We need an architecture that decouples the frontend from backend microservices while providing a frontend-optimized API. As we grow, we may add mobile apps or other frontends with different requirements.

## Decision

We will implement a Backend for Frontend (BFF) pattern:
- Dedicated BFF service (concepto-bff) sits between frontend and microservices
- BFF handles request/response transformation for frontend needs
- BFF aggregates data from multiple services (future)
- Each frontend (web, mobile) can have its own BFF

## Consequences

### Positive Consequences

- **Frontend independence**: Frontend not coupled to microservice changes
- **Optimized responses**: BFF returns exactly what frontend needs
- **Simplified frontend**: Less logic in React components
- **Multiple frontends**: Each frontend can have tailored API
- **API aggregation**: BFF can combine data from multiple services
- **Backward compatibility**: BFF can adapt to microservice changes

### Negative Consequences

- **Additional hop**: Extra network call adds latency (~20-50ms)
- **More code**: BFF adds codebase to maintain
- **Duplication**: Some logic duplicated between BFF and services
- **Deployment complexity**: One more service to deploy

## Alternatives Considered

### Alternative 1: Direct Frontend-to-Microservice

**Description**: Frontend calls microservices directly.

**Pros**:
- Simpler architecture
- Lower latency
- Fewer moving parts

**Cons**:
- Frontend tightly coupled to microservices
- Difficult to make breaking changes
- Frontend handles aggregation logic
- Hard to support multiple frontends

**Decision**: Not chosen because coupling makes evolution difficult.

### Alternative 2: API Gateway with Transformations

**Description**: Use API Gateway request/response transformations instead of BFF.

**Pros**:
- No separate BFF service
- Lower latency
- Less code to maintain

**Cons**:
- Limited transformation capabilities (VTL)
- Difficult to test and debug
- Cannot aggregate multiple services
- VTL is complex for non-trivial logic

**Decision**: Not chosen because transformations are too limited.

## References

- [BFF Pattern](https://samnewman.io/patterns/architectural/bff/)
- [Backends for Frontends](https://learn.microsoft.com/en-us/azure/architecture/patterns/backends-for-frontends)

## Date

2024-01-01

## Authors

Concepto Development Team
