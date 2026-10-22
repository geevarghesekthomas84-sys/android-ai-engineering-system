# Network Layer: Retrofit, OkHttp & Offline-First Patterns

## Retrofit Setup with kotlinx.serialization

```kotlin
// build.gradle.kts
dependencies {
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
}
```

```kotlin
// API interface
interface TaskApi {

    @GET("tasks")
    suspend fun getTasks(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
    ): PaginatedResponse<TaskDto>

    @GET("tasks/{id}")
    suspend fun getTask(@Path("id") taskId: String): TaskDto

    @POST("tasks")
    suspend fun createTask(@Body request: CreateTaskRequest): TaskDto

    @PUT("tasks/{id}")
    suspend fun updateTask(
        @Path("id") taskId: String,
        @Body request: UpdateTaskRequest,
    ): TaskDto

    @DELETE("tasks/{id}")
    suspend fun deleteTask(@Path("id") taskId: String)

    @Multipart
    @POST("tasks/{id}/attachments")
    suspend fun uploadAttachment(
        @Path("id") taskId: String,
        @Part file: MultipartBody.Part,
    ): AttachmentDto
}

// DTOs
@Serializable
data class TaskDto(
    val id: String,
    val title: String,
    val description: String?,
    @SerialName("is_completed") val isCompleted: Boolean,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class PaginatedResponse<T>(
    val data: List<T>,
    val page: Int,
    @SerialName("total_pages") val totalPages: Int,
    @SerialName("total_items") val totalItems: Int,
)

@Serializable
data class CreateTaskRequest(
    val title: String,
    val description: String? = null,
)
```

## OkHttp Interceptors

### Auth Interceptor

```kotlin
class AuthInterceptor @Inject constructor(
    private val tokenStore: TokenStore,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val token = tokenStore.accessToken ?: return chain.proceed(chain.request())

        val request = chain.request().newBuilder()
            .header("Authorization", "Bearer $token")
            .build()

        val response = chain.proceed(request)

        // Handle token expiration
        if (response.code == 401) {
            response.close()
            val newToken = runBlocking { tokenStore.refreshToken() }
            if (newToken != null) {
                val retryRequest = chain.request().newBuilder()
                    .header("Authorization", "Bearer $newToken")
                    .build()
                return chain.proceed(retryRequest)
            }
        }
        return response
    }
}
```

### Connectivity Interceptor

```kotlin
class ConnectivityInterceptor @Inject constructor(
    @ApplicationContext private val context: Context,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val connectivityManager = context.getSystemService<ConnectivityManager>()
        val isConnected = connectivityManager
            ?.getNetworkCapabilities(connectivityManager.activeNetwork)
            ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true

        if (!isConnected) {
            throw NoConnectivityException()
        }
        return chain.proceed(chain.request())
    }
}

class NoConnectivityException : IOException("No internet connection")
```

## Sealed Result Type for API Calls

```kotlin
sealed interface ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>
    sealed interface Failure : ApiResult<Nothing> {
        data class HttpError(val code: Int, val message: String) : Failure
        data class NetworkError(val exception: IOException) : Failure
        data class Unknown(val throwable: Throwable) : Failure
    }
}

suspend fun <T> safeApiCall(block: suspend () -> T): ApiResult<T> = try {
    ApiResult.Success(block())
} catch (e: HttpException) {
    val errorBody = e.response()?.errorBody()?.string()
    ApiResult.Failure.HttpError(e.code(), errorBody ?: e.message())
} catch (e: IOException) {
    ApiResult.Failure.NetworkError(e)
} catch (e: CancellationException) {
    throw e // Never catch coroutine cancellation
} catch (e: Throwable) {
    ApiResult.Failure.Unknown(e)
}

// Extension for convenient mapping
inline fun <T, R> ApiResult<T>.map(transform: (T) -> R): ApiResult<R> = when (this) {
    is ApiResult.Success -> ApiResult.Success(transform(data))
    is ApiResult.Failure -> this
}

inline fun <T> ApiResult<T>.onSuccess(action: (T) -> Unit): ApiResult<T> {
    if (this is ApiResult.Success) action(data)
    return this
}

inline fun <T> ApiResult<T>.onFailure(action: (ApiResult.Failure) -> Unit): ApiResult<T> {
    if (this is ApiResult.Failure) action(this)
    return this
}
```

## Retry with Exponential Backoff

```kotlin
suspend fun <T> retryWithBackoff(
    maxRetries: Int = 3,
    initialDelayMs: Long = 1_000,
    maxDelayMs: Long = 16_000,
    factor: Double = 2.0,
    shouldRetry: (Throwable) -> Boolean = { it is IOException },
    block: suspend () -> T,
): T {
    var currentDelay = initialDelayMs
    repeat(maxRetries) { attempt ->
        try {
            return block()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            if (attempt == maxRetries - 1 || !shouldRetry(e)) throw e
            delay(currentDelay)
            currentDelay = (currentDelay * factor).toLong().coerceAtMost(maxDelayMs)
        }
    }
    return block() // Final attempt
}

// Usage in repository
class TaskRepositoryImpl @Inject constructor(
    private val api: TaskApi,
    private val dao: TaskDao,
) : TaskRepository {
    override suspend fun syncTasks(): ApiResult<List<Task>> = safeApiCall {
        retryWithBackoff {
            val response = api.getTasks()
            val tasks = response.data.map { it.toDomain() }
            dao.upsertAll(tasks.map { it.toEntity() })
            tasks
        }
    }
}
```

