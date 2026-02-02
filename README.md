# Slalom Chairlift - Meta Repository

Orchestration hub for the Slalom Chairlift airline booking platform.

## Architecture

5 microservices in dependency order:

1. **chairlift-be-flights** - Flight search and inventory
2. **chairlift-be-customers** - Customer profiles and loyalty
3. **chairlift-be-bookings** - Booking management (depends on flights + customers)
4. **chairlift-bff** - Backend for Frontend (depends on all backends)
5. **chairlift-fe** - React frontend (depends on BFF)

## Quick Start

```bash
# Validate configuration
./scripts/validate-config.sh

# Clone all service repos
./scripts/setup-workspace.sh

# Bootstrap a new microservice
./scripts/bootstrap-microservice.sh
```

## Documentation

- **CLAUDE.md** - Guidance for Claude Code
- **docs/adr/** - Architecture Decision Records
- **services.yaml** - Service configuration

## Services

All services defined in `services.yaml` with dependencies and deployment order.
