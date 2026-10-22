---
name: database-offline-sync
description: Database engineering and offline-first architecture with Room, SQLite, PostgreSQL, Redis, DataStore, migrations, sync strategies, and conflict resolution
metadata:
  author: Custom
  keywords:
  - room
  - sqlite
  - postgresql
  - redis
  - datastore
  - offline-first
  - sync
  - migration
---

# Database & Offline-First Engineering Skill

## Trigger Conditions

Activate this skill when the task involves any of the following:

- **Database schema design**: Entity modeling, table structure, relationships (one-to-many, many-to-many), normalization, denormalization, index planning
- **Offline support**: Offline-first architecture, local caching, pending operation queues, connectivity-aware data fetching
- **Data synchronization**: Client-server sync, bidirectional sync, delta sync, full sync, background sync with WorkManager
- **Database migrations**: Room auto-migrations, manual migrations, schema versioning, zero-downtime migration, rollback
- **Caching**: Room as local cache, Redis caching, HTTP cache headers, in-memory cache, cache invalidation, stale-while-revalidate
- **DataStore**: Preferences DataStore, Proto DataStore, migration from SharedPreferences, typed key-value storage
- **Query optimization**: Index tuning, EXPLAIN QUERY PLAN, pagination, batch operations, transaction performance
- **Conflict resolution**: Last-write-wins, version vectors, merge strategies, conflict detection, user-prompted resolution
- **Repository pattern**: Data source abstraction, NetworkBoundResource, single source of truth, reactive data with Flow

## Capabilities

### Local Storage (Android)
- **Room** (SQLite ORM): Entity design with composite keys, indices, foreign keys, embedded objects; DAO with suspend functions, Flow, PagingSource; TypeConverters; KSP annotation processing; database inspector
- **SQLite**: Direct SQLiteDatabase access, WAL mode, pragma tuning, FTS (full-text search), custom functions
- **DataStore**: Preferences DataStore for simple key-value, Proto DataStore for typed objects with protobuf, migration from SharedPreferences, multi-process support
- **EncryptedSharedPreferences**: SQLCipher for encrypted Room databases

### Backend Storage
- **PostgreSQL**: Schema design, JSONB columns, materialized views, partitioning, connection pooling (HikariCP), Exposed/jOOQ/JDBI query builders
- **Redis**: Caching layer, pub/sub for real-time sync notifications, sorted sets for leaderboards, streams for event sourcing, TTL-based expiration, cluster configuration

### Architecture Patterns
- **Repository pattern**: Single source of truth, local-first reads, background network writes
- **NetworkBoundResource**: Fetch from cache, request from network, save response, serve cache
- **Offline queue**: Pending operations table with retry, exponential backoff, idempotency keys
- **Sync engine**: Delta sync with server timestamps, full sync fallback, pagination of sync batches
- **Conflict resolution**: Last-write-wins, client-wins, server-wins, three-way merge, vector clocks
- **Reactive data**: Room Flow queries, DataStore Flow, StateFlow in ViewModel, combine/transform operators

### Operations
- **Migrations**: Room @AutoMigration, manual Migration class, MigrationTestHelper, destructive fallback, PostgreSQL Flyway/Alembic
- **Testing**: In-memory Room databases, migration tests, DAO tests with Robolectric, sync integration tests
- **Monitoring**: Database inspector, SQLite EXPLAIN, PostgreSQL EXPLAIN ANALYZE, query logging, sync status dashboards
- **Performance**: Index optimization, covering indices, batch inserts inside transactions, WAL journal mode, prepared statements, connection pooling

## Workflow

Follow this sequence for database and offline-first features:

1. **Define Data Model** -- Identify entities, relationships, and access patterns. Determine which data must be available offline and which is network-only.

2. **Design Schema** -- Create Room @Entity classes with proper primary keys, indices, and foreign keys. Design server-side PostgreSQL tables. Map relationships (one-to-many with @Relation, many-to-many with junction tables).

3. **Implement DAO** -- Write @Dao interfaces with suspend functions for writes, Flow<List<T>> for reactive reads, PagingSource<Int, T> for paginated lists. Add @Transaction for compound operations.

4. **Add Migrations** -- Use @AutoMigration for simple changes (add column, add table). Write manual Migration for renames, data transforms, index changes. Always add migration tests.

5. **Build Repository** -- Implement repository with local Room source and remote API source. Use NetworkBoundResource for read operations. Queue writes for offline support.

6. **Implement Sync** -- Add ConnectivityManager monitoring. Build sync engine with delta timestamps. Use WorkManager for periodic and connectivity-triggered sync. Handle pagination of large sync payloads.

7. **Add Conflict Resolution** -- Detect conflicts via version numbers or timestamps. Apply resolution strategy (LWW, merge, user-prompt). Log conflicts for audit. Test edge cases (simultaneous edits, network partitions).

8. **Test** -- Unit test DAOs with in-memory database. Test migrations with MigrationTestHelper. Integration test sync with mock server. Test offline queue replay ordering.

## Reference Files

- `references/room-database.md` -- Room entities, DAOs, database setup, TypeConverters, coroutines, Flow, KSP
- `references/datastore.md` -- Preferences DataStore, Proto DataStore, Hilt integration, migration
- `references/migration-strategies.md` -- Auto-migration, manual migration, testing, PostgreSQL migrations
- `references/offline-first.md` -- NetworkBoundResource, offline queue, connectivity, WorkManager sync
- `references/conflict-resolution.md` -- LWW, merge, vector clocks, detection, testing
- `references/caching-patterns.md` -- Cache-aside, write-through, Redis, HTTP caching, invalidation
- `references/query-optimization.md` -- Indices, EXPLAIN, pagination, batch ops, WAL, connection pooling
