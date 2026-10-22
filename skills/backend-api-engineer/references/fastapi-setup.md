# FastAPI Project Setup

## Installation

```bash
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows

pip install "fastapi[standard]" uvicorn[standard] sqlalchemy[asyncio] asyncpg
pip install alembic pydantic-settings python-jose[cryptography] passlib[bcrypt]
pip install redis celery httpx pytest pytest-asyncio
```

## Project Structure

```
app/
  __init__.py
  main.py                    # FastAPI app factory, lifespan, middleware
  config.py                  # Pydantic settings
  database.py                # SQLAlchemy engine, session factory
  dependencies.py            # Shared dependencies (get_db, get_current_user)
  models/                    # SQLAlchemy ORM models
    __init__.py
    base.py                  # Declarative base with common mixins
    user.py
  schemas/                   # Pydantic request/response models
    __init__.py
    user.py
    auth.py
    common.py                # Pagination, error responses
  routers/                   # API route modules
    __init__.py
    auth.py
    users.py
    health.py
  services/                  # Business logic layer
    __init__.py
    user_service.py
    auth_service.py
  middleware/
    __init__.py
    correlation_id.py
    logging.py
  utils/
    security.py              # Password hashing, JWT encode/decode
    pagination.py
alembic/                     # Database migrations
  versions/
  env.py
alembic.ini
pyproject.toml
Dockerfile
docker-compose.yml
```

## Application Entry Point (main.py)

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse

from app.config import settings
from app.database import engine
from app.routers import auth, users, health
from app.middleware.correlation_id import CorrelationIdMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize connections, warm caches
    # Engine pool is created on first use; you can pre-connect here
    async with engine.begin() as conn:
        pass  # Verify DB is reachable
    yield
    # Shutdown: close connections, flush queues
    await engine.dispose()


app = FastAPI(
    title="My API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    default_response_class=ORJSONResponse,
    lifespan=lifespan,
)

# Middleware (order matters — last added runs first)
app.add_middleware(CorrelationIdMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["*"],
)

# Routers
app.include_router(health.router, prefix="/api/v1", tags=["health"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
```

## Configuration (config.py)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # App
    app_env: str = "development"
    debug: bool = False
    port: int = 8000

    # Database
    db_host: str = "localhost"
    db_port: int = 5432
    db_user: str = "postgres"
    db_password: str
    db_name: str = "myapi"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

    # JWT
    jwt_secret: str
    jwt_access_expire_minutes: int = 15
    jwt_refresh_expire_days: int = 7

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # CORS
    cors_origins: list[str] = ["http://localhost:3000"]

    @field_validator("jwt_secret")
    @classmethod
    def jwt_secret_min_length(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("JWT secret must be at least 32 characters")
        return v


settings = Settings()
```

## Path Operations (Routers)

```python
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, get_current_user
from app.schemas.user import UserCreate, UserUpdate, UserResponse, UserListResponse
from app.schemas.common import PaginationParams
from app.services.user_service import UserService
from app.models.user import User

router = APIRouter()


@router.get("", response_model=UserListResponse)
async def list_users(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = Query(None, max_length=100),
    db: AsyncSession = Depends(get_db),
):
    """List users with pagination and optional search."""
    service = UserService(db)
    users, total = await service.list_users(page=page, limit=limit, search=search)
    return UserListResponse(
        items=[UserResponse.model_validate(u) for u in users],
        total=total,
        page=page,
        limit=limit,
    )


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get a single user by ID."""
    service = UserService(db)
    user = await service.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse.model_validate(user)


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new user (admin only)."""
    if "admin" not in current_user.roles:
        raise HTTPException(status_code=403, detail="Admin access required")
    service = UserService(db)
    return await service.create(payload)


@router.patch("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update user profile. Users can update their own profile; admins can update any."""
    if user_id != str(current_user.id) and "admin" not in current_user.roles:
        raise HTTPException(status_code=403, detail="Not authorized")
    service = UserService(db)
    return await service.update(user_id, payload)


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Soft-delete a user (admin only)."""
    if "admin" not in current_user.roles:
        raise HTTPException(status_code=403, detail="Admin access required")
    service = UserService(db)
    await service.soft_delete(user_id)
```

## Pydantic Schemas

```python
from datetime import datetime
from pydantic import BaseModel, Field, EmailStr, ConfigDict


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(None, max_length=100)


class UserUpdate(BaseModel):
    display_name: str | None = Field(None, max_length=100)
    avatar_url: str | None = Field(None, max_length=500)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    display_name: str | None
    avatar_url: str | None
    created_at: datetime
    updated_at: datetime


class UserListResponse(BaseModel):
    items: list[UserResponse]
    total: int
    page: int
    limit: int
```

## Dependency Injection

```python
# dependencies.py
from typing import AsyncGenerator
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory
from app.utils.security import decode_access_token
from app.services.user_service import UserService

security = HTTPBearer()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
):
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    service = UserService(db)
    user = await service.get_by_id(payload["sub"])
    if user is None or user.is_deleted:
        raise HTTPException(status_code=401, detail="User not found")
    return user
```

## Custom Error Handling

```python
from fastapi import Request
from fastapi.responses import JSONResponse


class AppException(Exception):
    def __init__(self, status_code: int, detail: str, error_code: str | None = None):
        self.status_code = status_code
        self.detail = detail
        self.error_code = error_code


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "type": "about:blank",
            "title": exc.error_code or "Error",
            "status": exc.status_code,
            "detail": exc.detail,
            "instance": str(request.url),
        },
    )


# Register in main.py:
# app.add_exception_handler(AppException, app_exception_handler)
```

## Middleware Example

```python
# middleware/correlation_id.py
import uuid
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response


class CorrelationIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        request.state.correlation_id = correlation_id
        response = await call_next(request)
        response.headers["X-Correlation-ID"] = correlation_id
        return response
```

## Running the Application

```bash
# Development with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production with multiple workers
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4 --log-level info
```

OpenAPI docs are automatically available at `/docs` (Swagger UI) and `/redoc` (ReDoc).
