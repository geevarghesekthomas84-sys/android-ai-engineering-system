# System Design

## Client-Server Architecture for Mobile Apps

A typical Android + backend architecture consists of three tiers:

```
[Android App]
    |
    | HTTPS (REST/GraphQL)
    |
[API Layer]
    |--- [Auth Service] --- [User DB]
    |--- [Business Logic Service] --- [Primary DB]
    |--- [Media Service] --- [Object Storage]
    |--- [Notification Service] --- [FCM / APNs]
    |
[Infrastructure]
    |--- [CDN] (static assets, images)
    |--- [Cache] (Redis)
    |--- [Message Queue] (for async processing)
    |--- [Monitoring] (logs, metrics, alerts)
```

### Android Client Responsibilities
- UI rendering (Jetpack Compose)
- Local data caching (Room)
- Offline queue management
- Token management (encrypted storage)
- Push notification handling (FCM)
- Analytics event tracking

### Backend Responsibilities
- Authentication and authorization
- Business logic enforcement
- Data validation and persistence
- File upload processing and storage
- Notification dispatch
- Rate limiting and abuse prevention
- Background job processing

## Monolith vs Microservices Decision

### Start with a Modular Monolith
For most new apps (especially with small teams), a modular monolith is the correct starting point:

| Factor | Monolith | Microservices |
|---|---|---|
| Team size | 1-8 developers | 8+ developers with separate team ownership |
| Deployment complexity | Single deploy | Multiple deploys, orchestration needed |
| Local development | Simple | Requires Docker Compose or similar |
| Data consistency | Transactions across modules | Distributed transactions, eventual consistency |
| Latency | In-process calls | Network calls between services |
| Operational cost | One server/container | Multiple containers, service mesh, observability |
| Time to market | Faster | Slower initial setup |

