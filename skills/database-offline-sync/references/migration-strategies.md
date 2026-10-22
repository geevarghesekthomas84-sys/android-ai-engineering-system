# Database Migration Strategies

## Room Auto-Migration

Room auto-migrations handle simple schema changes without writing SQL. Requires `exportSchema = true`.

### Simple Auto-Migration (no spec needed)

```kotlin
@Database(
    entities = [TaskEntity::class, ProjectEntity::class],
    version = 2,
    autoMigrations = [
        AutoMigration(from = 1, to = 2)  // handles added columns with defaults, new tables
    ],
    exportSchema = true
)
abstract class AppDatabase : RoomDatabase() { ... }
```

Auto-migration handles automatically: adding a new column with a default value, adding a new entity/table, adding a new index.

### Auto-Migration with Spec

Required for renames, deletes, or ambiguous changes:

```kotlin
@Database(
    version = 5,
    autoMigrations = [
        AutoMigration(from = 1, to = 2),
        AutoMigration(from = 2, to = 3, spec = AppDatabase.Migrate2To3::class),
        AutoMigration(from = 3, to = 4, spec = AppDatabase.Migrate3To4::class),
        AutoMigration(from = 4, to = 5, spec = AppDatabase.Migrate4To5::class),
    ]
)
abstract class AppDatabase : RoomDatabase() {

    @RenameColumn(tableName = "tasks", fromColumnName = "deadline", toColumnName = "due_date")
    class Migrate2To3 : AutoMigrationSpec

    @DeleteColumn(tableName = "tasks", columnName = "legacy_field")
    class Migrate3To4 : AutoMigrationSpec

    @RenameTable(fromTableName = "task_items", toTableName = "tasks")
    class Migrate4To5 : AutoMigrationSpec
}
```

## Manual Migration

Use when auto-migration cannot handle the change: data transforms, complex index changes, column type changes, moving data between tables.

```kotlin
val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        // Add new column
        db.execSQL("ALTER TABLE tasks ADD COLUMN assignee_id INTEGER")

        // Create new index
        db.execSQL("CREATE INDEX index_tasks_assignee_id ON tasks(assignee_id)")

        // Data transform: split full_name into first_name and last_name
        db.execSQL("ALTER TABLE users ADD COLUMN first_name TEXT NOT NULL DEFAULT ''")
        db.execSQL("ALTER TABLE users ADD COLUMN last_name TEXT NOT NULL DEFAULT ''")
        db.execSQL("""
            UPDATE users SET
                first_name = SUBSTR(full_name, 1, INSTR(full_name, ' ') - 1),
                last_name = SUBSTR(full_name, INSTR(full_name, ' ') + 1)
            WHERE full_name LIKE '% %'
        """)
        db.execSQL("UPDATE users SET first_name = full_name WHERE full_name NOT LIKE '% %'")
    }
}

// SQLite does not support DROP COLUMN before 3.35.0 (API 34+).
// For older API levels, recreate the table:
val MIGRATION_6_7 = object : Migration(6, 7) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE tasks_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                title TEXT NOT NULL,
                status TEXT NOT NULL,
                due_date INTEGER
            )
        """)
        db.execSQL("INSERT INTO tasks_new (id, title, status, due_date) SELECT id, title, status, due_date FROM tasks")
        db.execSQL("DROP TABLE tasks")
        db.execSQL("ALTER TABLE tasks_new RENAME TO tasks")
        db.execSQL("CREATE INDEX index_tasks_status ON tasks(status)")
    }
}
```

### Register Migrations

```kotlin
Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
    .addMigrations(MIGRATION_5_6, MIGRATION_6_7)
    .build()
```

## Destructive Migration Fallback

Use only when data loss is acceptable (e.g., cache databases):

```kotlin
Room.databaseBuilder(context, AppDatabase::class.java, "cache.db")
    .fallbackToDestructiveMigration()          // any version mismatch
    .fallbackToDestructiveMigrationFrom(1, 2)  // only from specific versions
    .fallbackToDestructiveMigrationOnDowngrade() // only on downgrades
    .build()
```

## Migration Testing

### MigrationTestHelper

