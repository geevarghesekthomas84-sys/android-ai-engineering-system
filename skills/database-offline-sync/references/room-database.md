# Room Database Complete Guide

## KSP Setup (build.gradle.kts)

```kotlin
// project-level build.gradle.kts
plugins {
    id("com.google.devtools.ksp") version "2.1.21-2.0.1" apply false
}

// module-level build.gradle.kts
plugins {
    id("com.google.devtools.ksp")
}

dependencies {
    val roomVersion = "2.7.1"
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    implementation("androidx.room:room-paging:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")
    testImplementation("androidx.room:room-testing:$roomVersion")
}

// Export schema for migration testing
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
    arg("room.generateKotlin", "true")
}
```

## @Entity Design

```kotlin
@Entity(
    tableName = "tasks",
    indices = [
        Index(value = ["project_id"]),
        Index(value = ["status", "due_date"]),
        Index(value = ["sync_id"], unique = true)
    ],
    foreignKeys = [
        ForeignKey(
            entity = Project::class,
            parentColumns = ["id"],
            childColumns = ["project_id"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
data class TaskEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    @ColumnInfo(name = "project_id")
    val projectId: Long,
    val title: String,
    val description: String?,
    @ColumnInfo(name = "due_date")
    val dueDate: Long?,           // epoch millis
    val status: TaskStatus,
    val priority: Int = 0,
    @ColumnInfo(name = "sync_id")
    val syncId: String,           // UUID for server sync
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "is_pending_sync", defaultValue = "0")
    val isPendingSync: Boolean = false,
    val version: Int = 1
)

enum class TaskStatus { TODO, IN_PROGRESS, DONE, ARCHIVED }
```

### Embedded Objects

```kotlin
data class Address(
    val street: String,
    val city: String,
    val state: String,
    @ColumnInfo(name = "zip_code")
    val zipCode: String
)

@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: Long,
    val name: String,
    @Embedded(prefix = "addr_")
    val address: Address
)
// Creates columns: addr_street, addr_city, addr_state, addr_zip_code
```

### Many-to-Many with Junction Table

```kotlin
@Entity(
    tableName = "task_tag_cross_ref",
    primaryKeys = ["taskId", "tagId"],
    foreignKeys = [
        ForeignKey(entity = TaskEntity::class, parentColumns = ["id"], childColumns = ["taskId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = TagEntity::class, parentColumns = ["id"], childColumns = ["tagId"], onDelete = ForeignKey.CASCADE)
    ]
)
data class TaskTagCrossRef(
    val taskId: Long,
    @ColumnInfo(index = true)
    val tagId: Long
)

data class TaskWithTags(
    @Embedded val task: TaskEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "id",
        associateBy = Junction(
            TaskTagCrossRef::class,
            parentColumn = "taskId",
            entityColumn = "tagId"
        )
    )
    val tags: List<TagEntity>
)
```

## @Dao Patterns

```kotlin
@Dao
interface TaskDao {
    // --- Inserts ---
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(task: TaskEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(tasks: List<TaskEntity>)

    @Upsert
    suspend fun upsert(task: TaskEntity): Long

    // --- Updates ---
    @Update
    suspend fun update(task: TaskEntity): Int  // returns rows affected

    @Query("UPDATE tasks SET status = :status, updated_at = :now WHERE id = :id")
    suspend fun updateStatus(id: Long, status: TaskStatus, now: Long = System.currentTimeMillis()): Int

    // --- Deletes ---
    @Delete
    suspend fun delete(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE status = :status")
    suspend fun deleteByStatus(status: TaskStatus): Int

    // --- Queries returning Flow (reactive) ---
    @Query("SELECT * FROM tasks WHERE project_id = :projectId ORDER BY priority DESC, due_date ASC")
    fun observeByProject(projectId: Long): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :id")
    fun observeById(id: Long): Flow<TaskEntity?>

    @Query("SELECT COUNT(*) FROM tasks WHERE status = :status")
    fun observeCountByStatus(status: TaskStatus): Flow<Int>

    // --- Queries returning suspend (one-shot) ---
    @Query("SELECT * FROM tasks WHERE sync_id = :syncId")
    suspend fun getBySyncId(syncId: String): TaskEntity?

    @Query("SELECT * FROM tasks WHERE is_pending_sync = 1 ORDER BY updated_at ASC")
    suspend fun getPendingSync(): List<TaskEntity>

    // --- Paging ---
    @Query("SELECT * FROM tasks WHERE project_id = :projectId ORDER BY due_date ASC")
    fun pagingSource(projectId: Long): PagingSource<Int, TaskEntity>

    // --- Transaction ---
    @Transaction
    @Query("SELECT * FROM tasks WHERE id = :taskId")
    fun getTaskWithTags(taskId: Long): Flow<TaskWithTags>

    @Transaction
    suspend fun replaceAllForProject(projectId: Long, tasks: List<TaskEntity>) {
        deleteByProject(projectId)
        insertAll(tasks)
    }

    @Query("DELETE FROM tasks WHERE project_id = :projectId")
    suspend fun deleteByProject(projectId: Long)
}
```

