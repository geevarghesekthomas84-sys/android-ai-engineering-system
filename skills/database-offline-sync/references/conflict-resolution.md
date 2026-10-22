# Conflict Resolution Strategies

## Conflict Detection

### Version Numbers

Every entity carries a `version` integer. The server increments on each successful write. Conflict occurs when the client sends an update with a version lower than the server's current version.

```kotlin
// Client sends update
data class TaskUpdateRequest(
    val syncId: String,
    val title: String,
    val status: String,
    val version: Int  // client's last known version
)

// Server checks
fun updateTask(request: TaskUpdateRequest): TaskUpdateResponse {
    val current = taskRepository.findBySyncId(request.syncId)
        ?: throw NotFoundException("Task not found")

    if (request.version < current.version) {
        return TaskUpdateResponse(
            conflict = true,
            serverVersion = current.toDto(),
            clientVersion = request
        )
    }
    val updated = current.copy(
        title = request.title,
        status = request.status,
        version = current.version + 1,
        updatedAt = Instant.now()
    )
    taskRepository.save(updated)
    return TaskUpdateResponse(conflict = false, serverVersion = updated.toDto())
}
```

### Timestamp Comparison

```kotlin
data class SyncableEntity(
    val syncId: String,
    val updatedAt: Instant,
    val serverUpdatedAt: Instant?  // null if never synced
)

fun detectConflict(local: SyncableEntity, remote: SyncableEntity): Boolean {
    // Conflict if both changed since last sync
    val lastSync = local.serverUpdatedAt ?: return false
    return local.updatedAt > lastSync && remote.updatedAt > lastSync
}
```

### Hash Comparison

Compute a hash of the entity content. If the client's base hash differs from the server's current hash, a concurrent modification occurred.

```kotlin
fun contentHash(task: TaskEntity): String {
    val content = "${task.title}|${task.description}|${task.status}|${task.priority}"
    return MessageDigest.getInstance("SHA-256")
        .digest(content.toByteArray())
        .joinToString("") { "%02x".format(it) }
}
```

## Resolution Strategies

### Last-Write-Wins (LWW)

Simplest strategy. The most recent `updatedAt` timestamp wins. Risk: silent data loss.

```kotlin
fun resolveLastWriteWins(local: TaskEntity, remote: TaskDto): TaskEntity {
    return if (local.updatedAt >= remote.updatedAt) {
        local  // keep local
    } else {
        remote.toEntity()  // take server
    }
}
```

### Server-Wins / Client-Wins

Deterministic. Server-wins is safest for data integrity. Client-wins is best for user experience.

```kotlin
fun resolveServerWins(local: TaskEntity, remote: TaskDto): TaskEntity =
    remote.toEntity().copy(id = local.id, isPendingSync = false)

fun resolveClientWins(local: TaskEntity, remote: TaskDto): TaskEntity =
    local.copy(version = remote.version + 1, isPendingSync = true)
```

### Field-Level Merge

Merge non-conflicting field changes. Only conflict on fields both sides modified.

```kotlin
data class MergeResult(
    val merged: TaskEntity,
    val conflictingFields: List<String>
)

fun fieldLevelMerge(
    base: TaskEntity,     // last synced state
    local: TaskEntity,    // client current
    remote: TaskDto       // server current
): MergeResult {
    val conflicts = mutableListOf<String>()
    var merged = local.copy()

    // Title: if both changed, conflict; if only one changed, take that change
    val localTitleChanged = local.title != base.title
    val remoteTitleChanged = remote.title != base.title
    when {
        localTitleChanged && remoteTitleChanged && local.title != remote.title -> {
            conflicts.add("title")
            merged = merged.copy(title = remote.title)  // default to server
        }
        remoteTitleChanged && !localTitleChanged -> {
            merged = merged.copy(title = remote.title)
        }
        // else keep local
    }

    // Status: same pattern
    val localStatusChanged = local.status != base.status
    val remoteStatusChanged = remote.status != base.status.name
    when {
        localStatusChanged && remoteStatusChanged && local.status.name != remote.status -> {
            conflicts.add("status")
            merged = merged.copy(status = TaskStatus.valueOf(remote.status))
        }
        remoteStatusChanged && !localStatusChanged -> {
            merged = merged.copy(status = TaskStatus.valueOf(remote.status))
        }
    }

    return MergeResult(
        merged = merged.copy(version = remote.version + 1, isPendingSync = conflicts.isEmpty()),
        conflictingFields = conflicts
    )
}
```

### Vector Clocks (Distributed Systems)

