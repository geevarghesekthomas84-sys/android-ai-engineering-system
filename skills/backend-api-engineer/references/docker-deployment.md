# Docker & Deployment

## Multi-Stage Dockerfile — Node.js (NestJS)

```dockerfile
# Stage 1: Install dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Stage 2: Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: Production image
FROM node:20-alpine AS production
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

# Security: non-root user, no shell needed in production
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/v1/health || exit 1

CMD ["node", "dist/main.js"]
```

## Multi-Stage Dockerfile — Python (FastAPI)

```dockerfile
# Stage 1: Build dependencies
FROM python:3.12-slim AS builder
WORKDIR /app

RUN pip install --no-cache-dir --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Production image
FROM python:3.12-slim AS production

# Security: create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser
WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini .

# Security: non-root user
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/v1/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

## Docker Compose — Development

```yaml
# docker-compose.yml
version: "3.9"

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: build  # Use build stage with source for hot-reload
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USERNAME=postgres
      - DB_PASSWORD=devpassword
      - DB_NAME=myapi_dev
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - JWT_SECRET=dev-secret-at-least-32-characters-long
    volumes:
      - ./src:/app/src  # Hot-reload: mount source
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: npm run start:dev
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: myapi_dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru

volumes:
  pgdata:
  redisdata:
```

## Docker Compose — Production Overrides

```yaml
# docker-compose.prod.yml
# Usage: docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
version: "3.9"

services:
  app:
    build:
      target: production  # Use final production stage
    environment:
      - NODE_ENV=production
    volumes: []           # No source mount in production
    command: node dist/main.js
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
    read_only: true
    tmpfs:
      - /tmp:size=64M

  postgres:
    ports: []             # Don't expose DB externally
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}  # From .env or secrets

  redis:
    ports: []             # Don't expose Redis externally
    command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru --requirepass ${REDIS_PASSWORD}
```

## .dockerignore

```
node_modules
npm-debug.log
dist
.git
.gitignore
.env
.env.*
*.md
!README.md
docker-compose*.yml
Dockerfile
.vscode
.idea
coverage
test
__pycache__
*.pyc
.venv
.pytest_cache
.mypy_cache
```

## Health Check Endpoints

```typescript
// NestJS health controller
import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { DataSource } from 'typeorm';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private dataSource: DataSource) {}

  @Get()
  @ApiOperation({ summary: 'Liveness check' })
  liveness() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  @Get('ready')
  @ApiOperation({ summary: 'Readiness check — verifies DB and cache' })
  async readiness() {
    const checks: Record<string, string> = {};

    // Database check
    try {
      await this.dataSource.query('SELECT 1');
      checks.database = 'ok';
    } catch {
      checks.database = 'error';
    }

    const allOk = Object.values(checks).every((v) => v === 'ok');
    return {
      status: allOk ? 'ok' : 'degraded',
      checks,
      timestamp: new Date().toISOString(),
    };
  }
}
```

```python
# FastAPI health router
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.dependencies import get_db

router = APIRouter()

@router.get("/health")
async def liveness():
    return {"status": "ok"}

@router.get("/health/ready")
async def readiness(db: AsyncSession = Depends(get_db)):
    checks = {}
    try:
        await db.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception:
        checks["database"] = "error"

    all_ok = all(v == "ok" for v in checks.values())
    return {"status": "ok" if all_ok else "degraded", "checks": checks}
```

## Graceful Shutdown

Handle SIGTERM so in-flight requests complete before the container stops:

```typescript
// NestJS — enable in main.ts
app.enableShutdownHooks();

// In a service that needs cleanup
import { OnModuleDestroy } from '@nestjs/common';

@Injectable()
export class QueueService implements OnModuleDestroy {
  async onModuleDestroy() {
    // Close queue connections, flush buffers
    await this.queue.close();
  }
}
```

```python
# FastAPI — handled via lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    yield
    # Shutdown: close connections, flush logs
    await engine.dispose()
    await redis_client.aclose()
```

Docker stop sends SIGTERM, then waits 10 seconds (configurable with `stop_grace_period`), then SIGKILL. Ensure your app handles SIGTERM and finishes active requests within that window.

## Logging Configuration

Structured JSON logs for production:

```typescript
// NestJS with winston
import { WinstonModule } from 'nest-winston';
import * as winston from 'winston';

const app = await NestFactory.create(AppModule, {
  logger: WinstonModule.createLogger({
    transports: [
      new winston.transports.Console({
        format: process.env.NODE_ENV === 'production'
          ? winston.format.json()
          : winston.format.combine(
              winston.format.colorize(),
              winston.format.simple(),
            ),
      }),
    ],
  }),
});
```

```python
# FastAPI with structlog
import structlog
import logging

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer() if settings.app_env == "production"
        else structlog.dev.ConsoleRenderer(),
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

logger = structlog.get_logger()
```

## Container Security Checklist

- Run as non-root user (`USER appuser`)
- Use `read_only: true` filesystem where possible
- Set resource limits (CPU, memory)
- Do not install unnecessary packages (no curl, wget in production unless needed for health checks)
- Pin base image versions (e.g., `node:20.11-alpine`, not `node:latest`)
- Scan images for vulnerabilities: `docker scout cves myimage`
- Never copy `.env` files or secrets into the image
- Use multi-stage builds to exclude build tools from production image
- Set `no-new-privileges` security option
