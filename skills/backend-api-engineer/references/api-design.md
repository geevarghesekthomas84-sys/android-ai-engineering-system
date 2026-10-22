# REST API Design Best Practices

## Resource Naming

Use plural nouns for collections. Nest sub-resources under their parent.

```
GET    /api/v1/users                  # List users
POST   /api/v1/users                  # Create user
GET    /api/v1/users/{id}             # Get user
PATCH  /api/v1/users/{id}             # Partial update user
DELETE /api/v1/users/{id}             # Delete user

GET    /api/v1/users/{id}/posts       # List user's posts
POST   /api/v1/users/{id}/posts       # Create post for user

POST   /api/v1/auth/login             # Action-based endpoints use verbs
POST   /api/v1/reports/generate       # Long-running actions
```

- Use kebab-case: `/api/v1/user-profiles` not `/api/v1/userProfiles`
- Nest at most 2 levels deep: `/users/{id}/posts` is fine; `/users/{id}/posts/{id}/comments/{id}/likes` is too deep — flatten to `/comments/{id}/likes`
- Use query params for filtering on collections, not path segments

## HTTP Methods and Semantics

| Method  | Meaning             | Idempotent | Safe | Request Body | Success Code |
|---------|---------------------|------------|------|-------------|--------------|
| GET     | Read resource       | Yes        | Yes  | No          | 200          |
| POST    | Create resource     | No         | No   | Yes         | 201          |
| PUT     | Full replace        | Yes        | No   | Yes         | 200          |
| PATCH   | Partial update      | No*        | No   | Yes         | 200          |
| DELETE  | Remove resource     | Yes        | No   | No          | 204          |

*PATCH can be made idempotent with JSON Merge Patch (RFC 7396).

## Status Codes

Use the most specific appropriate code:

**Success (2xx):**
- `200 OK` — General success with response body
- `201 Created` — Resource created; include `Location` header with new resource URL
- `202 Accepted` — Request accepted for async processing
- `204 No Content` — Success with no response body (DELETE, some PUT/PATCH)

**Client Errors (4xx):**
- `400 Bad Request` — Malformed request or validation failure
- `401 Unauthorized` — Missing or invalid authentication
- `403 Forbidden` — Authenticated but insufficient permissions
- `404 Not Found` — Resource does not exist
- `409 Conflict` — Conflicting state (duplicate email, version mismatch)
- `422 Unprocessable Entity` — Request is valid JSON but semantically wrong
- `429 Too Many Requests` — Rate limit exceeded; include `Retry-After` header

**Server Errors (5xx):**
- `500 Internal Server Error` — Unexpected failure (log and alert)
- `502 Bad Gateway` — Upstream service failure
- `503 Service Unavailable` — Temporary overload; include `Retry-After`

## Error Response Format (RFC 7807 Problem Details)

Use a consistent error shape across all endpoints:

```json
{
  "type": "https://api.example.com/errors/validation",
  "title": "Validation Error",
  "status": 400,
  "detail": "One or more fields failed validation",
  "instance": "/api/v1/users",
  "errors": [
    {
      "field": "email",
      "message": "Must be a valid email address"
    },
    {
      "field": "password",
      "message": "Must be at least 8 characters"
    }
  ]
}
```

Fields:
- `type` — URI identifying the error type (can be a documentation link)
- `title` — Short human-readable summary
- `status` — HTTP status code (duplicated for convenience)
- `detail` — Specific explanation for this occurrence
- `instance` — URI of the request that caused the error
- `errors` — Optional array of field-level validation errors

## Pagination

### Cursor-Based (Recommended for Real-Time Data)

Best for feeds, timelines, or data that changes frequently. Stable under inserts/deletes.

```
GET /api/v1/posts?limit=20&cursor=eyJpZCI6IjEyMyJ9

Response:
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6IjE0MyJ9",
    "has_more": true
  }
}
```

