# Backend Testing

## NestJS Testing with Jest

### Unit Tests

Test services in isolation by mocking their dependencies:

```typescript
// users.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from './users.service';
import { User } from './entities/user.entity';
import { NotFoundException } from '@nestjs/common';

describe('UsersService', () => {
  let service: UsersService;
  let repo: jest.Mocked<Repository<User>>;

  const mockUser: Partial<User> = {
    id: 'test-uuid',
    email: 'jane@example.com',
    displayName: 'Jane',
    roles: ['user'],
    isDeleted: false,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: jest.fn(),
            findAndCount: jest.fn(),
            save: jest.fn(),
            create: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(UsersService);
    repo = module.get(getRepositoryToken(User));
  });

  describe('findById', () => {
    it('should return a user when found', async () => {
      repo.findOne.mockResolvedValue(mockUser as User);
      const result = await service.findById('test-uuid');
      expect(result).toEqual(mockUser);
      expect(repo.findOne).toHaveBeenCalledWith({
        where: { id: 'test-uuid', isDeleted: false },
      });
    });

    it('should throw NotFoundException when user does not exist', async () => {
      repo.findOne.mockResolvedValue(null);
      await expect(service.findById('missing')).rejects.toThrow(NotFoundException);
    });
  });

  describe('create', () => {
    it('should hash password and save user', async () => {
      const dto = { email: 'new@example.com', password: 'securepass' };
      repo.create.mockReturnValue({ ...mockUser, email: dto.email } as User);
      repo.save.mockResolvedValue({ ...mockUser, email: dto.email } as User);

      const result = await service.create(dto);
      expect(result.email).toBe(dto.email);
      // Verify password was not stored in plain text
      expect(repo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          email: dto.email,
          passwordHash: expect.not.stringContaining(dto.password),
        }),
      );
    });
  });
});
```

### Integration Tests with TestingModule

Test the full HTTP request/response cycle:

```typescript
// users.controller.integration.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../app.module';
import { DataSource } from 'typeorm';

describe('UsersController (integration)', () => {
  let app: INestApplication;
  let dataSource: DataSource;
  let authToken: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    dataSource = module.get(DataSource);

    // Create a test user and get auth token
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email: 'admin@test.com', password: 'testpassword' });
    authToken = loginRes.body.accessToken;
  });

  afterAll(async () => {
    await dataSource.destroy();
    await app.close();
  });

  afterEach(async () => {
    // Clean up test data (keep seed data)
    await dataSource.query(`DELETE FROM users WHERE email LIKE '%@integration-test.com'`);
  });

  describe('GET /api/v1/users', () => {
    it('should return paginated users', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/users')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ page: 1, limit: 10 });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('items');
      expect(res.body).toHaveProperty('total');
      expect(Array.isArray(res.body.items)).toBe(true);
    });

    it('should reject invalid pagination params', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/users')
        .set('Authorization', `Bearer ${authToken}`)
        .query({ page: -1 });

      expect(res.status).toBe(400);
    });
  });

  describe('POST /api/v1/users', () => {
    it('should create a user with valid data', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/users')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          email: 'new@integration-test.com',
          password: 'securepass123',
          displayName: 'Test User',
        });

      expect(res.status).toBe(201);
      expect(res.body.email).toBe('new@integration-test.com');
      expect(res.body).not.toHaveProperty('passwordHash');
    });

    it('should return 401 without auth token', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/users')
        .send({ email: 'a@test.com', password: 'pass1234' });

      expect(res.status).toBe(401);
    });
  });
});
```

## FastAPI Testing with pytest

### Test Setup

```python
# conftest.py
import pytest
import asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.main import app
from app.database import Base
from app.dependencies import get_db
from app.utils.security import create_access_token, hash_password

TEST_DATABASE_URL = "postgresql+asyncpg://postgres:testpass@localhost:5432/myapi_test"

test_engine = create_async_engine(TEST_DATABASE_URL)
TestSessionFactory = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session", autouse=True)
async def setup_database():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await test_engine.dispose()


@pytest.fixture
async def db_session():
    async with TestSessionFactory() as session:
        yield session
        await session.rollback()


@pytest.fixture
async def client(db_session):
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest.fixture
async def auth_headers(db_session):
    """Create a test user and return auth headers."""
    from app.models.user import User
    user = User(
        id="test-user-id",
        email="test@example.com",
        password_hash=hash_password("testpassword"),
        roles=["user", "admin"],
    )
    db_session.add(user)
    await db_session.commit()

    token = create_access_token(user_id=user.id, roles=user.roles, jti="test-jti")
    return {"Authorization": f"Bearer {token}"}
```

