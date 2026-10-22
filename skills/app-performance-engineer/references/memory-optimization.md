# Memory Optimization

## Detecting Leaks with LeakCanary

LeakCanary automatically detects memory leaks in debug builds and shows a notification with the leak trace.

### Setup

```kotlin
// Only in debug builds -- LeakCanary auto-installs via ContentProvider
debugImplementation("com.squareup.leakcanary:leakcanary-android:2.14")
```

No code changes needed. LeakCanary watches destroyed Activities, Fragments, ViewModels, and Services. When a watched object is not garbage collected within 5 seconds after destruction, LeakCanary dumps the heap and analyzes the retention path.

### Custom Object Watching

Watch your own objects that should be garbage collected:

```kotlin
class FeatureManager : DefaultLifecycleObserver {
    private val heavyCache = HeavyCache()

    override fun onDestroy(owner: LifecycleOwner) {
        // Tell LeakCanary to watch this object
        AppWatcher.objectWatcher.expectWeaklyReachable(
            heavyCache, "FeatureManager.heavyCache should be GC'd after onDestroy"
        )
    }
}
```

## Common Leak Patterns

### Inner Class Holding Activity Reference

```kotlin
// LEAK: anonymous inner class holds implicit reference to Activity
class DetailActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            // This lambda captures `this` (the Activity)
            updateUI()
        }, 30_000)
    }
}

// FIX: use lifecycleScope which auto-cancels
class DetailActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleScope.launch {
            delay(30_000)
            updateUI()
        }
    }
}
```

### Unregistered Listeners

```kotlin
// LEAK: listener registered but never unregistered
class LocationActivity : ComponentActivity() {
    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            updateMap(location)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        locationManager.requestLocationUpdates(
            LocationManager.GPS_PROVIDER, 0L, 0f, locationListener
        )
    }

    // FIX: always unregister
    override fun onDestroy() {
        super.onDestroy()
        locationManager.removeUpdates(locationListener)
    }
}
```

### Static Context References

```kotlin
// LEAK: storing Activity context in a singleton
object AppCache {
    lateinit var context: Context  // If this is an Activity, it leaks
}

// FIX: use applicationContext
object AppCache {
    lateinit var context: Context
    fun init(context: Context) {
        this.context = context.applicationContext
    }
}
```

## Bitmap Memory Management

### BitmapFactory.Options for Downsampling

Loading a full-resolution camera photo (4000x3000 at ARGB_8888 = 48MB) into memory when you only need a 400x300 thumbnail is wasteful.

```kotlin
fun decodeSampledBitmap(
    resources: Resources,
    resId: Int,
    reqWidth: Int,
    reqHeight: Int,
): Bitmap {
    // First, decode bounds only (no pixel allocation)
    val options = BitmapFactory.Options().apply {
        inJustDecodeBounds = true
    }
    BitmapFactory.decodeResource(resources, resId, options)

    // Calculate inSampleSize
    options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)

    // Decode with inSampleSize set
    options.inJustDecodeBounds = false
    return BitmapFactory.decodeResource(resources, resId, options)
}

fun calculateInSampleSize(
    options: BitmapFactory.Options,
    reqWidth: Int,
    reqHeight: Int,
): Int {
    val (height, width) = options.outHeight to options.outWidth
    var inSampleSize = 1

    if (height > reqHeight || width > reqWidth) {
        val halfHeight = height / 2
        val halfWidth = width / 2

        while (halfHeight / inSampleSize >= reqHeight &&
               halfWidth / inSampleSize >= reqWidth) {
            inSampleSize *= 2
        }
    }
    return inSampleSize
}
```

### Coil Memory Cache Configuration

```kotlin
class MyApplication : Application(), ImageLoaderFactory {
    override fun newImageLoader(): ImageLoader {
        return ImageLoader.Builder(this)
            .memoryCache {
                MemoryCache.Builder()
                    .maxSizePercent(this, 0.20) // 20% of available memory
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(cacheDir.resolve("image_cache"))
                    .maxSizeBytes(100L * 1024 * 1024) // 100 MB
                    .build()
            }
            .crossfade(true)
            .build()
    }
}
```

