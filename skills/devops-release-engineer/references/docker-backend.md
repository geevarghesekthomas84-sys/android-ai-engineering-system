# Docker Backend Deployment

## Multi-Stage Dockerfile -- NestJS

```dockerfile
# Build stage
FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY tsconfig*.json nest-cli.json ./
COPY src/ src/
RUN npm run build
RUN npm prune --production

# Production stage
FROM node:22-alpine AS production
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
CMD ["node", "dist/main.js"]
```

## Multi-Stage Dockerfile -- FastAPI

```dockerfile
# Build stage
FROM python:3.12-slim AS builder
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY src/ src/
RUN uv sync --frozen --no-dev

# Production stage
FROM python:3.12-slim AS production
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app
COPY --from=builder /app/.venv .venv
COPY --from=builder /app/src src/
ENV PATH="/app/.venv/bin:$PATH"
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

## Docker Compose -- Development

`docker-compose.yml`:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://appuser:apppass@postgres:5432/appdb
      - REDIS_URL=redis://redis:6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - backend

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: apppass
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - backend

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - backend

  nginx:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - app
    restart: unless-stopped
    networks:
      - backend

volumes:
  postgres_data:
  redis_data:

networks:
  backend:
    driver: bridge
```

## Production Compose Overrides

`docker-compose.prod.yml`:

```yaml
services:
  app:
    image: ghcr.io/your-org/your-app:${APP_VERSION:-latest}
    build: !reset null
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
      update_config:
        parallelism: 1
        delay: 30s
        failure_action: rollback
        order: start-first
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  postgres:
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 1G

  redis:
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

Deploy with:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Environment Configuration

### Using .env files

```bash
# .env (development)
NODE_ENV=development
DATABASE_URL=postgresql://appuser:apppass@localhost:5432/appdb
REDIS_URL=redis://localhost:6379
JWT_SECRET=dev-secret-not-for-production
LOG_LEVEL=debug

# .env.production
NODE_ENV=production
DATABASE_URL=postgresql://appuser:${DB_PASSWORD}@db.internal:5432/appdb
REDIS_URL=redis://cache.internal:6379
LOG_LEVEL=info
```

### Using Docker secrets (Swarm mode)

```bash
echo "strong-db-password" | docker secret create db_password -
echo "jwt-signing-secret" | docker secret create jwt_secret -
```

## Health Checks

Application health endpoint:

```typescript
// NestJS health controller
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private redis: MicroserviceHealthIndicator,
  ) {}

  @Get()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.redis.pingCheck('redis', { transport: Transport.REDIS }),
    ]);
  }
}
```

## Nginx Reverse Proxy Configuration

`nginx/nginx.conf`:

```nginx
upstream app_servers {
    least_conn;
    server app:3000;
}

server {
    listen 80;
    server_name api.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    client_max_body_size 10m;

    location / {
        proxy_pass http://app_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
    }

    location /health {
        proxy_pass http://app_servers/health;
        access_log off;
    }
}
```

## Zero-Downtime Deployment with Rolling Updates

### Using Docker Compose with start-first ordering

The `update_config` in the production override handles this:

```yaml
update_config:
  parallelism: 1      # Update one container at a time
  delay: 30s          # Wait 30s between updates
  failure_action: rollback  # Rollback on failure
  order: start-first  # Start new container before stopping old one
```

### Deployment script

```bash
#!/bin/bash
set -euo pipefail

IMAGE="ghcr.io/your-org/your-app"
TAG="${1:?Usage: deploy.sh <version>}"

echo "Pulling ${IMAGE}:${TAG}..."
docker pull "${IMAGE}:${TAG}"

echo "Deploying with rolling update..."
APP_VERSION="${TAG}" docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    up -d --no-build

echo "Waiting for health check..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
        echo "Deployment successful. Service is healthy."
        exit 0
    fi
    sleep 2
done

echo "Health check failed. Rolling back..."
APP_VERSION="${PREVIOUS_TAG}" docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    up -d --no-build
exit 1
```

## Monitoring with Prometheus and Grafana

Add monitoring services:

```yaml
services:
  prometheus:
    image: prom/prometheus:v3.0.0
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - backend

  grafana:
    image: grafana/grafana:11.3.0
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/dashboards:/etc/grafana/provisioning/dashboards:ro
    ports:
      - "3001:3000"
    depends_on:
      - prometheus
    networks:
      - backend
```

`monitoring/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['app:3000']
    metrics_path: /metrics

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
```