### Unit Tests

```python
# test_user_service.py
import pytest
from unittest.mock import AsyncMock, MagicMock
from app.services.user_service import UserService
from app.schemas.user import UserCreate


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.add = MagicMock()
    return db


class TestUserService:
    async def test_create_user_hashes_password(self, mock_db):
        service = UserService(mock_db)
        dto = UserCreate(email="a@test.com", password="plaintext")
        user = await service.create(dto)

        assert user.password_hash != "plaintext"
        assert user.email == "a@test.com"

    async def test_get_by_id_returns_none_for_missing(self, mock_db):
        mock_db.execute.return_value.scalar_one_or_none.return_value = None
        service = UserService(mock_db)
        result = await service.get_by_id("nonexistent")
        assert result is None
```

### Integration Tests

```python
# test_users_api.py
import pytest
from httpx import AsyncClient


class TestUsersAPI:
    @pytest.mark.asyncio
    async def test_list_users(self, client: AsyncClient, auth_headers: dict):
        response = await client.get("/api/v1/users", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data

    @pytest.mark.asyncio
    async def test_create_user(self, client: AsyncClient, auth_headers: dict):
        payload = {
            "email": "new@test.com",
            "password": "securepass123",
            "display_name": "New User",
        }
        response = await client.post("/api/v1/users", json=payload, headers=auth_headers)
        assert response.status_code == 201
        data = response.json()
        assert data["email"] == "new@test.com"
        assert "password_hash" not in data

    @pytest.mark.asyncio
    async def test_create_user_invalid_email(self, client: AsyncClient, auth_headers: dict):
        payload = {"email": "not-an-email", "password": "securepass123"}
        response = await client.post("/api/v1/users", json=payload, headers=auth_headers)
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_create_user_requires_auth(self, client: AsyncClient):
        payload = {"email": "a@test.com", "password": "securepass123"}
        response = await client.post("/api/v1/users", json=payload)
        assert response.status_code == 403  # No auth header

    @pytest.mark.asyncio
    async def test_get_user_not_found(self, client: AsyncClient, auth_headers: dict):
        response = await client.get("/api/v1/users/nonexistent-id", headers=auth_headers)
        assert response.status_code == 404
```

## Mocking External Services

```typescript
// NestJS — mocking an HTTP client
const mockHttpService = {
  post: jest.fn().mockReturnValue(
    of({ data: { access_token: 'mock-token' }, status: 200 }),
  ),
};

const module = await Test.createTestingModule({
  providers: [
    OAuthService,
    { provide: HttpService, useValue: mockHttpService },
  ],
}).compile();
```

```python
# FastAPI — mocking with respx (HTTP mock for httpx)
import respx
from httpx import Response

@respx.mock
async def test_oauth_callback(client, auth_headers):
    respx.post("https://oauth2.googleapis.com/token").mock(
        return_value=Response(200, json={"access_token": "mock", "id_token": "mock.jwt.token"})
    )
    response = await client.post("/api/v1/auth/oauth/google/callback", json={
        "code": "auth-code", "code_verifier": "verifier", "redirect_uri": "http://localhost"
    })
    assert response.status_code == 200
```

## Coverage Reporting

```bash
# NestJS
npx jest --coverage --coverageReporters=text-summary --coverageThreshold='{"global":{"branches":80,"functions":80,"lines":80}}'

# FastAPI
pytest --cov=app --cov-report=term-missing --cov-fail-under=80
```

## CI Integration

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: myapi_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]
        options: --health-cmd "redis-cli ping"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run test:cov
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_USERNAME: postgres
          DB_PASSWORD: testpass
          DB_NAME: myapi_test
          JWT_SECRET: ci-test-secret-at-least-32-characters
          REDIS_HOST: localhost
```
