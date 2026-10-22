# API Contract Design Reference

## OpenAPI 3.1 Specification Structure

Every API contract starts with a well-structured OpenAPI document:

```yaml
openapi: "3.1.0"
info:
  title: MyApp API
  version: "1.0.0"
  description: Production API for MyApp
  contact:
    name: API Support
    email: api-support@myapp.com
servers:
  - url: https://api.myapp.com/v1
    description: Production
  - url: https://staging-api.myapp.com/v1
    description: Staging
```

## Resource Modeling

### Naming Conventions

- Use plural nouns for collections: `/users`, `/orders`, `/products`
- Use kebab-case for multi-word resources: `/order-items`, `/payment-methods`
- Nest for clear parent-child: `/users/{userId}/orders/{orderId}`
- Limit nesting to 2 levels max; beyond that, use query params or top-level resources
- Use consistent ID parameter naming: `{resourceName}Id`

### Standard CRUD Endpoints

```yaml
paths:
  /users:
    get:
      summary: List users
      operationId: listUsers
      parameters:
        - $ref: "#/components/parameters/PageCursor"
        - $ref: "#/components/parameters/PageSize"
        - $ref: "#/components/parameters/SortBy"
      responses:
        "200":
          description: Paginated list of users
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/UserListResponse"
    post:
      summary: Create a user
      operationId: createUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateUserRequest"
      responses:
        "201":
          description: User created
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/UserResponse"
        "409":
          description: Conflict - email already registered
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ProblemDetail"

  /users/{userId}:
    get:
      summary: Get user by ID
      operationId: getUser
      parameters:
        - $ref: "#/components/parameters/UserId"
      responses:
        "200":
          description: User found
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/UserResponse"
        "404":
          $ref: "#/components/responses/NotFound"
    patch:
      summary: Partially update user
      operationId: updateUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/UpdateUserRequest"
      responses:
        "200":
          description: User updated
    delete:
      summary: Delete user
      operationId: deleteUser
      responses:
        "204":
          description: User deleted
```

### Resource Schemas

```yaml
components:
  schemas:
    UserResponse:
      type: object
      required: [id, email, displayName, createdAt]
      properties:
        id:
          type: string
          format: uuid
          readOnly: true
        email:
          type: string
          format: email
        displayName:
          type: string
          minLength: 1
          maxLength: 100
        avatarUrl:
          type: string
          format: uri
          nullable: true
        role:
          type: string
          enum: [user, admin, moderator]
          default: user
        createdAt:
          type: string
          format: date-time
          readOnly: true
        updatedAt:
          type: string
          format: date-time
          readOnly: true

    CreateUserRequest:
      type: object
      required: [email, displayName, password]
      properties:
        email:
          type: string
          format: email
        displayName:
          type: string
          minLength: 1
          maxLength: 100
        password:
          type: string
          format: password
          minLength: 8
          maxLength: 128

    UpdateUserRequest:
      type: object
      minProperties: 1
      properties:
        displayName:
          type: string
          minLength: 1
          maxLength: 100
        avatarUrl:
          type: string
          format: uri
          nullable: true
```

## Pagination

### Cursor-Based Pagination (Preferred)

Cursor pagination is stable under concurrent writes and performs well at scale:

```yaml
UserListResponse:
  type: object
  required: [data, pagination]
  properties:
    data:
      type: array
      items:
        $ref: "#/components/schemas/UserResponse"
    pagination:
      $ref: "#/components/schemas/CursorPagination"

CursorPagination:
  type: object
  required: [hasMore]
  properties:
    nextCursor:
      type: string
      description: Opaque cursor for the next page. Absent when hasMore is false.
    hasMore:
      type: boolean
    totalCount:
      type: integer
      description: Optional total count. Omit if expensive to compute.
```

Request: `GET /users?cursor=eyJpZCI6MTAwfQ&limit=25`

### Offset-Based Pagination (Simple Cases)

Acceptable for admin dashboards or small, stable datasets:

```yaml
OffsetPagination:
  type: object
  required: [page, pageSize, totalPages, totalCount]
  properties:
    page:
      type: integer
      minimum: 1
    pageSize:
      type: integer
      minimum: 1
      maximum: 100
    totalPages:
      type: integer
    totalCount:
      type: integer
```

Request: `GET /users?page=2&pageSize=25`

### Pagination Parameter Definitions

```yaml
components:
  parameters:
    PageCursor:
      name: cursor
      in: query
      required: false
      schema:
        type: string
      description: Opaque cursor from a previous response
    PageSize:
      name: limit
      in: query
      required: false
      schema:
        type: integer
        minimum: 1
        maximum: 100
        default: 25
    SortBy:
      name: sort
      in: query
      required: false
      schema:
        type: string
        pattern: "^[a-zA-Z]+:(asc|desc)$"
      example: "createdAt:desc"
```

## Error Format - RFC 7807 Problem Details

