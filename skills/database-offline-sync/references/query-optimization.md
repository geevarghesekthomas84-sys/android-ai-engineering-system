# Query Optimization

## SQLite / Room Index Design

### Basic Index

```kotlin
@Entity(
    tableName = "tasks",
    indices = [
        Index("project_id"),                          // single column
        Index("status", "due_date"),                  // composite
        Index(value = ["sync_id"], unique = true),    // unique
        Index(value = ["email"], unique = true, orders = [Index.Order.ASC])
    ]
)
```

### Composite Index Order

The leftmost prefix rule: a composite index on `(status, due_date)` supports queries filtering on `status` alone or `status + due_date`, but not `due_date` alone.

```sql
-- Uses index (status, due_date)
SELECT * FROM tasks WHERE status = 'TODO' ORDER BY due_date ASC;
SELECT * FROM tasks WHERE status = 'TODO';

-- Does NOT use the composite index (needs separate index on due_date)
SELECT * FROM tasks WHERE due_date < 1698000000;
```

### Covering Index

A covering index includes all columns the query needs, avoiding a table lookup:

```sql
-- If you frequently run:
SELECT title, status FROM tasks WHERE project_id = ? ORDER BY due_date;

-- Create:
CREATE INDEX idx_tasks_covering ON tasks(project_id, due_date, title, status);
-- SQLite reads the index only -- no table access
```

### Partial Index (SQLite 3.8.0+, API 21+)

Index only rows matching a condition. Smaller index, faster writes:

```sql
CREATE INDEX idx_tasks_pending ON tasks(updated_at) WHERE is_pending_sync = 1;
-- Only indexes rows that need syncing
```

In Room, add partial indices via manual migration or @Database callback since the annotation does not support WHERE clauses.

## EXPLAIN QUERY PLAN

Use to verify index usage. Run in Android Studio Database Inspector or via:

```kotlin
// Debug-only helper
@RawQuery
fun explain(query: SupportSQLiteQuery): List<ExplainRow>

// Usage in a test
val plan = db.openHelper.writableDatabase.query(
    "EXPLAIN QUERY PLAN SELECT * FROM tasks WHERE status = 'TODO' AND project_id = 5 ORDER BY due_date"
)
while (plan.moveToNext()) {
    Log.d("EXPLAIN", "id=${plan.getInt(0)} parent=${plan.getInt(1)} detail=${plan.getString(3)}")
}
plan.close()
```

Output signals:
- `SEARCH tasks USING INDEX idx_tasks_status_due` -- good, using index
- `SCAN tasks` -- bad, full table scan
- `USE TEMP B-TREE FOR ORDER BY` -- sorting not covered by index

## Avoiding Full Table Scans

1. Add an index on every column used in WHERE, JOIN ON, and ORDER BY
2. Avoid functions on indexed columns: `WHERE LOWER(name) = 'foo'` cannot use an index on `name`. Instead store a normalized column or use COLLATE NOCASE
3. Avoid `LIKE '%pattern'` (leading wildcard). Use FTS for full-text search
4. Use `EXISTS` instead of `IN` for subqueries with large result sets

```sql
-- Bad: can't use index
SELECT * FROM tasks WHERE SUBSTR(title, 1, 3) = 'Bug';

-- Good: range scan on index
SELECT * FROM tasks WHERE title >= 'Bug' AND title < 'Buh';
```

## Pagination

### LIMIT/OFFSET (simple but slow for large offsets)

```kotlin
@Query("SELECT * FROM tasks ORDER BY created_at DESC LIMIT :limit OFFSET :offset")
suspend fun getPage(limit: Int, offset: Int): List<TaskEntity>
// Problem: OFFSET 10000 still scans 10000 rows then discards them
```

### Keyset Pagination (fast, stable)

```kotlin
@Query("""
    SELECT * FROM tasks 
    WHERE (created_at < :lastCreatedAt) OR (created_at = :lastCreatedAt AND id < :lastId)
    ORDER BY created_at DESC, id DESC 
    LIMIT :limit
""")
suspend fun getNextPage(lastCreatedAt: Long, lastId: Long, limit: Int): List<TaskEntity>
```

### Room Paging 3

```kotlin
@Query("SELECT * FROM tasks WHERE project_id = :projectId ORDER BY due_date ASC")
fun pagingSource(projectId: Long): PagingSource<Int, TaskEntity>

// In ViewModel
val pager = Pager(
    config = PagingConfig(pageSize = 20, enablePlaceholders = false, prefetchDistance = 5),
    pagingSourceFactory = { taskDao.pagingSource(projectId) }
).flow.cachedIn(viewModelScope)
```

## Batch Operations

Always wrap batch inserts/updates in a transaction. Without a transaction, each operation triggers a separate disk sync.