The cursor is an opaque, base64-encoded token (typically containing the last item's sort key). The server decodes it to build the WHERE clause.

### Offset-Based (Simpler, for Admin Panels)

```
GET /api/v1/users?page=2&limit=20

Response:
{
  "data": [...],
  "pagination": {
    "page": 2,
    "limit": 20,
    "total": 156,
    "total_pages": 8
  }
}
```

Offset pagination can skip items or show duplicates when data changes between pages. Acceptable for admin dashboards; avoid for user-facing feeds.

## Filtering and Sorting

```
GET /api/v1/posts?status=published&author_id=abc&created_after=2024-01-01
GET /api/v1/posts?sort=-created_at,title    # Prefix - for descending
GET /api/v1/posts?fields=id,title,author    # Sparse fieldsets
GET /api/v1/users?search=jane               # Full-text search
```

- Use flat query parameters for simple filters
- Prefix sort fields with `-` for descending order
- Validate all filter and sort field names server-side — reject unknown fields
- Apply default sorting when none specified (typically `-created_at`)

## API Versioning

### URL Prefix (Recommended)

```
/api/v1/users
/api/v2/users
```

Simple, explicit, easy to route and document. Run both versions concurrently during migration.

### Accept Header (Alternative)

```
Accept: application/vnd.myapi.v2+json
```

More RESTful but harder to test in browsers and harder to cache.

**Versioning rules:**
- Bump the version only for breaking changes (removing fields, changing types, renaming endpoints)
- Adding optional fields or new endpoints is not a breaking change
- Deprecate old versions with a sunset date; return `Sunset` and `Deprecation` headers
- Keep at most 2 versions active simultaneously

## Idempotency Keys

For non-idempotent operations (POST), allow clients to send an idempotency key to prevent duplicate processing:

```
POST /api/v1/payments
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000

{
  "amount": 1000,
  "currency": "USD"
}
```

Server implementation:
1. On first request: process normally, store the response keyed by `Idempotency-Key` in Redis (TTL 24h)
2. On duplicate request: return the stored response without reprocessing
3. If the first request is still in flight: return `409 Conflict`

## Bulk Operations

For creating or updating multiple resources in one request:

```
POST /api/v1/users/bulk
{
  "operations": [
    { "action": "create", "data": { "email": "a@test.com", ... } },
    { "action": "create", "data": { "email": "b@test.com", ... } }
  ]
}

Response (207 Multi-Status):
{
  "results": [
    { "status": 201, "data": { "id": "...", ... } },
    { "status": 409, "error": { "detail": "Email already exists" } }
  ]
}
```

Use HTTP `207 Multi-Status` when individual operations may succeed or fail independently.

## Rate Limiting Headers

Include these headers on every response:

```
X-RateLimit-Limit: 100        # Max requests per window
X-RateLimit-Remaining: 42     # Requests remaining
X-RateLimit-Reset: 1700001200 # Unix timestamp when the window resets
Retry-After: 30               # Seconds to wait (only on 429)
```

## OpenAPI Schema-First Design

Write the OpenAPI spec before implementing endpoints. This enables:
- Client SDK generation (openapi-generator for Android/Kotlin, TypeScript)
- Contract testing between frontend and backend teams
- Automatic validation middleware
- Interactive documentation (Swagger UI, ReDoc)

```yaml
openapi: 3.0.3
info:
  title: My API
  version: 1.0.0
paths:
  /api/v1/users:
    get:
      summary: List users
      operationId: listUsers
      tags: [users]
      parameters:
        - name: page
          in: query
          schema: { type: integer, minimum: 1, default: 1 }
        - name: limit
          in: query
          schema: { type: integer, minimum: 1, maximum: 100, default: 20 }
      responses:
        '200':
          description: Paginated list of users
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserListResponse'
```

Generate client code from the spec:

```bash
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml -g kotlin -o ./android-client \
  --additional-properties=library=jvm-retrofit2,serializationLibrary=kotlinx_serialization
```