All errors use a consistent structure based on RFC 7807:

```yaml
ProblemDetail:
  type: object
  required: [type, title, status]
  properties:
    type:
      type: string
      format: uri
      description: URI identifying the problem type
      example: "https://api.myapp.com/problems/validation-error"
    title:
      type: string
      description: Short human-readable summary
      example: "Validation Error"
    status:
      type: integer
      description: HTTP status code
      example: 422
    detail:
      type: string
      description: Human-readable explanation specific to this occurrence
      example: "The email field is not a valid email address"
    instance:
      type: string
      format: uri
      description: URI identifying this specific occurrence
    errors:
      type: array
      description: Field-level validation errors
      items:
        type: object
        required: [field, message]
        properties:
          field:
            type: string
            example: "email"
          message:
            type: string
            example: "must be a valid email address"
          code:
            type: string
            example: "invalid_format"
    traceId:
      type: string
      description: Correlation ID for support and debugging
      example: "req_7f3a9b2c"
```

### Standard Error Responses

```yaml
components:
  responses:
    BadRequest:
      description: Invalid request
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
    Unauthorized:
      description: Authentication required
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
    Forbidden:
      description: Insufficient permissions
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
    NotFound:
      description: Resource not found
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
    Conflict:
      description: Resource conflict
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
    UnprocessableEntity:
      description: Validation failed
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
    TooManyRequests:
      description: Rate limit exceeded
      headers:
        Retry-After:
          schema:
            type: integer
          description: Seconds until the rate limit resets
        X-RateLimit-Limit:
          schema:
            type: integer
        X-RateLimit-Remaining:
          schema:
            type: integer
      content:
        application/problem+json:
          schema:
            $ref: "#/components/schemas/ProblemDetail"
```

## API Versioning

### URI Path Versioning (Recommended for Most Apps)

```
https://api.myapp.com/v1/users
https://api.myapp.com/v2/users
```

- Explicit, easy to understand and route
- Each major version is a separate deployment or routing target
- Clients know exactly which version they call

### Header Versioning (Alternative)

```
GET /users HTTP/1.1
Host: api.myapp.com
Accept: application/vnd.myapp.v2+json
```

- Cleaner URIs
- Harder to test in browser, more complex routing

### Versioning Rules

1. **Never break existing clients** - additive changes (new fields, new endpoints) do not require a version bump
2. **Breaking changes require a new version**: removing fields, renaming fields, changing field types, changing required/optional status, changing response structure
3. **Deprecation policy**: announce 6 months before sunsetting a version; return `Sunset` and `Deprecation` headers
4. **Support at most 2 versions** concurrently in production

## Authentication and Security Headers

```yaml
components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key

security:
  - BearerAuth: []
```

### Required Response Headers

| Header | Purpose | Example |
|---|---|---|
| `X-Request-Id` | Correlation/tracing | `req_7f3a9b2c` |
| `Cache-Control` | Caching directive | `private, max-age=60` |
| `Content-Type` | Response media type | `application/json` |
| `X-RateLimit-Limit` | Request quota | `1000` |
| `X-RateLimit-Remaining` | Remaining quota | `997` |

## Idempotency

For non-idempotent operations (POST), use an idempotency key:

```
POST /payments
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

The server stores the response and returns the same result for duplicate requests with the same key. Idempotency keys should expire after 24 hours.

## Android Client Contract Consumption

### Retrofit Interface from Contract

```kotlin
interface UserApi {
    @GET("users")
    suspend fun listUsers(
        @Query("cursor") cursor: String? = null,
        @Query("limit") limit: Int = 25,
        @Query("sort") sort: String? = null
    ): UserListResponse

    @GET("users/{userId}")
    suspend fun getUser(@Path("userId") userId: String): UserResponse

    @POST("users")
    suspend fun createUser(@Body request: CreateUserRequest): UserResponse

    @PATCH("users/{userId}")
    suspend fun updateUser(
        @Path("userId") userId: String,
        @Body request: UpdateUserRequest
    ): UserResponse

    @DELETE("users/{userId}")
    suspend fun deleteUser(@Path("userId") userId: String)
}
```

### Sealed Result Wrapper

```kotlin
sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val problem: ProblemDetail) : ApiResult<Nothing>()
    data class NetworkError(val throwable: Throwable) : ApiResult<Nothing>()
}

// Usage in repository
class UserRepository(private val api: UserApi) {
    suspend fun getUser(id: String): ApiResult<UserResponse> = safeApiCall {
        api.getUser(id)
    }
}
```

### Code Generation

Use OpenAPI Generator for Kotlin client models:

```bash
openapi-generator generate \
  -i api-spec.yaml \
  -g kotlin \
  -o generated/ \
  --additional-properties=library=jvm-retrofit2,serializationLibrary=kotlinx_serialization
```

Place generated models in a shared `:api-models` module so both app and tests reference the same contract types.