Track per-device version to detect concurrent updates without a central server timestamp.

```kotlin
data class VectorClock(
    val versions: Map<String, Long> = emptyMap()  // deviceId -> version
) {
    fun increment(deviceId: String): VectorClock =
        copy(versions = versions + (deviceId to (versions[deviceId] ?: 0) + 1))

    fun merge(other: VectorClock): VectorClock {
        val allKeys = versions.keys + other.versions.keys
        return VectorClock(allKeys.associateWith { key ->
            maxOf(versions[key] ?: 0, other.versions[key] ?: 0)
        })
    }

    fun happenedBefore(other: VectorClock): Boolean =
        versions.all { (k, v) -> v <= (other.versions[k] ?: 0) } &&
        versions != other.versions

    fun isConcurrent(other: VectorClock): Boolean =
        !happenedBefore(other) && !other.happenedBefore(this)
}
```

## User-Prompted Resolution

When automatic resolution is insufficient, show the user both versions.

```kotlin
sealed class ConflictAction {
    data object KeepLocal : ConflictAction()
    data object KeepRemote : ConflictAction()
    data class KeepMerged(val merged: TaskEntity) : ConflictAction()
}

// ViewModel
class ConflictResolutionViewModel @Inject constructor(
    private val taskDao: TaskDao,
    private val syncService: SyncService
) : ViewModel() {
    private val _conflicts = MutableStateFlow<List<ConflictItem>>(emptyList())
    val conflicts: StateFlow<List<ConflictItem>> = _conflicts.asStateFlow()

    fun resolve(conflictId: Long, action: ConflictAction) {
        viewModelScope.launch {
            when (action) {
                is ConflictAction.KeepLocal -> syncService.forceUpload(conflictId)
                is ConflictAction.KeepRemote -> syncService.acceptRemote(conflictId)
                is ConflictAction.KeepMerged -> syncService.uploadMerged(conflictId, action.merged)
            }
        }
    }
}

data class ConflictItem(
    val id: Long,
    val entityType: String,
    val localValue: String,    // JSON or display text
    val remoteValue: String,
    val conflictingFields: List<String>,
    val detectedAt: Long
)
```

## Conflict Log for Audit

```kotlin
@Entity(tableName = "conflict_log")
data class ConflictLogEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val entityType: String,
    val entitySyncId: String,
    val localVersion: Int,
    val remoteVersion: Int,
    val conflictFields: String,  // comma-separated
    val resolution: String,      // "LOCAL_WINS", "REMOTE_WINS", "MERGED", "USER_CHOICE"
    val resolvedBy: String?,     // user ID if user-prompted
    val detectedAt: Long = System.currentTimeMillis(),
    val resolvedAt: Long? = null
)

@Dao
interface ConflictLogDao {
    @Insert
    suspend fun log(entry: ConflictLogEntity)

    @Query("SELECT * FROM conflict_log WHERE entity_sync_id = :syncId ORDER BY detected_at DESC")
    suspend fun getHistory(syncId: String): List<ConflictLogEntity>

    @Query("SELECT COUNT(*) FROM conflict_log WHERE resolution = 'USER_CHOICE' AND resolved_at IS NULL")
    fun observeUnresolvedCount(): Flow<Int>
}
```

## Testing Conflict Scenarios

```kotlin
@Test
fun `concurrent updates detected as conflict`() = runTest {
    val base = TaskEntity(id = 1, title = "Original", version = 1, syncId = "abc", projectId = 1, status = TaskStatus.TODO)

    val local = base.copy(title = "Local Edit", updatedAt = 1000L)
    val remote = TaskDto(syncId = "abc", title = "Remote Edit", version = 2, updatedAt = 2000L, status = "TODO")

    val result = fieldLevelMerge(base, local, remote)
    assertTrue(result.conflictingFields.contains("title"))
}

@Test
fun `vector clock detects concurrent modification`() {
    val clockA = VectorClock(mapOf("A" to 2, "B" to 1))
    val clockB = VectorClock(mapOf("A" to 1, "B" to 2))
    assertTrue(clockA.isConcurrent(clockB))
}

@Test
fun `last-write-wins keeps latest`() {
    val local = TaskEntity(id = 1, title = "Old", updatedAt = 100, syncId = "x", projectId = 1, status = TaskStatus.TODO)
    val remote = TaskDto(syncId = "x", title = "New", updatedAt = 200, status = "TODO", version = 2)
    val resolved = resolveLastWriteWins(local, remote)
    assertEquals("New", resolved.title)
}
```
