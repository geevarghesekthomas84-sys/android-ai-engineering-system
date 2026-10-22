# Network and Battery Optimization

## Efficient Network Calls

### Batching Requests

Avoid sending many small requests. Combine related data fetches into a single API call:

```kotlin
// BAD: separate request per item
suspend fun loadDashboard() {
    val user = api.getUser()
    val notifications = api.getNotifications()
    val feed = api.getFeed()
    // 3 sequential round-trips
}

// BETTER: parallel but still 3 connections
suspend fun loadDashboard() = coroutineScope {
    val user = async { api.getUser() }
    val notifications = async { api.getNotifications() }
    val feed = async { api.getFeed() }
    DashboardData(user.await(), notifications.await(), feed.await())
}

// BEST: single endpoint returns all dashboard data
suspend fun loadDashboard(): DashboardData = api.getDashboard()
```

### HTTP Compression

Ensure the server supports gzip or brotli. OkHttp automatically adds `Accept-Encoding: gzip` and decompresses responses. For request bodies:

```kotlin
val client = OkHttpClient.Builder()
    .addInterceptor { chain ->
        val original = chain.request()
        if (original.body != null && original.body!!.contentLength() > 1024) {
            val compressed = original.newBuilder()
                .header("Content-Encoding", "gzip")
                .method(original.method, gzip(original.body!!))
                .build()
            chain.proceed(compressed)
        } else {
            chain.proceed(original)
        }
    }
    .build()

private fun gzip(body: RequestBody): RequestBody {
    return object : RequestBody() {
        override fun contentType() = body.contentType()
        override fun writeTo(sink: BufferedSink) {
            val gzipSink = GzipSink(sink).buffer()
            body.writeTo(gzipSink)
            gzipSink.close()
        }
    }
}
```

### Conditional Requests with ETag and Last-Modified

Avoid re-downloading unchanged data:

```kotlin
// OkHttp handles this automatically when you configure a cache
val client = OkHttpClient.Builder()
    .cache(Cache(
        directory = context.cacheDir.resolve("http_cache"),
        maxSize = 50L * 1024 * 1024 // 50 MB
    ))
    .build()
```

With a cache, OkHttp stores `ETag` and `Last-Modified` headers and sends `If-None-Match` / `If-Modified-Since` on subsequent requests. A `304 Not Modified` response returns no body, saving bandwidth.

For manual control:

```kotlin
val request = Request.Builder()
    .url("https://api.example.com/data")
    .header("If-None-Match", storedETag)
    .build()

val response = client.newCall(request).execute()
if (response.code == 304) {
    // Use cached data
} else {
    // Parse new data, store new ETag
    val newETag = response.header("ETag")
}
```

## Image Loading Optimization with Coil

### Disk Cache Configuration

```kotlin
val imageLoader = ImageLoader.Builder(context)
    .diskCache {
        DiskCache.Builder()
            .directory(context.cacheDir.resolve("image_cache"))
            .maxSizeBytes(100L * 1024 * 1024) // 100 MB
            .build()
    }
    .memoryCache {
        MemoryCache.Builder()
            .maxSizePercent(context, 0.20)
            .build()
    }
    .respectCacheHeaders(true)
    .build()
```

### Thumbnail Placeholders

Show a tiny blurred placeholder while the full image loads:

```kotlin
@Composable
fun OptimizedImage(imageUrl: String, thumbnailUrl: String?) {
    var showFullImage by remember { mutableStateOf(false) }

    SubcomposeAsyncImage(
        model = ImageRequest.Builder(LocalContext.current)
            .data(imageUrl)
            .crossfade(true)
            .size(Size.ORIGINAL)
            .build(),
        contentDescription = null,
        loading = {
            if (thumbnailUrl != null) {
                AsyncImage(
                    model = thumbnailUrl,
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxSize()
                        .blur(8.dp),
                    contentScale = ContentScale.Crop,
                )
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                )
            }
        },
        contentScale = ContentScale.Crop,
    )
}
```

### Request Size Limits

Request images at the size you actually display:

```kotlin
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(imageUrl)
        .size(300, 300) // Request only what the composable needs
        .build(),
    contentDescription = null,
    modifier = Modifier.size(150.dp), // Display size in dp
    contentScale = ContentScale.Crop,
)
```

## WorkManager for Deferrable Work

WorkManager is the recommended solution for work that must execute even if the app exits, but can be deferred:

