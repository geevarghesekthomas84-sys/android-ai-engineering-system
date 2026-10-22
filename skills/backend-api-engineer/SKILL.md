---
name: backend-api-engineer
description: Backend API engineering with Node.js/TypeScript (NestJS), Python (FastAPI), REST design, authentication, PostgreSQL, Redis, WebSockets, Docker, and production deployment
metadata:
  author: Custom
  keywords:
  - backend
  - api
  - nestjs
  - fastapi
  - rest
  - authentication
  - postgresql
  - docker
---

# Backend API Engineer

## Trigger Conditions

Activate this skill when the task involves:
- Building REST or GraphQL APIs for mobile or web clients
- Setting up authentication and authorization (JWT, OAuth, API keys)
- Database schema design, migrations, or query optimization
- Docker containerization and deployment configuration
- Backend architecture decisions (monolith vs microservices, event-driven patterns)
- WebSocket or real-time communication setup
- Background job processing and task queues
- API rate limiting, caching, or performance optimization
- File upload handling and storage integration
- CI/CD pipeline configuration for backend services

## Primary Technology Stacks

### Node.js / TypeScript — NestJS
- **Framework**: NestJS 10.x with TypeScript 5.x strict mode
- **ORM**: TypeORM 0.3.x with PostgreSQL driver
- **Validation**: class-validator + class-transformer
- **Auth**: @nestjs/passport + @nestjs/jwt + passport-jwt
- **Docs**: @nestjs/swagger for OpenAPI 3.0
- **Caching**: @nestjs/cache-manager with Redis store
- **WebSockets**: @nestjs/websockets with Socket.IO adapter
- **Queue**: @nestjs/bull with Redis-backed Bull queues
- **Testing**: Jest + supertest

### Python — FastAPI
- **Framework**: FastAPI 0.110.x with Python 3.11+
- **ORM**: SQLAlchemy 2.0 with asyncpg driver
- **Validation**: Pydantic v2 models
- **Auth**: python-jose for JWT, passlib for password hashing
- **Docs**: Built-in OpenAPI + Swagger UI + ReDoc
- **Caching**: redis-py with async support
- **WebSockets**: Built-in WebSocket support
- **Queue**: Celery with Redis broker or arq for async jobs
- **Testing**: pytest + httpx AsyncClient
- **Migrations**: Alembic

## Capabilities

### API Design & Documentation
- RESTful resource design following HTTP semantics
- OpenAPI 3.0 schema-first or code-first documentation
- Consistent error responses using RFC 7807 Problem Details
- API versioning (URL prefix or Accept header)
- Cursor-based and offset pagination
- Bulk operation endpoints with partial failure handling

### Authentication & Authorization
- JWT access + refresh token flow with rotation
- OAuth 2.0 Authorization Code with PKCE (mobile clients)
- OpenID Connect integration (Google, Apple, Microsoft)
- Role-Based Access Control (RBAC) with guard/dependency patterns
- API key authentication for service-to-service calls
- Secure session management with HttpOnly cookies
- CSRF protection for cookie-based auth
- Per-user and per-IP rate limiting

### Database & Caching
- PostgreSQL schema design with proper indexing
- Connection pooling configuration
- Database migrations with rollback support
- Repository pattern for data access abstraction
- Transaction management for multi-step operations
- N+1 query detection and prevention (eager loading, DataLoader)
- Redis cache-aside pattern with TTL and invalidation
- Redis pub/sub for real-time event distribution

### Real-Time & Background Processing
- WebSocket connections with room-based broadcasting
- Server-Sent Events for one-way streaming
- Background job queues with retry policies and dead-letter handling
- Scheduled tasks (cron-based)
- Event-driven communication between modules

### Infrastructure & Deployment
- Multi-stage Docker builds for minimal production images
- Docker Compose for local development (app + PostgreSQL + Redis)
- Structured JSON logging with correlation IDs
- Health check endpoints (liveness + readiness)
- Graceful shutdown with connection draining
- Environment-based configuration with validation
- Container security: non-root user, read-only filesystem, resource limits

### Testing
- Unit tests for services and utility functions
- Integration tests for API endpoints with test database
- Authentication test helpers for protected routes
- Database fixture management and cleanup
- External service mocking
- Code coverage reporting and CI integration

## Rules

### Security Defaults
- Always hash passwords with bcrypt (cost 12) or argon2id
- Never log sensitive data (passwords, tokens, PII)
- Validate and sanitize all input at the boundary
- Use parameterized queries — never string-interpolate SQL
- Set secure, HttpOnly, SameSite=Lax cookies by default
- Enable CORS only for known origins, never wildcard in production
- Store secrets in environment variables, never in code or config files
- Apply rate limiting to authentication endpoints (max 5 attempts per minute)
- Use HTTPS in production; set HSTS headers

### Least Privilege
- Database users get only required permissions (SELECT, INSERT, UPDATE on specific tables)
- API keys are scoped to specific operations
- JWT claims contain minimal data (user ID, roles — no PII)
- Docker containers run as non-root with dropped capabilities
- File upload validation: check MIME type, file size, and extension

### Code Quality
- Enable TypeScript strict mode with no implicit any
- Use DTOs for all request/response shapes — never expose ORM entities directly
- Return consistent error response objects, never raw exceptions
- Document all public endpoints with OpenAPI decorators/annotations
- Write migration files for every schema change — never use synchronize in production
- Keep controllers thin: business logic belongs in services

## Workflow

The standard workflow for building a backend API:

1. **Design API Schema** — Define resources, endpoints, request/response models, and error cases. Write or generate an OpenAPI spec. Agree on pagination, filtering, and versioning strategy.

2. **Scaffold Project** — Initialize the project with the chosen framework (NestJS CLI or FastAPI cookiecutter). Set up linting (ESLint/Ruff), formatting (Prettier/Black), and pre-commit hooks.

3. **Implement Endpoints** — Build controllers/routers, services, and DTOs/Pydantic models for each resource. Wire up input validation and consistent error handling.

4. **Add Authentication** — Implement the auth strategy (JWT, OAuth, or API key). Add guards/dependencies to protected routes. Set up RBAC if needed.

5. **Connect Database** — Configure PostgreSQL with the ORM. Create entity/model definitions and migration files. Implement repository/data access layer. Add Redis caching where needed.

6. **Write Tests** — Unit test services, integration test endpoints. Set up test database, fixtures, and auth helpers. Target 80%+ coverage on business logic.

7. **Dockerize** — Write multi-stage Dockerfile. Create docker-compose.yml for local dev. Add health checks and graceful shutdown. Configure logging.

8. **Deploy** — Set up CI pipeline (lint, test, build, push image). Configure environment-specific settings. Set up monitoring, alerting, and log aggregation.

## Reference Files

- `references/nestjs-setup.md` — NestJS project structure, decorators, pipes, interceptors, Swagger
- `references/fastapi-setup.md` — FastAPI project structure, Pydantic, dependency injection, middleware
- `references/authentication.md` — JWT, OAuth 2.0, PKCE, Passport.js, RBAC, session management
- `references/database-patterns.md` — TypeORM, SQLAlchemy, migrations, caching, query optimization
- `references/api-design.md` — REST conventions, status codes, pagination, error format, versioning
- `references/docker-deployment.md` — Dockerfile, Compose, health checks, security, logging
- `references/testing-backend.md` — Jest, pytest, integration tests, fixtures, CI integration