```kotlin
@RunWith(AndroidJUnit4::class)
class MigrationTest {
    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        AppDatabase::class.java
    )

    @Test
    fun migrate5To6() {
        // Create database at version 5
        helper.createDatabase("test-db", 5).apply {
            execSQL("INSERT INTO tasks (id, title, status) VALUES (1, 'Test', 'TODO')")
            close()
        }

        // Run migration and validate
        val db = helper.runMigrationsAndValidate("test-db", 6, true, MIGRATION_5_6)

        // Verify data integrity
        val cursor = db.query("SELECT assignee_id FROM tasks WHERE id = 1")
        assertTrue(cursor.moveToFirst())
        assertTrue(cursor.isNull(0))  // new column should be null
        cursor.close()
        db.close()
    }

    @Test
    fun migrateAll() {
        // Create oldest version
        helper.createDatabase("test-db", 1).close()

        // Migrate through all versions
        Room.databaseBuilder(
            InstrumentationRegistry.getInstrumentation().targetContext,
            AppDatabase::class.java,
            "test-db"
        )
            .addMigrations(*ALL_MIGRATIONS)
            .build()
            .apply {
                openHelper.writableDatabase  // triggers migration
                close()
            }
    }
}
```

## PostgreSQL Migrations with Flyway

### Setup (build.gradle.kts for backend/Spring Boot)

```kotlin
dependencies {
    implementation("org.flywaydb:flyway-core:11.3.1")
    implementation("org.flywaydb:flyway-database-postgresql:11.3.1")
    runtimeOnly("org.postgresql:postgresql:42.7.5")
}
```

### Migration Files (src/main/resources/db/migration/)

```sql
-- V1__create_tasks_table.sql
CREATE TABLE tasks (
    id BIGSERIAL PRIMARY KEY,
    sync_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'TODO',
    priority INTEGER NOT NULL DEFAULT 0,
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_tasks_status_due ON tasks (status, due_date);
CREATE INDEX idx_tasks_sync_id ON tasks (sync_id);

-- V2__add_assignee.sql
ALTER TABLE tasks ADD COLUMN assignee_id BIGINT REFERENCES users(id);
CREATE INDEX idx_tasks_assignee ON tasks (assignee_id);

-- V3__add_full_text_search.sql
ALTER TABLE tasks ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,''))) STORED;
CREATE INDEX idx_tasks_search ON tasks USING GIN (search_vector);
```

### Repeatable Migrations

```sql
-- R__update_task_statistics_view.sql (re-run on every change)
CREATE OR REPLACE VIEW task_statistics AS
SELECT
    project_id,
    status,
    COUNT(*) as count,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at))) as avg_completion_secs
FROM tasks
GROUP BY project_id, status;
```

## Zero-Downtime Migration Strategies

1. **Expand-Contract Pattern**: Add new column (expand) -> backfill data -> update app to use new column -> drop old column (contract). Never rename or drop in a single step.

2. **Backward-Compatible Additions**: New columns must have defaults or be nullable. New tables are always safe. New indices are safe (CREATE INDEX CONCURRENTLY in PostgreSQL).

3. **Online Schema Change** (PostgreSQL): `CREATE INDEX CONCURRENTLY` avoids locking the table. For large table alterations, use `pg_repack` or logical replication switchover.

4. **Feature Flags**: Deploy code that reads both old and new schema behind a flag. Flip when migration is verified.

## Rollback Strategies

- **Room**: Ship a downgrade migration or use `fallbackToDestructiveMigrationOnDowngrade()` for cache DBs. Always keep the previous APK version available for rollback.
- **PostgreSQL/Flyway**: Flyway community does not support undo. Write a compensating V(n+1) migration. Or use Flyway Teams `undo` feature. Always test rollback SQL in staging.
- **Schema version table**: Both Room (room_master_table) and Flyway (flyway_schema_history) track applied versions. Query to verify current state before rollback.

## Version Control Best Practices

- Export Room schemas to `schemas/` directory (configure via KSP arg) and commit to version control
- Number Flyway migrations sequentially (V1, V2, V3) on trunk; use timestamps (V20261021120000) on feature branches to avoid conflicts
- Review migration SQL in code review -- every migration is a production deployment risk
- Keep a migration changelog in your project docs
