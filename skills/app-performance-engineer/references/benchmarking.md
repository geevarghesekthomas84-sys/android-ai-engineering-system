# Benchmarking

## Macrobenchmark

Macrobenchmark measures app-level performance from an instrumentation test APK running on a real device. It launches your app as a user would and captures system-level metrics.

### Module Setup

Create a `benchmark` module (type `com.android.test`):

```kotlin
// benchmark/build.gradle.kts
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

    buildTypes {
        create("benchmark") {
            isDebuggable = true
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
        }
    }
}

dependencies {
    implementation("androidx.benchmark:benchmark-macro-junit4:1.3.3")
    implementation("androidx.test.ext:junit:1.2.1")
    implementation("androidx.test.espresso:espresso-core:3.6.1")
    implementation("androidx.test.uiautomator:uiautomator:2.3.0")
}

androidComponents {
    beforeVariants(selector().all()) {
        it.enable = it.buildType == "benchmark"
    }
}
```

Add the benchmark build type to the app module:

```kotlin
// app/build.gradle.kts
android {
    buildTypes {
        create("benchmark") {
            initWith(getByName("release"))
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
            isDebuggable = false
            // Ensure Baseline Profiles are used
            proguardFiles("benchmark-rules.pro")
        }
    }
}
```

### Startup Benchmark

```kotlin
@LargeTest
@RunWith(AndroidJUnit4::class)
class StartupBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun startupCompilationNone() = startup(CompilationMode.None())

    @Test
    fun startupCompilationPartial() = startup(
        CompilationMode.Partial(
            baselineProfileMode = BaselineProfileMode.Require
        )
    )

    @Test
    fun startupCompilationFull() = startup(CompilationMode.Full())

    private fun startup(compilationMode: CompilationMode) {
        benchmarkRule.measureRepeated(
            packageName = "com.example.app",
            metrics = listOf(StartupTimingMetric()),
            iterations = 10,
            startupMode = StartupMode.COLD,
            compilationMode = compilationMode,
        ) {
            pressHome()
            startActivityAndWait()
        }
    }
}
```

### Scroll Benchmark

```kotlin
@LargeTest
@RunWith(AndroidJUnit4::class)
class ScrollBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun scrollFeed() = benchmarkRule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(FrameTimingMetric()),
        iterations = 5,
        startupMode = StartupMode.WARM,
        compilationMode = CompilationMode.Partial(
            baselineProfileMode = BaselineProfileMode.Require
        ),
    ) {
        pressHome()
        startActivityAndWait()

        val feedList = device.findObject(By.res("com.example.app", "feed_list"))
        feedList.setGestureMargin(device.displayWidth / 5)

        repeat(3) {
            feedList.scroll(Direction.DOWN, 2f)
            device.waitForIdle()
        }
    }
}
```

### Animation Benchmark

```kotlin
@LargeTest
@RunWith(AndroidJUnit4::class)
class AnimationBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun navigationTransition() = benchmarkRule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(FrameTimingMetric()),
        iterations = 5,
        startupMode = StartupMode.WARM,
        compilationMode = CompilationMode.DEFAULT,
    ) {
        pressHome()
        startActivityAndWait()

        // Trigger navigation that includes animation
        val item = device.findObject(By.text("Item 1"))
        item.click()
        device.waitForIdle()

        // Navigate back
        device.pressBack()
        device.waitForIdle()
    }
}
```

### CompilationMode Options

| Mode | What It Does | When to Use |
|---|---|---|
| `CompilationMode.None()` | Clears all compilation. Fully interpreted/JIT. | Worst-case baseline |
| `CompilationMode.Partial(baselineProfileMode = Require)` | Applies only Baseline Profile AOT | Realistic first-launch after install |
| `CompilationMode.Full()` | AOT-compiles everything | Best-case (after days of use) |
| `CompilationMode.DEFAULT` | Does not change compilation state | Quick iteration during development |

### StartupMode Options

| Mode | Effect |
|---|---|
| `StartupMode.COLD` | Kills the process, then starts fresh |
| `StartupMode.WARM` | Keeps the process, finishes the activity, then restarts it |
| `StartupMode.HOT` | Keeps the process and activity, brings to foreground |

## Microbenchmark

Microbenchmark measures CPU performance of individual functions or code blocks. It runs in-process and is suited for hot code paths like data transformations, sorting, and serialization.

### Module Setup

```kotlin
// microbenchmark/build.gradle.kts
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("androidx.benchmark")
}

android {
    namespace = "com.example.microbenchmark"
    compileSdk = 35

    defaultConfig {
        minSdk = 28
        testInstrumentationRunner = "androidx.benchmark.junit4.AndroidBenchmarkRunner"
    }

    testBuildType = "release"

    buildTypes {
        release {
            isDefault = true
        }
    }
}

dependencies {
    androidTestImplementation("androidx.benchmark:benchmark-junit4:1.3.3")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
```

### Writing a Microbenchmark

