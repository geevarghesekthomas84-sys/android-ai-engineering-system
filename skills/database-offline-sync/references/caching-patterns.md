# Caching Patterns

## Cache-Aside (Read-Through)

Application checks cache first. On miss, fetches from the source, writes to cache, then returns. This is the most common pattern for Room as a local cache for API data.

```kotlin
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val api: TaskApiService
) {
    fun getTask(syncId: String): Flow<TaskEntity?> = flow {
        // 1. Emit cached value immediately
        val cached = taskDao.getBySyncId(syncId)
        if (cached != null) emit(cached)

        // 2. Fetch fresh data
        try {
            val remote = api.getTask(syncId)
            val entity = remote.toEntity()
            taskDao.upsert(entity)
            emit(entity)
        } catch (e: IOException) {
            if (cached == null) throw e
            // Serve stale cache on network error
        }
    }.distinctUntilChanged()
}
```

## Write-Through

Write to both cache and origin in the same operation. Guarantees cache consistency at the cost of write latency.

```kotlin
suspend fun updateTask(task: TaskEntity) {
    // Write to server first
    val response = api.updateTask(task.syncId, task.toRequest())
    // Then update cache with server response (may include server-generated fields)
    taskDao.upsert(response.toEntity())
}
```

## Write-Behind (Write-Back)

Write to cache immediately, then asynchronously write to origin. Better write performance but risks data loss. This is the offline queue pattern.

```kotlin
suspend fun updateTaskOffline(task: TaskEntity) {
    // Write to local cache immediately
    taskDao.upsert(task.copy(isPendingSync = true))
    // Enqueue for background sync
    offlineQueue.enqueue(PendingOperationEntity(
        entityType = "task",
        entityId = task.syncId,
        operationType = "UPDATE",
        payload = json.encodeToString(task.toRequest())
    ))
}
```

## Time-Based Expiration

```kotlin
class CachePolicy(
    val maxAgeMs: Long = 5 * 60 * 1000  // 5 minutes default
) {
    fun isExpired(cachedAtMs: Long): Boolean =
        System.currentTimeMillis() - cachedAtMs > maxAgeMs
}

// Usage in repository
fun getTasks(projectId: Long): Flow<Resource<List<TaskEntity>>> = networkBoundResource(
    query = { taskDao.observeByProject(projectId) },
    fetch = { api.getTasks(projectId) },
    saveFetchResult = { tasks ->
        taskDao.replaceAllForProject(projectId, tasks.map { it.toEntity() })
        cacheTimestampStore.setLastFetch("tasks_$projectId", System.currentTimeMillis())
    },
    shouldFetch = { _ ->
        val lastFetch = cacheTimestampStore.getLastFetch("tasks_$projectId")
        cachePolicy.isExpired(lastFetch)
    }
)
```

## LRU Eviction

Android's `LruCache` for in-memory caching of expensive-to-compute results:

```kotlin
class TaskSummaryCache(maxSize: Int = 50) {
    private val cache = object : LruCache<Long, TaskSummary>(maxSize) {
        override fun sizeOf(key: Long, value: TaskSummary): Int = 1
    }

    fun get(projectId: Long): TaskSummary? = cache.get(projectId)
    fun put(projectId: Long, summary: TaskSummary) { cache.put(projectId, summary) }
    fun evict(projectId: Long) { cache.remove(projectId) }
    fun clear() { cache.evictAll() }
}
```

## Redis Caching (Backend)

```kotlin
// Using Lettuce (Kotlin coroutines-friendly Redis client)
// build.gradle.kts: implementation("io.lettuce:lettuce-core:6.5.3.RELEASE")

class RedisCacheService(
    private val redis: RedisCoroutinesCommands<String, String>,
    private val json: Json
) {
    suspend inline fun <reified T> getOrFetch(
        key: String,
        ttlSeconds: Long = 300,
        crossinline fetch: suspend () -> T
    ): T {
        val cached = redis.get(key)
        if (cached != null) return json.decodeFromString<T>(cached)

        val value = fetch()
        redis.setex(key, ttlSeconds, json.encodeToString(value))
        return value
    }

    suspend fun invalidate(vararg keys: String) {
        redis.del(*keys)
    }

    suspend fun invalidatePattern(pattern: String) {
        var cursor = "0"
        do {
            val result = redis.scan(ScanCursor.of(cursor), ScanArgs.Builder.matches(pattern).limit(100))
            if (result.keys.isNotEmpty()) redis.del(*result.keys.toTypedArray())
            cursor = result.cursor
        } while (!result.isFinished)
    }
}

// Usage
suspend fun getTask(syncId: String): TaskDto {
    return cacheService.getOrFetch("task:$syncId", ttlSeconds = 600) {
        taskRepository.findBySyncId(syncId).toDto()
    }
}

// Invalidate on write
suspend fun updateTask(syncId: String, request: TaskUpdateRequest): TaskDto {
    val updated = taskRepository.update(syncId, request)
    cacheService.invalidate("task:$syncId", "tasks:project:${updated.projectId}")
    return updated.toDto()
}
```