## @TypeConverter

```kotlin
class Converters {
    @TypeConverter
    fun fromTaskStatus(status: TaskStatus): String = status.name

    @TypeConverter
    fun toTaskStatus(value: String): TaskStatus = TaskStatus.valueOf(value)

    @TypeConverter
    fun fromInstant(instant: Instant?): Long? = instant?.toEpochMilli()

    @TypeConverter
    fun toInstant(millis: Long?): Instant? = millis?.let { Instant.ofEpochMilli(it) }

    @TypeConverter
    fun fromStringList(list: List<String>?): String? = list?.joinToString(",")

    @TypeConverter
    fun toStringList(value: String?): List<String>? = value?.split(",")?.filter { it.isNotEmpty() }
}
```

## @Database

```kotlin
@Database(
    entities = [
        TaskEntity::class,
        ProjectEntity::class,
        TagEntity::class,
        TaskTagCrossRef::class,
        PendingOperationEntity::class
    ],
    version = 3,
    autoMigrations = [
        AutoMigration(from = 1, to = 2),
        AutoMigration(from = 2, to = 3, spec = AppDatabase.Migration2To3::class)
    ],
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun projectDao(): ProjectDao
    abstract fun pendingOperationDao(): PendingOperationDao

    @RenameColumn(tableName = "tasks", fromColumnName = "deadline", toColumnName = "due_date")
    class Migration2To3 : AutoMigrationSpec

    companion object {
        const val DATABASE_NAME = "app_database"
    }
}
```

## Hilt Module

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(context, AppDatabase::class.java, AppDatabase.DATABASE_NAME)
            .addMigrations(MIGRATION_3_4)
            .addCallback(object : RoomDatabase.Callback() {
                override fun onCreate(db: SupportSQLiteDatabase) {
                    super.onCreate(db)
                    // Pre-populate default data
                    db.execSQL("INSERT INTO projects (id, name) VALUES (1, 'Default')")
                }
            })
            .build()
    }

    @Provides fun provideTaskDao(db: AppDatabase): TaskDao = db.taskDao()
    @Provides fun provideProjectDao(db: AppDatabase): ProjectDao = db.projectDao()

    private val MIGRATION_3_4 = object : Migration(3, 4) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL("ALTER TABLE tasks ADD COLUMN assignee_id INTEGER")
            db.execSQL("CREATE INDEX index_tasks_assignee_id ON tasks(assignee_id)")
        }
    }
}
```

## Pre-populated Database

```kotlin
Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
    .createFromAsset("databases/prepopulated.db")   // from assets/
    // OR
    .createFromFile(File(context.filesDir, "initial.db"))
    .build()
```

## Room with Coroutines and Flow

Room-ktx makes all @Insert/@Update/@Delete/@Query suspend functions run on `Dispatchers.IO` automatically. Flow queries re-emit whenever the observed table changes:

```kotlin
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) {
    // Reactive stream -- re-emits on any tasks table change
    fun observeTasks(projectId: Long): Flow<List<TaskEntity>> =
        taskDao.observeByProject(projectId)
            .distinctUntilChanged()
            .flowOn(ioDispatcher)

    // One-shot
    suspend fun getTask(syncId: String): TaskEntity? =
        withContext(ioDispatcher) { taskDao.getBySyncId(syncId) }
}
```

## Database Inspector

Enable in Android Studio: View > Tool Windows > App Inspection > Database Inspector. Supports live queries, table browsing, and modifying data on debug builds. No code changes needed -- works automatically with Room.