```kotlin
@RunWith(AndroidJUnit4::class)
class JsonParsingBenchmark {

    @get:Rule
    val benchmarkRule = BenchmarkRule()

    private val sampleJson = """
        {"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]}
    """.trimIndent()

    @Test
    fun parseWithKotlinxSerialization() {
        benchmarkRule.measureRepeated {
            val result = runWithTimingDisabled {
                sampleJson.encodeToByteArray()
            }
            Json.decodeFromString<UserResponse>(String(result))
        }
    }

    @Test
    fun parseWithManualParsing() {
        benchmarkRule.measureRepeated {
            val parser = runWithTimingDisabled {
                JSONObject(sampleJson)
            }
            parseManually(parser)
        }
    }
}
```

Use `runWithTimingDisabled` to exclude setup code from the measurement.

## Baseline Profiles

Baseline Profiles pre-compile critical code paths at install time, reducing cold start time and eliminating JIT compilation jank during first use.

### BaselineProfileRule

```kotlin
@LargeTest
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {

    @get:Rule
    val rule = BaselineProfileRule()

    @Test
    fun generateProfile() = rule.collect(
        packageName = "com.example.app",
        includeInStartupProfile = true,
        stableIterations = 3,
        maxIterations = 10,
    ) {
        // Startup path
        pressHome()
        startActivityAndWait()

        // Critical user journey: browse feed
        device.findObject(By.res("feed_list"))
            .scroll(Direction.DOWN, 3f)
        device.waitForIdle()

        // Critical user journey: open detail
        device.findObject(By.text("Item 1")).click()
        device.waitForIdle()
        device.pressBack()
        device.waitForIdle()

        // Critical user journey: search
        device.findObject(By.res("search_button")).click()
        device.waitForIdle()
        device.findObject(By.res("search_field")).text = "query"
        device.waitForIdle()
    }
}
```

### build.gradle.kts Configuration

```kotlin
// app/build.gradle.kts
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
    // Generate during build and commit to source control
    automaticGenerationDuringBuild = true
    saveInSrc = true
    // Filter to include only your app's packages
    filter {
        include("com.example.app.**")
    }
}
```

### Running Generation

```bash
# Generate profiles
./gradlew :app:generateBaselineProfile

# Output file: app/src/main/baseline-prof.txt
# Startup profile: app/src/main/startup-prof.txt
```

The generated text files contain method and class rules:

```
HSPLcom/example/app/MainActivity;->onCreate(Landroid/os/Bundle;)V
PLcom/example/app/data/Repository;->getItems()Ljava/util/List;
```

- `H` = hot (frequently executed)
- `S` = startup
- `P` = post-startup
- `L` = end of method signature

## Reading Benchmark Results

Macrobenchmark outputs JSON results to the device and pulls them to `benchmark/build/outputs/`:

```json
{
    "benchmarks": [{
        "name": "startupCold",
        "className": "com.example.benchmark.StartupBenchmark",
        "metrics": {
            "timeToInitialDisplayMs": {
                "minimum": 234.5,
                "maximum": 312.1,
                "median": 267.8,
                "runs": [234.5, 245.2, 267.8, 289.4, 312.1]
            }
        }
    }]
}
```

Key metrics to track:

- **timeToInitialDisplayMs** -- time from intent to first frame drawn (TTID)
- **timeToFullDisplayMs** -- time from intent to `reportFullyDrawn()` call (TTFD)
- **frameDurationCpuMs** -- CPU time per frame during scroll/animation
- **frameOverrunMs** -- how much each frame exceeded the deadline (negative = within budget)

## CI Integration for Performance Regression Detection

### GitHub Actions Example

```yaml
name: Performance Benchmarks

on:
  pull_request:
    branches: [main]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Accept Android SDK Licenses
        run: yes | sdkmanager --licenses || true

      - name: Run benchmarks on Firebase Test Lab
        run: |
          ./gradlew :benchmark:assembleBenchmark :app:assembleBenchmark
          gcloud firebase test android run \
            --type instrumentation \
            --app app/build/outputs/apk/benchmark/app-benchmark.apk \
            --test benchmark/build/outputs/apk/benchmark/benchmark-benchmark.apk \
            --device model=oriole,version=33 \
            --results-dir=benchmark-results \
            --no-performance-metrics

      - name: Parse and compare results
        run: |
          python scripts/compare_benchmarks.py \
            --baseline benchmarks/baseline.json \
            --current benchmark-results/latest.json \
            --threshold 10  # fail if >10% regression
```

### Tracking Metrics Over Time

Store benchmark results in a database or file alongside your code:

```bash
# After each benchmark run on main, commit the results
cp benchmark/build/outputs/connected_android_test_additional_output/benchmark/*.json \
   benchmarks/latest.json
```

Set regression thresholds:
- **Startup time**: fail if median cold start increases by more than 50ms or 10%
- **Frame timing**: fail if P95 frame duration exceeds 16ms
- **APK size**: fail if release APK grows by more than 500KB

Automate with a comparison script that reads the JSON results and exits non-zero on regression.