## Connectivity Monitoring with Flow

```kotlin
class ConnectivityMonitor @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    val isOnline: Flow<Boolean> = callbackFlow {
        val connectivityManager = context.getSystemService<ConnectivityManager>()!!

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { trySend(true) }
            override fun onLost(network: Network) { trySend(false) }
            override fun onCapabilitiesChanged(
                network: Network,
                capabilities: NetworkCapabilities,
            ) {
                trySend(capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET))
            }
        }

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        connectivityManager.registerNetworkCallback(request, callback)

        // Emit initial state
        val isCurrentlyConnected = connectivityManager
            .getNetworkCapabilities(connectivityManager.activeNetwork)
            ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        trySend(isCurrentlyConnected)

        awaitClose { connectivityManager.unregisterNetworkCallback(callback) }
    }.distinctUntilChanged()
}
```

## Offline-First Pattern with Room Caching

The repository exposes a `Flow` from Room as the single source of truth. Network fetches update Room, and the UI observes Room.

```kotlin
class TaskRepositoryImpl @Inject constructor(
    private val api: TaskApi,
    private val dao: TaskDao,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
    private val connectivityMonitor: ConnectivityMonitor,
) : TaskRepository {

    // UI observes this — always has cached data
    override fun observeTasks(): Flow<List<Task>> =
        dao.observeAll().map { entities -> entities.map { it.toDomain() } }

    // Pull fresh data from network and update cache
    override suspend fun refreshTasks(): ApiResult<Unit> = withContext(ioDispatcher) {
        safeApiCall {
            val response = api.getTasks()
            val entities = response.data.map { it.toEntity() }
            dao.deleteAllAndInsert(entities) // Transaction: clear stale + insert fresh
        }.map { } // Map Success<List<TaskEntity>> to Success<Unit>
    }

    // Create with optimistic update
    override suspend fun createTask(title: String): ApiResult<Task> = withContext(ioDispatcher) {
        // Optimistic: insert locally first with pending sync status
        val localEntity = TaskEntity(
            id = UUID.randomUUID().toString(),
            title = title,
            syncStatus = SyncStatus.PENDING_CREATE,
        )
        dao.insert(localEntity)

        // Attempt remote sync
        safeApiCall { api.createTask(CreateTaskRequest(title)) }
            .onSuccess { dto ->
                dao.delete(localEntity.id) // Remove optimistic entry
                dao.insert(dto.toEntity()) // Insert server-confirmed entry
            }
            .onFailure {
                // Keep local entry — WorkManager will retry later
            }
            .map { it.toDomain() }
    }
}

// Room DAO with transaction support
@Dao
interface TaskDao {
    @Query("SELECT * FROM tasks ORDER BY created_at DESC")
    fun observeAll(): Flow<List<TaskEntity>>

    @Upsert
    suspend fun upsertAll(tasks: List<TaskEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :id")
    suspend fun delete(id: String)

    @Transaction
    suspend fun deleteAllAndInsert(tasks: List<TaskEntity>) {
        deleteAll()
        upsertAll(tasks)
    }

    @Query("DELETE FROM tasks")
    suspend fun deleteAll()

    @Query("SELECT * FROM tasks WHERE sync_status != 'SYNCED'")
    suspend fun getPendingSyncTasks(): List<TaskEntity>
}
```

## File Upload with Progress Tracking

```kotlin
class ProgressRequestBody(
    private val file: File,
    private val contentType: MediaType,
    private val onProgress: (Float) -> Unit,
) : RequestBody() {

    override fun contentType(): MediaType = contentType
    override fun contentLength(): Long = file.length()

    override fun writeTo(sink: BufferedSink) {
        val totalBytes = file.length()
        var uploadedBytes = 0L
        val buffer = ByteArray(8_192)

        file.inputStream().use { inputStream ->
            var read: Int
            while (inputStream.read(buffer).also { read = it } != -1) {
                sink.write(buffer, 0, read)
                uploadedBytes += read
                onProgress(uploadedBytes.toFloat() / totalBytes)
            }
        }
    }
}

// Usage
suspend fun uploadFile(taskId: String, file: File, onProgress: (Float) -> Unit): ApiResult<AttachmentDto> {
    val requestBody = ProgressRequestBody(
        file = file,
        contentType = "image/*".toMediaType(),
        onProgress = onProgress,
    )
    val part = MultipartBody.Part.createFormData("file", file.name, requestBody)
    return safeApiCall { api.uploadAttachment(taskId, part) }
}
```