## HTTP Caching

### ETag-Based (Conditional Requests)

```kotlin
// OkHttp interceptor for ETag support
class ETagInterceptor(private val etagStore: ETagStore) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val etag = etagStore.get(request.url.toString())

        val modifiedRequest = if (etag != null) {
            request.newBuilder().header("If-None-Match", etag).build()
        } else request

        val response = chain.proceed(modifiedRequest)

        if (response.code == 304) {
            // Not modified, use cached version
            response.close()
            return response
        }

        response.header("ETag")?.let { newEtag ->
            etagStore.set(request.url.toString(), newEtag)
        }
        return response
    }
}
```

### Cache-Control with OkHttp

```kotlin
val client = OkHttpClient.Builder()
    .cache(Cache(
        directory = File(context.cacheDir, "http_cache"),
        maxSize = 50L * 1024 * 1024  // 50 MB
    ))
    .addNetworkInterceptor { chain ->
        chain.proceed(chain.request()).newBuilder()
            .header("Cache-Control", "public, max-age=300")  // 5 min
            .build()
    }
    .build()
```

## Image Caching with Coil

```kotlin
// build.gradle.kts: implementation("io.coil-kt.coil3:coil-compose:3.1.0")

// Custom ImageLoader with cache settings
val imageLoader = ImageLoader.Builder(context)
    .memoryCachePolicy(CachePolicy.ENABLED)
    .memoryCache {
        MemoryCache.Builder()
            .maxSizePercent(context, 0.25)  // 25% of app memory
            .build()
    }
    .diskCachePolicy(CachePolicy.ENABLED)
    .diskCache {
        DiskCache.Builder()
            .directory(context.cacheDir.resolve("image_cache"))
            .maxSizeBytes(100 * 1024 * 1024)  // 100 MB
            .build()
    }
    .respectCacheHeaders(true)
    .build()
```

## Stale-While-Revalidate

Serve stale cached data immediately while fetching fresh data in the background. The UI updates when the fresh data arrives.

```kotlin
fun <T> staleWhileRevalidate(
    cache: () -> Flow<T?>,
    fetch: suspend () -> T,
    save: suspend (T) -> Unit,
    isStale: (T) -> Boolean
): Flow<T> = channelFlow {
    val cached = cache().first()
    if (cached != null) {
        send(cached)
        if (isStale(cached)) {
            launch {
                try {
                    val fresh = fetch()
                    save(fresh)
                    // Room Flow will auto-emit the new data through cache()
                } catch (_: Exception) { /* serve stale */ }
            }
        }
    } else {
        val fresh = fetch()
        save(fresh)
        // cache() Flow will emit
    }
    emitAll(cache().filterNotNull())
}
```

## Cache Invalidation Strategies

1. **Time-based (TTL)**: Set expiration. Simple but may serve stale data. Good for read-heavy, low-change data.
2. **Event-based**: Invalidate on write. Precise but requires coupling between write and cache paths.
3. **Version-based**: Cache key includes version. `task:v3:abc123`. New version = automatic miss.
4. **Tag-based**: Group cache entries by tag. Invalidate all entries with tag `project:5` when the project changes.
5. **Push invalidation**: Server sends WebSocket/FCM message to invalidate specific client caches.

```kotlin
// Tag-based invalidation example
class TaggedCache @Inject constructor(private val redis: RedisCoroutinesCommands<String, String>) {
    suspend fun setWithTags(key: String, value: String, tags: Set<String>, ttl: Long = 300) {
        redis.setex(key, ttl, value)
        tags.forEach { tag -> redis.sadd("tag:$tag", key) }
    }

    suspend fun invalidateTag(tag: String) {
        val keys = redis.smembers("tag:$tag")
        if (keys.isNotEmpty()) redis.del(*keys.toTypedArray())
        redis.del("tag:$tag")
    }
}
```
