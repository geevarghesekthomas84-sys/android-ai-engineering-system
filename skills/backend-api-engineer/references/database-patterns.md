# Database Patterns

## PostgreSQL with TypeORM (NestJS)

### Entity Definition

```typescript
import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
  UpdateDateColumn, Index, OneToMany, ManyToOne, JoinColumn,
} from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  @Index()
  email: string;

  @Column({ name: 'password_hash' })
  passwordHash: string;

  @Column({ name: 'display_name', nullable: true })
  displayName: string | null;

  @Column('simple-array', { default: 'user' })
  roles: string[];

  @Column({ name: 'is_deleted', default: false })
  isDeleted: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => Post, (post) => post.author)
  posts: Post[];
}

@Entity('posts')
@Index(['authorId', 'createdAt'])
export class Post {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  title: string;

  @Column('text')
  content: string;

  @Column({ name: 'author_id' })
  authorId: string;

  @ManyToOne(() => User, (user) => user.posts)
  @JoinColumn({ name: 'author_id' })
  author: User;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
```

### Repository Pattern

```typescript
// users.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private usersRepo: Repository<User>,
  ) {}

  async findAll(pagination: PaginationDto) {
    const { page, limit } = pagination;
    const [items, total] = await this.usersRepo.findAndCount({
      where: { isDeleted: false },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
    return { items, total, page, limit };
  }

  async findById(id: string): Promise<User> {
    const user = await this.usersRepo.findOne({
      where: { id, isDeleted: false },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async findByIdWithPosts(id: string): Promise<User> {
    return this.usersRepo.findOne({
      where: { id, isDeleted: false },
      relations: ['posts'], // Eager load to prevent N+1
    });
  }
}
```

### Transactions

```typescript
async transferCredits(fromId: string, toId: string, amount: number) {
  const queryRunner = this.dataSource.createQueryRunner();
  await queryRunner.connect();
  await queryRunner.startTransaction();
  try {
    await queryRunner.manager
      .createQueryBuilder()
      .update(User)
      .set({ credits: () => `credits - ${amount}` })
      .where('id = :id AND credits >= :amount', { id: fromId, amount })
      .execute();

    await queryRunner.manager
      .createQueryBuilder()
      .update(User)
      .set({ credits: () => `credits + ${amount}` })
      .where('id = :id', { id: toId })
      .execute();

    await queryRunner.commitTransaction();
  } catch (err) {
    await queryRunner.rollbackTransaction();
    throw err;
  } finally {
    await queryRunner.release();
  }
}
```

### TypeORM Migrations

```bash
# Generate migration from entity changes
npx typeorm migration:generate src/migrations/AddUserRoles -d src/data-source.ts

# Create empty migration for manual SQL
npx typeorm migration:create src/migrations/SeedDefaultRoles

# Run pending migrations
npx typeorm migration:run -d src/data-source.ts

# Revert last migration
npx typeorm migration:revert -d src/data-source.ts
```

Never set `synchronize: true` in production. Always use migration files.

## PostgreSQL with SQLAlchemy (FastAPI)

### Database Setup

```python
# database.py
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.config import settings

engine = create_async_engine(
    settings.database_url,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,    # Detect stale connections
    pool_recycle=3600,      # Recycle connections after 1 hour
    echo=settings.debug,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)
```

### Model Definition

```python
# models/base.py
import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# models/user.py
from sqlalchemy import String, Boolean, ARRAY, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

class User(Base, TimestampMixin):
    __tablename__ = "users"
    __table_args__ = (
        Index("ix_users_email", "email", unique=True),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    email: Mapped[str] = mapped_column(String(255))
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str | None] = mapped_column(String(100))
    roles: Mapped[list[str]] = mapped_column(ARRAY(String), default=["user"])
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)

    posts: Mapped[list["Post"]] = relationship(back_populates="author", lazy="selectin")
```

### Async Queries

