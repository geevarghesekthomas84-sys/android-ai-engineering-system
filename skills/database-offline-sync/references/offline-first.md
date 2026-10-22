# Offline-First Architecture

## NetworkBoundResource Pattern

The core pattern for offline-first: serve from cache immediately, fetch from network in the background, update cache, re-emit from cache.

```kotlin
inline fun <ResultType, RequestType> networkBoundResource(
    crossinline query: () -> Flow<ResultType>,
    crossinline fetch: suspend () -> RequestType,
    crossinline saveFetchResult: suspend (RequestType) -> Unit,
    crossinline shouldFetch: (ResultType) -> Boolean = { true },
    crossinline onFetchFailed: (Throwable) -> Unit = { }
): Flow<Resource<ResultType>> = flow {
    val data = query().first()
    emit(Resource.Loading(data))

    val flow = if (shouldFetch(data)) {
        try {
            val fetchedData = fetch()
            saveFetchResult(fetchedData)
            query().map { Resource.Success(it) }
        } catch (throwable: Throwable) {
            onFetchFailed(throwable)
            query().map { Resource.Error(throwable, it) }
        }
    } else {
        query().map { Resource.Success(it) }
    }

    emitAll(flow)
}

sealed class Resource<T>(val data: T?, val error: Throwable? = null) {
    class Success<T>(data: T) : Resource<T>(data)
    class Loading<T>(data: T? = null) : Resource<T>(data)
    class Error<T>(throwable: Throwable, data: T? = null) : Resource<T>(data, throwable)
}
```

### Usage in Repository

```kotlin
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val apiService: TaskApiService,
    private val connectivityMonitor: ConnectivityMonitor
) {
    fun getTasks(projectId: Long): Flow<Resource<List<TaskEntity>>> = networkBoundResource(
        query = { taskDao.observeByProject(projectId) },
        fetch = { apiService.getTasks(projectId) },
        saveFetchResult = { response ->
            taskDao.replaceAllForProject(projectId, response.map { it.toEntity() })
        },
        shouldFetch = { cachedData ->
            cachedData.isEmpty() || connectivityMonitor.isOnline.value
        },
        onFetchFailed = { e -> Log.e("TaskRepo", "Fetch failed", e) }
    )
}
```

## Offline Queue (Pending Operations)

Queue write operations when offline. Replay them when connectivity returns.

### Pending Operation Entity

```kotlin
@Entity(
    tableName = "pending_operations",
    indices = [Index("created_at")]
)
data class PendingOperationEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val entityType: String,         // "task", "project"
    val entityId: String,           // local or sync ID
    val operationType: String,      // "CREATE", "UPDATE", "DELETE"
    val payload: String,            // JSON of the request body
    val idempotencyKey: String = UUID.randomUUID().toString(),
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    val retryCount: Int = 0,
    val maxRetries: Int = 5,
    val lastError: String? = null,
    val status: String = "PENDING"  // PENDING, IN_PROGRESS, FAILED, COMPLETED
)

@Dao
interface PendingOperationDao {
    @Query("SELECT * FROM pending_operations WHERE status = 'PENDING' ORDER BY created_at ASC")
    suspend fun getPending(): List<PendingOperationEntity>

    @Insert
    suspend fun insert(operation: PendingOperationEntity)

    @Query("UPDATE pending_operations SET status = :status, last_error = :error, retry_count = retry_count + 1 WHERE id = :id")
    suspend fun updateStatus(id: Long, status: String, error: String? = null)

    @Query("DELETE FROM pending_operations WHERE status = 'COMPLETED'")
    suspend fun deleteCompleted()

    @Query("SELECT COUNT(*) FROM pending_operations WHERE status = 'PENDING'")
    fun observePendingCount(): Flow<Int>
}
```

### Queue Manager

```kotlin
class OfflineQueueManager @Inject constructor(
    private val pendingOpDao: PendingOperationDao,
    private val apiService: TaskApiService,
    private val json: Json
) {
    suspend fun enqueue(operation: PendingOperationEntity) {
        pendingOpDao.insert(operation)
    }

    suspend fun processQueue(): SyncResult {
        val pending = pendingOpDao.getPending()
        var succeeded = 0
        var failed = 0

        for (op in pending) {
            pendingOpDao.updateStatus(op.id, "IN_PROGRESS")
            try {
                executeOperation(op)
                pendingOpDao.updateStatus(op.id, "COMPLETED")
                succeeded++
            } catch (e: Exception) {
                if (op.retryCount >= op.maxRetries) {
                    pendingOpDao.updateStatus(op.id, "FAILED", e.message)
                    failed++
                } else {
                    pendingOpDao.updateStatus(op.id, "PENDING", e.message)
                }
            }
        }
        pendingOpDao.deleteCompleted()
        return SyncResult(succeeded, failed, pending.size)
    }

    private suspend fun executeOperation(op: PendingOperationEntity) {
        when (op.operationType) {
            "CREATE" -> {
                val task = json.decodeFromString<TaskRequest>(op.payload)
                apiService.createTask(task, idempotencyKey = op.idempotencyKey)
            }
            "UPDATE" -> {
                val task = json.decodeFromString<TaskRequest>(op.payload)
                apiService.updateTask(op.entityId, task, idempotencyKey = op.idempotencyKey)
            }
            "DELETE" -> {
                apiService.deleteTask(op.entityId)
            }
        }
    }
}

data class SyncResult(val succeeded: Int, val failed: Int, val total: Int)
```

