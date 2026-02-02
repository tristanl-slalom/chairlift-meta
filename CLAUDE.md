# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **chairlift-meta** repository - the orchestration hub for the Slalom Chairlift airline booking platform. It coordinates development across five service repositories using automated workflows that handle everything from GitHub issues to pull requests.

## Architecture Overview

Slalom Chairlift is a serverless airline booking application on AWS with five independent services:

1. **chairlift-be-flights** - Flight search and inventory management (Node.js 20, Lambda, DynamoDB)
2. **chairlift-be-customers** - Customer profiles and loyalty programs (Node.js 20, Lambda, DynamoDB)
3. **chairlift-be-bookings** - Booking and reservation management (Node.js 20, Lambda, DynamoDB)
4. **chairlift-bff** - Backend for Frontend aggregation layer (Node.js 20, Lambda, API Gateway)
5. **chairlift-fe** - React booking interface (React 18, Vite, S3 + CloudFront)

**Dependency Chain**:
- Flights and Customers are independent (deploy first)
- Bookings depends on Flights + Customers
- BFF depends on all three backend services
- Frontend depends on BFF

**Infrastructure**: All services use AWS CDK for infrastructure as code. Feature branches automatically deploy isolated infrastructure with branch-specific CloudFormation stacks.

## Configuration System

The platform uses a **config-driven automation system** defined in `services.yaml` at the repository root.

### Configuration File: services.yaml

All service repositories, dependencies, and deployment orders are defined in a single YAML file. See `services.yaml` in the root directory.

**Key benefits**:
- Single source of truth for all services
- Automatic dependency resolution
- N-service scalability
- Validates configuration before operations

### Script Libraries

All automation scripts use shared libraries from `scripts/lib/`:

- **colors.sh** - Color definitions
- **logging.sh** - Logging functions (log_info, log_success, log_error)
- **config.sh** - Configuration parsing (supports services.yaml)
- **services.sh** - Dependency resolution (get_services_in_order, validate_dependencies)
- **paths.sh** - Path management
- **github.sh** - GitHub operations
- **validation.sh** - Input validation

## Domain Model

### Flights Service
- Flight inventory management
- Route and schedule management
- Seat availability tracking
- Pricing management
- Airport operations

### Customers Service
- Customer profile management
- Loyalty program (tiers: Silver, Gold, Platinum)
- Preference management (seats, meals)
- Account management

### Bookings Service
- Booking creation and management
- Passenger management
- Payment processing
- Booking status lifecycle
- Integration with flights (seat allocation) and customers (loyalty points)

### BFF (Aggregation)
- Aggregates data from all backend services
- Provides simplified endpoints for frontend
- Example: Get booking details with flight and customer info in single call

## Database Schemas

### chairlift-flights
- **PK**: `FLIGHT#{flightId}`
- **SK**: `METADATA`
- **GSI1** (Route): `ROUTE#{origin}#{destination}` / `DATE#{date}#TIME#{time}`
- **GSI2** (Airline): `AIRLINE#{code}` / `DATE#{date}`
- **GSI3** (Airport): `AIRPORT#{origin}` / `DATE#{date}#TIME#{time}`

### chairlift-customers
- **PK**: `CUSTOMER#{customerId}`
- **SK**: `PROFILE`
- **GSI1** (Email): `EMAIL#{email}` / `CUSTOMER#{customerId}`
- **GSI2** (Loyalty): `TIER#{tierLevel}` / `POINTS#{totalPoints}`

### chairlift-bookings
- **PK**: `BOOKING#{bookingId}`
- **SK**: `METADATA`
- **GSI1** (Customer): `CUSTOMER#{customerId}` / `CREATED#{timestamp}`
- **GSI2** (Flight): `FLIGHT#{flightId}` / `BOOKING#{bookingId}`
- **GSI3** (Status): `STATUS#{status}` / `CREATED#{timestamp}`
- **GSI4** (Confirmation): `CONFIRMATION#{code}` / `BOOKING#{bookingId}`

## Implementation Order

Always implement in dependency order:
1. **chairlift-be-flights** and **chairlift-be-customers** (parallel - both independent)
2. **chairlift-be-bookings** (depends on flights + customers)
3. **chairlift-bff** (depends on all backends)
4. **chairlift-fe** (depends on BFF)

## Common Commands

### Testing

Run tests in each service repo:
```bash
# Backend services
npm test                    # Run all tests (Jest)
npm run test:watch         # Watch mode
npm run test:coverage      # Generate coverage report

# Frontend
npm test                   # Run all tests (Vitest)
npm run test:ui           # Visual test UI
npm run test -- --coverage # Coverage report
```

### Building

```bash
# All services
npm run build              # Compile TypeScript
npm run lint              # Check code style
npm run lint:fix          # Fix linting issues

# Frontend only
npm run dev               # Start dev server (port 5173)
```

### Infrastructure

```bash
# Deploy to AWS (from service repo)
npm run cdk:deploy        # Deploy CloudFormation stack
npm run cdk:synth         # Preview CloudFormation template
npm run cdk:destroy       # Delete stack
```

## Critical Patterns

### DynamoDB: Never Use Scan

**IMPORTANT**: The codebase follows ADR-004 which mandates **no Scan operations**. When retrieving multiple items, query each partition individually and merge results using `Promise.all()`.

### Multi-Service Integration

The bookings service calls flights and customers services:
- Validate customer exists before booking
- Check flight availability
- Update seat inventory after booking
- Award loyalty points

The BFF aggregates all backend services for simplified frontend consumption.

### CloudFormation Export Resolution

Services find dependencies via CloudFormation exports with branch-aware naming:

```typescript
const branch = BranchConfig.getBranch();
const exportName = 'ChairliftFlightsApiUrl' + (branch === 'main' ? '' : BranchConfig.normalized);
const flightsUrl = cdk.Fn.importValue(exportName);
```

## Automation Scripts

Located in `scripts/` directory:

| Script | Purpose |
|--------|---------|
| `bootstrap-microservice.sh` | Create new microservice from template |
| `setup-workspace.sh` | Clone service repos |
| `validate-config.sh` | Validate services.yaml |
| `create-prs.sh` | Create PRs across repos |

## Testing Strategy

- **Backend**: Jest tests with DynamoDB Local
- **Frontend**: Vitest + React Testing Library
- **Integration**: Multi-service scenarios with mocks
- **E2E**: Playwright for complete booking flows

## Key Takeaways

1. **5-service architecture**: Flights, Customers, Bookings, BFF, Frontend
2. **Dependency order**: Always deploy backends before BFF, BFF before frontend
3. **No DynamoDB Scans**: Query partitions in parallel
4. **Aggregation pattern**: BFF combines multiple service responses
5. **Branch-aware infrastructure**: Feature branches get isolated AWS stacks