```kotlin
@Dao
interface TaskDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(tasks: List<TaskEntity>)  // Room wraps in transaction

    @Transaction
    suspend fun replaceAll(projectId: Long, tasks: List<TaskEntity>) {
        deleteByProject(projectId)
        insertAll(tasks)
    }
}

// For very large batches, chunk to avoid memory pressure
suspend fun insertLargeBatch(tasks: List<TaskEntity>) {
    tasks.chunked(500).forEach { chunk ->
        taskDao.insertAll(chunk)
    }
}
```

### Raw Batch with Compiled Statement

For maximum insert performance:

```kotlin
suspend fun bulkInsert(db: SupportSQLiteDatabase, tasks: List<TaskEntity>) {
    val sql = "INSERT OR REPLACE INTO tasks (sync_id, title, status, project_id) VALUES (?, ?, ?, ?)"
    val stmt = db.compileStatement(sql)
    db.beginTransaction()
    try {
        tasks.forEach { task ->
            stmt.clearBindings()
            stmt.bindString(1, task.syncId)
            stmt.bindString(2, task.title)
            stmt.bindString(3, task.status.name)
            stmt.bindLong(4, task.projectId)
            stmt.executeInsert()
        }
        db.setTransactionSuccessful()
    } finally {
        db.endTransaction()
    }
}
```

## WAL Mode

Write-Ahead Logging allows concurrent reads and writes. Room enables WAL by default. To verify or configure:

```kotlin
Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
    .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)  // default
    .build()

// WAL advantages:
// - Readers do not block writers
// - Writers do not block readers
// - Better write performance (sequential log writes)
// WAL trade-offs:
// - Slightly more disk space (WAL file + shared memory file)
// - Checkpoint overhead (WAL -> main DB)
```

## PostgreSQL Query Planning

### EXPLAIN ANALYZE

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT t.*, p.name as project_name
FROM tasks t
JOIN projects p ON p.id = t.project_id
WHERE t.status = 'TODO' AND t.due_date < NOW()
ORDER BY t.priority DESC
LIMIT 20;
```

Read the output:
- `Seq Scan` -- full table scan (add an index)
- `Index Scan using idx_name` -- good
- `Index Only Scan` -- best (covering index)
- `Bitmap Index Scan` -- acceptable for multi-column OR conditions
- `actual time=X..Y` -- startup time and total time in ms
- `rows=N` -- actual rows vs planned (large discrepancy = stale statistics, run `ANALYZE`)
- `Buffers: shared hit=N read=M` -- cache hit ratio

### Common PostgreSQL Index Types

```sql
-- B-tree (default, most queries)
CREATE INDEX idx_tasks_status ON tasks (status);

-- GIN (for JSONB, arrays, full-text search)
CREATE INDEX idx_tasks_metadata ON tasks USING GIN (metadata jsonb_path_ops);

-- GiST (for geometric, range, full-text)
CREATE INDEX idx_tasks_search ON tasks USING GIN (to_tsvector('english', title || ' ' || description));

-- BRIN (for naturally ordered data like timestamps in append-only tables)
CREATE INDEX idx_events_created ON events USING BRIN (created_at);

-- Partial index
CREATE INDEX idx_tasks_active ON tasks (due_date) WHERE status != 'ARCHIVED';

-- Concurrent creation (no table lock)
CREATE INDEX CONCURRENTLY idx_tasks_assignee ON tasks (assignee_id);
```

## Connection Pooling (Backend)

### HikariCP (JVM standard)

```kotlin
// build.gradle.kts: implementation("com.zaxxer:HikariCP:6.2.1")

val dataSource = HikariDataSource(HikariConfig().apply {
    jdbcUrl = "jdbc:postgresql://localhost:5432/appdb"
    username = "app"
    password = System.getenv("DB_PASSWORD")
    maximumPoolSize = 10             // max connections
    minimumIdle = 2                  // keep 2 idle
    idleTimeout = 600_000            // 10 min idle before close
    connectionTimeout = 30_000       // 30s wait for connection
    maxLifetime = 1_800_000          // 30 min max connection age
    poolName = "app-pool"
    addDataSourceProperty("cachePrepStmts", "true")
    addDataSourceProperty("prepStmtCacheSize", "250")
    addDataSourceProperty("prepStmtCacheSqlLimit", "2048")
})
```

## Prepared Statements

Room uses prepared statements automatically for `@Query` annotations. For raw queries, use `SupportSQLiteDatabase.compileStatement()` to reuse the compiled plan:

```kotlin
// Compiled once, executed many times
val stmt = db.compileStatement("UPDATE tasks SET status = ? WHERE id = ?")
tasks.forEach { task ->
    stmt.clearBindings()
    stmt.bindString(1, task.status.name)
    stmt.bindLong(2, task.id)
    stmt.executeUpdateDelete()
}
```

For PostgreSQL, enable prepared statement caching via HikariCP data source properties (`cachePrepStmts`, `prepStmtCacheSize`). JDBC drivers reuse server-side prepared statements across calls, reducing parse overhead.