## Connectivity Monitoring

```kotlin
class ConnectivityMonitor @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val connectivityManager = context.getSystemService<ConnectivityManager>()!!

    val isOnline: StateFlow<Boolean> = callbackFlow {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { trySend(true) }
            override fun onLost(network: Network) { trySend(false) }
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                trySend(caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET))
            }
        }
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager.registerNetworkCallback(request, callback)

        // Emit initial state
        val activeNetwork = connectivityManager.activeNetwork
        val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
        trySend(caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true)

        awaitClose { connectivityManager.unregisterNetworkCallback(callback) }
    }.stateIn(CoroutineScope(Dispatchers.Default), SharingStarted.Eagerly, false)
}
```

## Optimistic UI Updates

Write to local database immediately, show the change in the UI, then sync with server. Roll back on failure.

```kotlin
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val queueManager: OfflineQueueManager,
    private val json: Json
) {
    suspend fun createTask(title: String, projectId: Long): TaskEntity {
        val task = TaskEntity(
            title = title,
            projectId = projectId,
            syncId = UUID.randomUUID().toString(),
            isPendingSync = true,
            status = TaskStatus.TODO
        )
        val id = taskDao.insert(task)
        val savedTask = task.copy(id = id)

        // Queue for server sync
        queueManager.enqueue(
            PendingOperationEntity(
                entityType = "task",
                entityId = savedTask.syncId,
                operationType = "CREATE",
                payload = json.encodeToString(savedTask.toRequest())
            )
        )
        return savedTask
    }
}
```

## Retry with Exponential Backoff

```kotlin
suspend fun <T> retryWithBackoff(
    maxRetries: Int = 5,
    initialDelayMs: Long = 1000,
    maxDelayMs: Long = 30_000,
    factor: Double = 2.0,
    jitterFactor: Double = 0.1,
    retryOn: (Throwable) -> Boolean = { it is IOException || it is HttpException },
    block: suspend () -> T
): T {
    var currentDelay = initialDelayMs
    repeat(maxRetries) { attempt ->
        try {
            return block()
        } catch (e: Throwable) {
            if (attempt == maxRetries - 1 || !retryOn(e)) throw e
            val jitter = (currentDelay * jitterFactor * Random.nextDouble()).toLong()
            delay(currentDelay + jitter)
            currentDelay = (currentDelay * factor).toLong().coerceAtMost(maxDelayMs)
        }
    }
    error("Unreachable")
}
```

## Sync Status Tracking

```kotlin
sealed class SyncState {
    data object Idle : SyncState()
    data object Syncing : SyncState()
    data class Success(val timestamp: Long = System.currentTimeMillis()) : SyncState()
    data class Error(val message: String, val retryable: Boolean = true) : SyncState()
    data class Partial(val synced: Int, val failed: Int) : SyncState()
}

class SyncStatusTracker @Inject constructor() {
    private val _syncState = MutableStateFlow<SyncState>(SyncState.Idle)
    val syncState: StateFlow<SyncState> = _syncState.asStateFlow()

    fun setSyncing() { _syncState.value = SyncState.Syncing }
    fun setSuccess() { _syncState.value = SyncState.Success() }
    fun setError(msg: String) { _syncState.value = SyncState.Error(msg) }
    fun setPartial(synced: Int, failed: Int) { _syncState.value = SyncState.Partial(synced, failed) }
}
```

## WorkManager for Background Sync

```kotlin
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val queueManager: OfflineQueueManager,
    private val syncTracker: SyncStatusTracker
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        syncTracker.setSyncing()
        return try {
            val result = queueManager.processQueue()
            if (result.failed > 0) {
                syncTracker.setPartial(result.succeeded, result.failed)
                Result.retry()
            } else {
                syncTracker.setSuccess()
                Result.success()
            }
        } catch (e: Exception) {
            syncTracker.setError(e.message ?: "Sync failed")
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }

    companion object {
        const val WORK_NAME = "sync_work"
    }
}

// Schedule sync
class SyncScheduler @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val workManager = WorkManager.getInstance(context)

    fun schedulePeriodicSync() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()

        workManager.enqueueUniquePeriodicWork(
            SyncWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
    }

    fun triggerImmediateSync() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = OneTimeWorkRequestBuilder<SyncWorker>()
            .setConstraints(constraints)
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .build()

        workManager.enqueueUniqueWork(
            "${SyncWorker.WORK_NAME}_immediate",
            ExistingWorkPolicy.REPLACE,
            request
        )
    }

    fun observeSyncStatus(): Flow<WorkInfo?> =
        workManager.getWorkInfosForUniqueWorkFlow(SyncWorker.WORK_NAME)
            .map { it.firstOrNull() }
}
```