```kotlin
// Define the worker
class SyncWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            repository.syncPendingChanges()
            Result.success()
        } catch (e: IOException) {
            Result.retry()
        }
    }
}

// Schedule with constraints
val syncRequest = PeriodicWorkRequestBuilder<SyncWorker>(
    repeatInterval = 1,
    repeatIntervalTimeUnit = TimeUnit.HOURS,
)
    .setConstraints(
        Constraints.Builder()
            .setRequiredNetworkType(NetworkType.UNMETERED) // WiFi only
            .setRequiresBatteryNotLow(true)
            .build()
    )
    .setBackoffCriteria(
        BackoffPolicy.EXPONENTIAL,
        WorkRequest.MIN_BACKOFF_MILLIS,
        TimeUnit.MILLISECONDS,
    )
    .build()

WorkManager.getInstance(context)
    .enqueueUniquePeriodicWork(
        "data_sync",
        ExistingPeriodicWorkPolicy.KEEP,
        syncRequest,
    )
```

### One-Time Work with Expedited

For urgent work that should start immediately but still survives process death:

```kotlin
val uploadRequest = OneTimeWorkRequestBuilder<UploadWorker>()
    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
    .setInputData(workDataOf("file_path" to filePath))
    .build()

WorkManager.getInstance(context).enqueue(uploadRequest)
```

## Doze Mode and App Standby

Starting from Android 6.0, the system enters Doze mode when the device is stationary, unplugged, and screen-off. In Doze:

- Network access is suspended
- Alarms are deferred
- Wi-Fi scans stop
- Syncs and jobs are deferred
- Wake locks are ignored

### Adapting to Doze

- Use WorkManager instead of AlarmManager for deferrable tasks
- For time-critical tasks, use `setExactAndAllowWhileIdle()` (limited to ~once per 9 minutes)
- Use FCM high-priority messages for urgent server-to-device communication

### App Standby Buckets

Android categorizes apps into usage buckets that affect background work frequency:

| Bucket | Job Frequency | Alarm Frequency |
|---|---|---|
| Active | No restrictions | No restrictions |
| Working Set | Deferred up to 2 hours | Deferred up to 6 minutes |
| Frequent | Deferred up to 8 hours | Deferred up to 30 minutes |
| Rare | Deferred up to 24 hours | Deferred up to 2 hours |
| Restricted | Once per day | Once per day |

Check current bucket:

```kotlin
val usageStatsManager = getSystemService<UsageStatsManager>()
val bucket = usageStatsManager?.appStandbyBucket
// 10 = ACTIVE, 20 = WORKING_SET, 30 = FREQUENT, 40 = RARE, 50 = RESTRICTED
```

## Battery Stats Monitoring

Track battery impact of your app:

```kotlin
val batteryManager = getSystemService<BatteryManager>()

// Current battery level
val level = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)

// Current charging status
val status = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)
val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                 status == BatteryManager.BATTERY_STATUS_FULL

// Adapt behavior based on battery state
if (!isCharging && (level ?: 100) < 20) {
    // Reduce background sync frequency
    // Disable prefetching
    // Lower image quality
}
```

Use the Energy Profiler in Android Studio (Profiler > Energy) to see wake locks, alarms, jobs, and network activity correlated with battery drain.

## Network Profiling

Android Studio's Network Profiler shows each request's timing, size, and headers:

1. Open Profiler and select the Network row
2. Click on individual requests to see:
   - Request/response headers
   - Payload size
   - Timeline (DNS, connect, TLS, request, response)
   - Thread that initiated the request

Look for:
- **Redundant requests**: same URL called multiple times
- **Large payloads**: responses that could be paginated or compressed
- **Sequential requests**: chains that could be parallelized
- **Missing caching**: requests without cache headers

## Reducing Wake Locks

Wake locks prevent the CPU from sleeping and drain the battery. Audit and minimize their use:

```kotlin
// BAD: holding a wake lock for the entire operation
val wakeLock = powerManager.newWakeLock(
    PowerManager.PARTIAL_WAKE_LOCK, "app:sync"
)
wakeLock.acquire(10 * 60 * 1000L) // 10 minutes -- excessive

// GOOD: use WorkManager, which manages wake locks internally
// The system holds a wake lock only for the duration of doWork()
class SyncWorker(...) : CoroutineWorker(...) {
    override suspend fun doWork(): Result {
        // System holds wake lock automatically
        performSync()
        return Result.success()
        // Wake lock released automatically
    }
}
```

Check for wake locks in adb:

```bash
adb shell dumpsys power | grep "Wake Locks"
```

If you must use a wake lock directly, always:
1. Set a timeout: `wakeLock.acquire(timeoutMs)`
2. Release in a `finally` block
3. Use the shortest duration possible
