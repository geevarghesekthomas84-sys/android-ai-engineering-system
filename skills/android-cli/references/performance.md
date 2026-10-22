# Android Performance Optimization

## Startup Performance

### Measure Startup Time
```powershell
# Cold start measurement
adb shell am force-stop com.example.app
adb shell am start-activity -W -n com.example.app/.MainActivity
# Look for TotalTime in output

# Repeated measurements
1..5 | ForEach-Object {
    adb shell am force-stop com.example.app
    Start-Sleep -Seconds 2
    $result = adb shell am start-activity -W -n com.example.app/.MainActivity
    $result | Select-String "TotalTime"
}
```

### Optimize Startup
- Defer non-critical initialization using `Startup` library or lazy init.
- Use App Startup library for ordered initialization:
  ```kotlin
  class NetworkInitializer : Initializer<OkHttpClient> {
      override fun create(context: Context): OkHttpClient {
          return OkHttpClient.Builder().build()
      }
      override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
  }
  ```
- Avoid heavy work in `Application.onCreate()`.
- Use a baseline profile for AOT compilation of critical paths.

### Baseline Profiles
```kotlin
// benchmark/src/main/java/BaselineProfileGenerator.kt
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {
    @get:Rule
    val rule = BaselineProfileRule()

    @Test
    fun generateProfile() {
        rule.collect(packageName = "com.example.app") {
            startActivityAndWait()
            // Add critical user journeys here
        }
    }
}
```

## Compose Performance

### Avoid Unnecessary Recompositions
```kotlin
// Use stable types â€” data classes, primitives, lambdas with remember
@Composable
fun UserCard(user: User, onClick: () -> Unit) {
    // user is a data class (stable) âœ“
    // onClick should be stable â€” wrap in remember at call site if needed
    Card(onClick = onClick) {
        Text(user.name)
    }
}

// Stabilize lambdas
@Composable
fun ParentScreen(viewModel: HomeViewModel = hiltViewModel()) {
    val onItemClick = remember<(String) -> Unit> { { id -> viewModel.selectItem(id) } }
    ItemList(onItemClick = onItemClick)
}
```

### Use `key` in LazyColumn
```kotlin
LazyColumn {
    items(users, key = { it.id }) { user ->
        UserCard(user)
    }
}
```

### Defer Reads with `derivedStateOf`
```kotlin
val listState = rememberLazyListState()
val showScrollToTop by remember {
    derivedStateOf { listState.firstVisibleItemIndex > 5 }
}
```

### Use `Modifier.drawBehind` for Heavy Drawing
```kotlin
// Instead of creating a new Color in every recomposition
val color = MaterialTheme.colorScheme.primary
Box(modifier = Modifier.drawBehind { drawRect(color) })
```

## Memory Optimization

### Detect Memory Leaks
```powershell
# Get memory info
adb shell dumpsys meminfo com.example.app

# Trigger GC and check
adb shell "cmd activity force-gc com.example.app"
adb shell dumpsys meminfo com.example.app
```

### Common Leak Sources
- Activity/Context references in singletons or static fields.
- Unregistered callbacks (BroadcastReceiver, listeners).
- CoroutineScope not tied to lifecycle.
- Bitmaps not recycled.
- Inner classes holding outer class references.

### Prevention
```kotlin
// Use viewModelScope (auto-cancelled)
viewModelScope.launch { ... }

// Use lifecycleScope in UI (auto-cancelled)
lifecycleScope.launch { ... }

// Never pass Activity context to singletons â€” use Application context
@Provides @Singleton
fun provideSomething(@ApplicationContext context: Context): Something
```

### Image Loading with Coil
```kotlin
// Efficient image loading with memory/disk caching
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(user.avatarUrl)
        .crossfade(true)
        .size(Size.ORIGINAL)  // Or specific size
        .build(),
    contentDescription = "User avatar",
    modifier = Modifier.size(48.dp).clip(CircleShape)
)
```

## Network Performance

### Response Caching
```kotlin
val client = OkHttpClient.Builder()
    .cache(Cache(context.cacheDir.resolve("http_cache"), 10L * 1024 * 1024))
    .build()
```

### Connection Pooling
OkHttp handles this automatically. For multiple API hosts, share a single
OkHttpClient instance.

### Compression
```kotlin
val client = OkHttpClient.Builder()
    .addInterceptor { chain ->
        val request = chain.request().newBuilder()
            .header("Accept-Encoding", "gzip")
            .build()
        chain.proceed(request)
    }
    .build()
```

## Database Performance

### Room Query Optimization
```kotlin
// Use indices for frequently queried columns
@Entity(
    tableName = "users",
    indices = [Index(value = ["email"], unique = true)]
)
data class UserEntity(...)

// Use transactions for batch operations
@Transaction
suspend fun replaceAll(users: List<UserEntity>) {
    deleteAll()
    insertAll(users)
}

// Paginate large result sets
@Query("SELECT * FROM users ORDER BY name LIMIT :limit OFFSET :offset")
suspend fun getPage(limit: Int, offset: Int): List<UserEntity>
```

### Use Paging 3 for Large Lists
```kotlin
@Query("SELECT * FROM users ORDER BY name ASC")
fun getUsersPagingSource(): PagingSource<Int, UserEntity>
```

## Build Performance

```properties
# gradle.properties
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.jvmargs=-Xmx4096m -XX:+UseG1GC
```

```powershell
# Profile a build
.\gradlew assembleDebug --profile
# Report at build/reports/profile/

# Build scan (detailed)
.\gradlew assembleDebug --scan
```

## APK Size Optimization

### R8/ProGuard (Release Builds)
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true     // Code shrinking
        isShrinkResources = true   // Resource shrinking
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

### Analyze APK Size
```powershell
# Use Android Studio's APK Analyzer or:
.\gradlew assembleRelease
# Then inspect: app/build/outputs/apk/release/

# List APK contents size
$aapt = "${ANDROID_HOME}\build-tools\36.1.0\aapt2.exe"
& $aapt dump badging app/build/outputs/apk/release/app-release.apk
```

### Size Reduction Tips
- Remove unused dependencies.
- Use `resConfigs` to include only needed language resources.
- Convert PNGs to WebP.
- Use vector drawables instead of raster images.
- Enable `shrinkResources`.
- Use Android App Bundle (AAB) for Play Store distribution.

```kotlin
android {
    defaultConfig {
        resourceConfigurations += listOf("en", "es")  // Only English and Spanish
    }
}
```

## Profiling Checklist

1. **Startup**: Measure cold/warm/hot start times.
2. **Frame rate**: Check for jank (frames > 16ms).
3. **Memory**: Monitor heap size under typical usage.
4. **Network**: Check request count, payload sizes, caching.
5. **Battery**: Monitor wake locks, background work frequency.
6. **APK size**: Track per-release and compare.
7. **Database**: Check query times for large datasets.
