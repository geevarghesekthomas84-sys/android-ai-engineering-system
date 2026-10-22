# Startup Optimization

## Startup Types

Android defines three startup types, each measured from a different starting state:

- **Cold start**: Process not running. The system forks a new process, creates the Application object, inflates the activity, and draws the first frame. This is the slowest path and the one users notice most.
- **Warm start**: Process exists but the activity was destroyed. The system recreates the activity without re-initializing the Application.
- **Hot start**: Process and activity exist in memory. The system brings the activity to the foreground. Fastest path.

## Measuring Startup with Macrobenchmark

The Macrobenchmark library runs on a real device from a separate test module, providing production-accurate timing.

### Setup

Add the benchmark module to `settings.gradle.kts`:

```kotlin
include(":benchmark")
```

In `benchmark/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.test")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.benchmark"
    compileSdk = 35

    defaultConfig {
        minSdk = 28
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    targetProjectPath = ":app"
    experimentalProperties["android.experimental.self-instrumenting"] = true
}

dependencies {
    implementation("androidx.benchmark:benchmark-macro-junit4:1.3.3")
    implementation("androidx.test.ext:junit:1.2.1")
    implementation("androidx.test.espresso:espresso-core:3.6.1")
}

androidComponents {
    beforeVariants(selector().all()) {
        it.enable = it.buildType == "benchmark"
    }
}
```

### Startup Benchmark Test

```kotlin
@LargeTest
@RunWith(AndroidJUnit4::class)
class StartupBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun startupCold() = benchmarkRule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.COLD,
        compilationMode = CompilationMode.DEFAULT,
    ) {
        pressHome()
        startActivityAndWait()
    }

    @Test
    fun startupWarm() = benchmarkRule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.WARM,
        compilationMode = CompilationMode.DEFAULT,
    ) {
        pressHome()
        startActivityAndWait()
    }

    @Test
    fun startupHot() = benchmarkRule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.HOT,
        compilationMode = CompilationMode.DEFAULT,
    ) {
        pressHome()
        startActivityAndWait()
    }
}
```

## App Startup Library

The `androidx.startup` library replaces scattered `ContentProvider` initializations with a single, ordered initializer system.

### Dependency

```kotlin
implementation("androidx.startup:startup-runtime:1.2.0")
```

### Creating an Initializer

```kotlin
class TimberInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}

class AnalyticsInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        Analytics.init(context)
    }

    // Analytics depends on Timber being initialized first
    override fun dependencies(): List<Class<out Initializer<*>>> =
        listOf(TimberInitializer::class.java)
}
```

### Registering in AndroidManifest.xml

```xml
<provider
    android:name="androidx.startup.InitializationProvider"
    android:authorities="${applicationId}.androidx-startup"
    android:exported="false"
    tools:node="merge">
    <meta-data
        android:name="com.example.app.AnalyticsInitializer"
        android:value="androidx.startup" />
    <!-- TimberInitializer is discovered automatically via dependencies() -->
</provider>
```

### Lazy Initialization

Defer initializers that are not needed at startup:

```xml
<!-- Disable automatic initialization -->
<provider
    android:name="androidx.startup.InitializationProvider"
    android:authorities="${applicationId}.androidx-startup"
    android:exported="false"
    tools:node="merge">
    <meta-data
        android:name="com.example.app.HeavyInitializer"
        android:value="androidx.startup"
        tools:node="remove" />
</provider>
```

Then initialize manually when needed:

```kotlin
AppInitializer.getInstance(context)
    .initializeComponent(HeavyInitializer::class.java)
```

## Background Initialization

Move heavy work off the main thread during Application.onCreate:

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Critical path only -- keep this minimal
        StrictMode.enableDefaults()

        // Move non-critical init to background
        val executor = Executors.newFixedThreadPool(2)
        executor.execute { initializeDatabase() }
        executor.execute { preloadFonts() }
        // Do NOT block on these futures during onCreate
    }
}
```

## Avoiding Heavy Application.onCreate Work

Common offenders that slow cold start:

1. **Network library initialization** -- Retrofit/OkHttp client creation is cheap; do it lazily via Dagger/Hilt `@Singleton` providers.
2. **Database creation** -- Room database `.build()` is fast, but pre-populating or migrating is not. Defer migrations to first query.
3. **Analytics SDKs** -- Many call home on init. Use App Startup with lazy init.
4. **Image loader setup** -- Coil's `ImageLoader` can be set up lazily via `ImageLoaderFactory`.
5. **Crash reporters** -- Firebase Crashlytics init is fast, but custom crash handlers may not be.

## Baseline Profiles

Baseline Profiles tell ART which methods and classes to pre-compile at install time, reducing cold start JIT overhead.

### Generating with Macrobenchmark

```kotlin
@LargeTest
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {

    @get:Rule
    val rule = BaselineProfileRule()

    @Test
    fun generateBaselineProfile() = rule.collect(
        packageName = "com.example.app",
        includeInStartupProfile = true,
    ) {
        pressHome()
        startActivityAndWait()

        // Exercise critical user journeys
        device.findObject(By.text("Home")).click()
        device.waitForIdle()
        device.findObject(By.res("feed_list")).scroll(Direction.DOWN, 2f)
    }
}
```

### Installing in build.gradle.kts

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("androidx.baselineprofile")
}

dependencies {
    implementation("androidx.profileinstaller:profileinstaller:1.4.1")
    baselineProfile(project(":benchmark"))
}

baselineProfile {
    automaticGenerationDuringBuild = true
    saveInSrc = true
}
```

The generated profile lands in `src/main/baseline-prof.txt`.

## Splash Screen API

Use the `androidx.core.splashscreen` library to control the splash screen without adding startup latency:

```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()

        // Keep splash visible while loading critical data
        var isReady = false
        splashScreen.setKeepOnScreenCondition { !isReady }

        super.onCreate(savedInstanceState)

        lifecycleScope.launch {
            // Load essential data
            viewModel.uiState.first { it is UiState.Ready }
            isReady = true
        }

        setContent { MyApp() }
    }
}
```

## ContentProvider Optimization

Each `ContentProvider` in the manifest adds to startup time because the system instantiates them all before `Application.onCreate`. Audit and remove unnecessary ones:

```bash
# List all ContentProviders in the merged manifest
# Check app/build/intermediates/merged_manifests/release/AndroidManifest.xml
# Search for <provider> tags
```

Replace library-contributed ContentProviders with App Startup initializers where the library supports it (e.g., WorkManager, Firebase).

## Tracing with Perfetto

Add custom trace sections to pinpoint slow startup code:

```kotlin
import android.os.Trace

class MyApplication : Application() {
    override fun onCreate() {
        Trace.beginSection("MyApp.onCreate")
        super.onCreate()

        Trace.beginSection("initDependencyInjection")
        initHilt()
        Trace.endSection()

        Trace.beginSection("initCriticalServices")
        initCriticalServices()
        Trace.endSection()

        Trace.endSection() // MyApp.onCreate
    }
}
```

Capture a Perfetto trace during cold start:

```bash
# Record a system trace (on device with developer options enabled)
adb shell perfetto -o /data/misc/perfetto-traces/trace.perfetto-trace -t 10s \
  sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory

# Pull and open in ui.perfetto.dev
adb pull /data/misc/perfetto-traces/trace.perfetto-trace .
```

In the Perfetto UI, filter to your process and look for long slices in the main thread between `bindApplication` and the first `Choreographer#doFrame`.