## Reducing Object Allocation

### Object Pools for Frequently Created Objects

```kotlin
class RectPool(private val maxPoolSize: Int = 20) {
    private val pool = ArrayDeque<Rect>(maxPoolSize)

    fun acquire(): Rect = pool.removeFirstOrNull() ?: Rect()

    fun release(rect: Rect) {
        rect.setEmpty()
        if (pool.size < maxPoolSize) {
            pool.addLast(rect)
        }
    }
}

// Usage
val rectPool = RectPool()
val rect = rectPool.acquire()
try {
    canvas.getClipBounds(rect)
    // use rect
} finally {
    rectPool.release(rect)
}
```

### Avoid Allocations in Draw and Measure

```kotlin
// BAD: allocating Paint on every draw call
@Composable
fun CustomCanvas() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val paint = Paint().apply { color = Color.Red }  // allocation every frame
        drawRect(color = Color.Red)
    }
}

// GOOD: use the built-in DrawScope functions which reuse internal Paint objects
@Composable
fun CustomCanvas() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        drawRect(color = Color.Red)
    }
}
```

## Monitoring with Android Profiler

Open **Android Studio > View > Tool Windows > Profiler** and select your running process.

### Memory Profiler Workflow

1. **Capture a heap dump**: Click the heap dump icon to see all live objects, grouped by class.
2. **Record allocations**: Click record to track every allocation over a period. Look for high-frequency allocations in hot paths.
3. **Force GC**: Click the garbage can icon before taking a heap dump to remove soft/weak references.
4. **Compare heap dumps**: Take a dump before and after a user journey. Diff them to find objects that should have been freed.

### Key Indicators

- **Java/Kotlin heap** steadily climbing without plateauing = probable leak
- **Native heap** growing = Bitmap or NDK leak
- **Allocated objects** count high in a short period = allocation pressure causing GC pauses

## onTrimMemory Callbacks

Respond to system memory pressure to avoid being killed:

```kotlin
class MyApplication : Application() {
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        when (level) {
            TRIM_MEMORY_RUNNING_LOW -> {
                // App is running, system is low on memory
                // Clear non-critical caches
                imageLoader.memoryCache?.clear()
            }
            TRIM_MEMORY_UI_HIDDEN -> {
                // App's UI is no longer visible
                // Release UI-only resources
                clearPreviewCache()
            }
            TRIM_MEMORY_COMPLETE -> {
                // App is at the end of the LRU list, about to be killed
                // Release everything possible
                releaseAllCaches()
            }
        }
    }
}
```

In Compose, use `LifecycleEventEffect` to respond to trim events at the composable level:

```kotlin
@Composable
fun ImageGallery(imageCache: ImageCache) {
    val owner = LocalLifecycleOwner.current

    DisposableEffect(owner) {
        val callback = ComponentCallbacks2Impl { level ->
            if (level >= ComponentCallbacks2.TRIM_MEMORY_MODERATE) {
                imageCache.evictAll()
            }
        }
        owner.lifecycle.addObserver(callback)
        onDispose { owner.lifecycle.removeObserver(callback) }
    }
}
```

## Large Heap Considerations

You can request a large heap in the manifest:

```xml
<application android:largeHeap="true" ...>
```

**Do not use this as a fix for memory leaks.** It approximately doubles the available heap but also makes GC pauses longer. Only use it when your app genuinely needs to hold large datasets in memory (e.g., photo editors, mapping apps). Most apps should optimize memory usage instead.

Check available memory at runtime:

```kotlin
val activityManager = getSystemService<ActivityManager>()!!
val memoryInfo = ActivityManager.MemoryInfo()
activityManager.getMemoryInfo(memoryInfo)

val availableMemory = memoryInfo.availMem / (1024 * 1024) // MB
val totalMemory = memoryInfo.totalMem / (1024 * 1024)     // MB
val isLowMemory = memoryInfo.lowMemory
```
