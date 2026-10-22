# Background Processing: WorkManager, FCM & Services

## WorkManager Setup

```kotlin
// build.gradle.kts
dependencies {
    implementation("androidx.work:work-runtime-ktx:2.10.1")
    implementation("androidx.hilt:hilt-work:1.2.0")
    ksp("androidx.hilt:hilt-compiler:1.2.0")
}
```

## OneTimeWorkRequest

```kotlin
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters,
    private val taskRepository: TaskRepository,
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val result = taskRepository.syncPendingTasks()
            if (result is ApiResult.Success) Result.success()
            else Result.retry()
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure(
                workDataOf("error" to e.message)
            )
        }
    }

    companion object {
        const val WORK_NAME = "sync_tasks"

        fun buildRequest(): OneTimeWorkRequest =
            OneTimeWorkRequestBuilder<SyncWorker>()
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS,
                )
                .build()
    }
}

// Enqueue from repository or ViewModel
class TaskRepositoryImpl @Inject constructor(
    private val workManager: WorkManager,
) : TaskRepository {
    override fun scheduleSyncAfterLocalChange() {
        workManager.enqueueUniqueWork(
            SyncWorker.WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            SyncWorker.buildRequest(),
        )
    }
}
```

## PeriodicWorkRequest

```kotlin
@HiltWorker
class PeriodicSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters,
    private val repository: TaskRepository,
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        repository.refreshTasks()
        return Result.success()
    }

    companion object {
        const val WORK_NAME = "periodic_sync"

        fun buildRequest(): PeriodicWorkRequest =
            PeriodicWorkRequestBuilder<PeriodicSyncWorker>(
                repeatInterval = 1,
                repeatIntervalTimeUnit = TimeUnit.HOURS,
                flexTimeInterval = 15,
                flexTimeIntervalUnit = TimeUnit.MINUTES,
            ).setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .setRequiresBatteryNotLow(true)
                    .build()
            ).build()
    }
}

// Schedule on app startup
@HiltAndroidApp
class MyApp : Application() {
    @Inject lateinit var workManager: WorkManager

    override fun onCreate() {
        super.onCreate()
        workManager.enqueueUniquePeriodicWork(
            PeriodicSyncWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicSyncWorker.buildRequest(),
        )
    }
}
```

## Chaining Workers with Input/Output Data

```kotlin
// Worker that passes output to the next worker
@HiltWorker
class DownloadWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val api: FileApi,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val url = inputData.getString("url") ?: return Result.failure()
        val filePath = api.downloadFile(url)
        return Result.success(workDataOf("file_path" to filePath))
    }
}

@HiltWorker
class ProcessWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val filePath = inputData.getString("file_path") ?: return Result.failure()
        processFile(filePath)
        return Result.success()
    }
}

// Chain them
fun scheduleDownloadAndProcess(url: String) {
    val downloadWork = OneTimeWorkRequestBuilder<DownloadWorker>()
        .setInputData(workDataOf("url" to url))
        .build()

    val processWork = OneTimeWorkRequestBuilder<ProcessWorker>()
        .build()

    workManager
        .beginWith(downloadWork)
        .then(processWork)
        .enqueue()
}
```

## Observing Work Status in Compose

```kotlin
@Composable
fun SyncStatusIndicator() {
    val context = LocalContext.current
    val workManager = remember { WorkManager.getInstance(context) }

    val syncWorkInfo by workManager
        .getWorkInfosForUniqueWorkFlow(SyncWorker.WORK_NAME)
        .collectAsStateWithLifecycle(initialValue = emptyList())

    val isSyncing = syncWorkInfo.any { it.state == WorkInfo.State.RUNNING }

    if (isSyncing) {
        LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
    }
}
```

## FCM Push Notifications

### Setup

```kotlin
// build.gradle.kts
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.8.0"))
    implementation("com.google.firebase:firebase-messaging-ktx")
}
```

### FirebaseMessagingService

```kotlin
class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // Send token to your backend
        CoroutineScope(Dispatchers.IO).launch {
            val entryPoint = EntryPointAccessors.fromApplication(
                applicationContext,
                MessagingEntryPoint::class.java,
            )
            entryPoint.tokenRepository().updateFcmToken(token)
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        when (data["type"]) {
            "task_assigned" -> showTaskNotification(data)
            "chat_message" -> showChatNotification(data)
            else -> message.notification?.let { showGenericNotification(it) }
        }
    }

    private fun showTaskNotification(data: Map<String, String>) {
        val taskId = data["task_id"] ?: return
        val title = data["title"] ?: "New Task"

        // Deep link intent
        val intent = Intent(Intent.ACTION_VIEW, "myapp://task/$taskId".toUri()).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, taskId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_TASKS)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(data["body"])
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val manager = getSystemService<NotificationManager>()!!
        manager.notify(taskId.hashCode(), notification)
    }

    companion object {
        const val CHANNEL_TASKS = "tasks"
        const val CHANNEL_CHAT = "chat"
    }
}
```

### Notification Channels (Android 8+)

```kotlin
// Create channels on app startup
class NotificationHelper @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    fun createChannels() {
        val manager = context.getSystemService<NotificationManager>() ?: return

        val taskChannel = NotificationChannel(
            "tasks",
            "Task Updates",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Notifications for task assignments and updates"
        }

        val chatChannel = NotificationChannel(
            "chat",
            "Chat Messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Notifications for new chat messages"
            enableVibration(true)
        }

        manager.createNotificationChannels(listOf(taskChannel, chatChannel))
    }
}
```

### Request Notification Permission (Android 13+)

```kotlin
@Composable
fun NotificationPermissionRequest() {
    val permissionState = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (!granted) { /* Show rationale or settings prompt */ }
    }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionState.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}
```

## Foreground Service

Use for long-running operations that the user should be aware of (e.g., file upload, music playback).

```kotlin
class UploadService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, "uploads")
            .setContentTitle("Uploading files")
            .setSmallIcon(R.drawable.ic_upload)
            .setProgress(100, 0, true)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        CoroutineScope(Dispatchers.IO + SupervisorJob()).launch {
            performUpload()
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val NOTIFICATION_ID = 1001
    }
}
```

Declare in manifest with the required `foregroundServiceType`:

```xml
<service
    android:name=".UploadService"
    android:foregroundServiceType="dataSync"
    android:exported="false" />
```

## Hilt WorkManager Integration

```kotlin
// Provide WorkManager via Hilt
@Module
@InstallIn(SingletonComponent::class)
object WorkModule {
    @Provides
    @Singleton
    fun provideWorkManager(@ApplicationContext context: Context): WorkManager =
        WorkManager.getInstance(context)
}

// EntryPoint for MessagingService (cannot use @AndroidEntryPoint on Services extending FirebaseMessagingService)
@EntryPoint
@InstallIn(SingletonComponent::class)
interface MessagingEntryPoint {
    fun tokenRepository(): TokenRepository
}
```