```python
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

class UserService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_users(self, page: int, limit: int, search: str | None = None):
        query = select(User).where(User.is_deleted == False)
        if search:
            query = query.where(User.email.ilike(f"%{search}%"))

        # Count total
        count_query = select(func.count()).select_from(query.subquery())
        total = (await self.db.execute(count_query)).scalar()

        # Fetch page
        query = query.order_by(User.created_at.desc())
        query = query.offset((page - 1) * limit).limit(limit)
        result = await self.db.execute(query)
        users = result.scalars().all()

        return users, total

    async def get_with_posts(self, user_id: str):
        query = (
            select(User)
            .where(User.id == user_id)
            .options(selectinload(User.posts))  # Prevent N+1
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()
```

### Alembic Migrations

```bash
# Initialize Alembic
alembic init alembic

# Generate migration from model changes
alembic revision --autogenerate -m "add user roles column"

# Run migrations
alembic upgrade head

# Rollback one migration
alembic downgrade -1

# Show current migration
alembic current
```

Configure `alembic/env.py` for async:

```python
from app.database import engine
from app.models.base import Base

target_metadata = Base.metadata

async def run_async_migrations():
    async with engine.connect() as connection:
        await connection.run_sync(do_run_migrations)

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()
```

## Connection Pooling

PostgreSQL defaults to max 100 connections. With multiple app instances, configure pooling carefully:

```
# Per-instance settings (4 instances = 80 total connections max)
pool_size=15       # Maintained idle connections
max_overflow=5     # Extra connections under load (temporary)
pool_pre_ping=True # Health-check before reusing
pool_recycle=3600  # Prevent stale connections
```

For high-concurrency apps, add PgBouncer as an external connection pooler.

## Indexing Strategies

```sql
-- Single-column index for frequent lookups
CREATE INDEX ix_users_email ON users(email);

-- Composite index for queries that filter on both columns
CREATE INDEX ix_posts_author_created ON posts(author_id, created_at DESC);

-- Partial index for queries that always filter soft-deleted rows
CREATE INDEX ix_users_active ON users(email) WHERE is_deleted = false;

-- GIN index for full-text search or JSONB
CREATE INDEX ix_posts_content_search ON posts USING gin(to_tsvector('english', content));
```

Only index columns that appear in WHERE, JOIN, or ORDER BY clauses. Every index slows writes.

## N+1 Query Prevention

The N+1 problem: loading a list of N parents, then making N separate queries for their children.

- **TypeORM**: Use `relations` in `find()` or `leftJoinAndSelect` in QueryBuilder
- **SQLAlchemy**: Use `selectinload()`, `joinedload()`, or `subqueryload()` in query options
- **Detection**: Enable query logging in development and look for repeated similar queries

## Redis Caching (Cache-Aside Pattern)

```typescript
// NestJS cache-aside example
@Injectable()
export class UsersService {
  constructor(
    @Inject(CACHE_MANAGER) private cache: Cache,
    @InjectRepository(User) private repo: Repository<User>,
  ) {}

  async findById(id: string): Promise<User> {
    const cacheKey = `user:${id}`;

    // 1. Check cache
    const cached = await this.cache.get<User>(cacheKey);
    if (cached) return cached;

    // 2. Query database
    const user = await this.repo.findOneBy({ id });
    if (!user) throw new NotFoundException();

    // 3. Populate cache (TTL: 5 minutes)
    await this.cache.set(cacheKey, user, 300_000);
    return user;
  }

  async update(id: string, dto: UpdateUserDto): Promise<User> {
    const user = await this.repo.save({ id, ...dto });
    // Invalidate cache on write
    await this.cache.del(`user:${id}`);
    return user;
  }
}
```

## Redis Pub/Sub for Real-Time

```python
# FastAPI Redis pub/sub for broadcasting updates
import redis.asyncio as redis

redis_client = redis.from_url(settings.redis_url)

async def publish_event(channel: str, data: dict):
    await redis_client.publish(channel, json.dumps(data))

async def subscribe_events(channel: str):
    pubsub = redis_client.pubsub()
    await pubsub.subscribe(channel)
    async for message in pubsub.listen():
        if message["type"] == "message":
            yield json.loads(message["data"])
```

Use pub/sub to push real-time updates (new messages, notifications) across multiple app instances to connected WebSocket clients.