### When to Extract Microservices
Extract a module into a service when:
- A module needs to **scale independently** (media processing vs CRUD API)
- A module has a **different deployment cadence** (notification service updates weekly, core API updates daily)
- A module requires a **different technology** (ML model serving in Python, core API in TypeScript)
- A team boundary forms around a module (Conway's Law)

## API Gateway Pattern

An API Gateway sits between the client and backend services:

```
[Android App] --> [API Gateway] --> [Service A]
                                --> [Service B]
                                --> [Service C]
```

### Gateway Responsibilities
- **Request routing**: Route to the correct backend service
- **Authentication**: Validate JWT tokens before forwarding
- **Rate limiting**: Per-user and per-endpoint limits
- **Request transformation**: Aggregate responses from multiple services
- **Caching**: Cache GET responses at the edge
- **Logging**: Centralized request/response logging

### Implementation Options
- **AWS API Gateway**: Managed, integrates with Lambda and other AWS services
- **Kong**: Open-source, plugin-based, runs on any infrastructure
- **Nginx**: Lightweight reverse proxy with basic gateway features
- **Cloud Run / Cloud Functions**: Serverless, auto-scaling, pay-per-request

## Backend for Frontend (BFF)

A BFF is a backend service specifically designed for a single frontend:

```
[Android App] --> [Android BFF] --> [Shared Services]
[Web App]     --> [Web BFF]     --> [Shared Services]
[Admin Panel] --> [Admin BFF]   --> [Shared Services]
```

### Why Use a BFF
- **Tailored responses**: Android needs different data shapes than web (smaller payloads, fewer fields)
- **Aggregation**: Combine multiple service calls into one response
- **Version management**: Update mobile API contracts independently from web
- **Offline support**: BFF can prepare data optimized for client-side caching

### When to Skip BFF
- Single client (Android only) with no web counterpart
- Simple CRUD app with no aggregation needs
- Small team where maintaining extra services adds overhead

## Event-Driven Architecture

Use events when actions trigger multiple downstream effects:

```
[User places order]
    |
    |--> Event: "order.created"
         |
         |--> [Inventory Service] - Reserve stock
         |--> [Payment Service] - Charge payment
         |--> [Notification Service] - Send confirmation email
         |--> [Analytics Service] - Track conversion
```

### Event Patterns
- **Pub/Sub**: Publisher emits events, multiple subscribers react independently
- **Event sourcing**: Store all state changes as events; rebuild state by replaying them
- **Saga pattern**: Coordinate multi-step transactions across services with compensating actions

### Message Brokers
| Broker | Best For | Managed Option |
|---|---|---|
| Google Pub/Sub | GCP-native, at-least-once delivery | Fully managed |
| AWS SQS/SNS | AWS-native, simple queue/topic | Fully managed |
| RabbitMQ | Complex routing, priority queues | CloudAMQP, Amazon MQ |
| Redis Streams | Low latency, ephemeral events | Redis Cloud |

## CQRS (Command Query Responsibility Segregation)

Separate read and write paths when they have different performance characteristics:

```
[Write Path]
  Android --> API --> Command Handler --> Write DB (PostgreSQL)
                                            |
                                            | (sync/async projection)
                                            v
[Read Path]                             Read Store (Elasticsearch, Redis, denormalized views)
  Android --> API --> Query Handler --> Read Store
```

### When CQRS Helps
- Read patterns differ significantly from write patterns (dashboards, search, analytics)
- Read-heavy workload (100:1 read/write ratio)
- Complex queries that are expensive on normalized data

### When to Skip CQRS
- Simple CRUD with similar read/write patterns
- Small data volume where query performance is not an issue
- Added complexity is not justified by the team's experience level

## Scalability Considerations

### Horizontal Scaling Checklist
- [ ] Stateless services (no in-memory sessions)
- [ ] Externalized configuration (environment variables)
- [ ] Shared-nothing architecture (no local file dependencies)
- [ ] Database connection pooling (PgBouncer for PostgreSQL)
- [ ] Health check endpoints (/health, /ready)
- [ ] Graceful shutdown handling

### Caching Strategy

| Layer | Tool | TTL | Use Case |
|---|---|---|---|
| Client | Room + DataStore | Until invalidated | Offline support, reduce network calls |
| CDN | Cloudflare / CloudFront | 1-24 hours | Static assets, images, fonts |
| API Response | Redis | 1-15 minutes | Frequently read, rarely changed data (categories, config) |
| Database Query | Materialized views | On write | Complex aggregations (dashboard stats) |

### Cache Invalidation Strategies
- **Time-based (TTL)**: Simple, works for data that can be slightly stale
- **Event-based**: Invalidate cache when underlying data changes
- **Version-based**: Include version in cache key; increment on write
- **Stale-while-revalidate**: Serve stale cache immediately, refresh in background

## CDN for Media

Store and serve user-uploaded media through a CDN:

```
[Upload Flow]
  Android --> Pre-signed URL from API --> Direct upload to S3/GCS
  
[Download Flow]
  Android --> CDN URL --> CDN Edge (cached) or Origin (S3/GCS)
```

### Image Processing Pipeline
1. User uploads original image to object storage
2. Background job generates variants (thumbnail 150px, medium 600px, large 1200px)
3. Store variants in object storage with predictable naming: `images/{id}/thumb.webp`
4. Serve through CDN with long cache TTL (images are immutable once processed)
5. Use WebP format for Android (30% smaller than JPEG at same quality)

## Database Selection Criteria

| Criterion | PostgreSQL | MongoDB | Firestore |
|---|---|---|---|
| Data model | Relational, structured | Document, flexible schema | Document, hierarchical |
| Transactions | Full ACID, multi-table | Multi-document (v4+) | Multi-document within collection group |
| Scaling | Vertical + read replicas | Horizontal sharding | Automatic (managed) |
| Full-text search | Built-in (tsvector) | Built-in (Atlas Search) | No (use Algolia/Typesense) |
| Real-time sync | Requires polling or triggers | Change streams | Built-in listeners |
| Offline support | Requires custom sync | Requires custom sync | Built-in (Firestore SDK) |
| Cost model | Server-based | Server or Atlas serverless | Pay per read/write operation |
| Best for | Complex queries, strong consistency | Flexible schemas, rapid iteration | Mobile-first with real-time needs |

### Decision Guide
- **Choose PostgreSQL** when you need complex joins, strong consistency, and your team knows SQL
- **Choose MongoDB** when schema flexibility matters and you want fast iteration with document queries
- **Choose Firestore** when building mobile-first with real-time sync and offline support out of the box, and your query patterns fit Firestore's index model

## Load Balancing

### For a Simple Setup (Starting Out)
- Use the cloud provider's managed load balancer (ALB on AWS, Cloud Load Balancing on GCP)
- Round-robin distribution across 2+ instances
- Health checks to route away from unhealthy instances
- SSL termination at the load balancer

### For Production Scale
- Geographic load balancing (route users to nearest region)
- Connection draining during deployments
- Auto-scaling based on CPU, memory, or custom metrics (request latency)
- Blue/green or canary deployments for zero-downtime releases
