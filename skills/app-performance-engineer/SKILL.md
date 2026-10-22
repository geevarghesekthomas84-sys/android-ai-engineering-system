---
name: app-performance-engineer
description: Android app performance optimization covering startup, Compose rendering, memory, network, battery, APK size, and benchmarking
metadata:
  author: Custom
  keywords:
  - performance
  - optimization
  - benchmark
  - compose-performance
  - startup
  - memory
  - apk-size
  - profiling
---

# App Performance Engineer

## Trigger Conditions

Activate this skill when the user describes or asks about any of the following:

- **Slow app startup** -- cold start exceeds 500ms, warm start exceeds 300ms, or splash screen lingers
- **UI jank** -- dropped frames, stuttering scrolls, animation hitches, recomposition storms in Compose
- **Large APK** -- release APK or AAB exceeds target size, user or Play Console flags download size
- **Memory issues** -- OOM crashes, high memory warnings, suspected leaks, GC pressure
- **Battery drain** -- background wake locks, excessive network polling, users reporting battery consumption
- **Startup time** -- need to measure, profile, or reduce time-to-first-frame or time-to-interactive
- **Benchmark setup** -- setting up Macrobenchmark, Microbenchmark, Baseline Profiles, or CI performance gates

## Capabilities

### 1. Startup Optimization
Measure and reduce cold, warm, and hot start times using App Startup library, lazy initialization, background thread scheduling, Baseline Profiles, and splash screen API. Reference: `references/startup-optimization.md`

### 2. Compose Rendering Performance
Eliminate recomposition waste through stability annotations, `derivedStateOf`, correct `remember` usage, efficient `LazyColumn` configuration, and Compose compiler metrics. Reference: `references/compose-performance.md`

### 3. Memory Optimization
Detect and fix memory leaks with LeakCanary, optimize Bitmap handling with Coil, reduce allocation pressure, and respond to system trim callbacks. Reference: `references/memory-optimization.md`

### 4. Network and Battery Efficiency
Batch and compress network calls, configure Coil disk caching, schedule deferrable work with WorkManager, respect Doze mode, and minimize wake locks. Reference: `references/network-battery.md`

### 5. APK Size Reduction
Configure R8 for aggressive shrinking, enable resource shrinking, split by density, analyze with APK Analyzer, convert rasters to WebP and vector drawables, and trim unused Material Icons. Reference: `references/apk-size.md`

### 6. Benchmarking and Baseline Profiles
Write Macrobenchmark tests for startup and scroll, Microbenchmark tests for hot code paths, generate and install Baseline Profiles, read results, and integrate into CI. Reference: `references/benchmarking.md`

### 7. Profiling with Android Studio
Use CPU Profiler for method traces, Memory Profiler for allocation tracking, Network Profiler for request timing, Energy Profiler for battery impact, Layout Inspector for recomposition counts, and Perfetto for system traces.

## Performance Workflow

Every optimization follows this cycle:

```
1. MEASURE BASELINE
   Capture current metric with a reproducible benchmark or profiler trace.

2. IDENTIFY BOTTLENECK
   Analyze traces (Perfetto, CPU Profiler) or metrics (Macrobenchmark JSON)
   to find the single largest contributor to the problem.

3. IMPLEMENT FIX
   Apply the targeted optimization. Change one thing at a time.

4. MEASURE AGAIN
   Re-run the exact same benchmark or trace under the same conditions.

5. COMPARE
   Confirm the metric improved. If not, revert and try another approach.
```

Never ship a "performance improvement" without before-and-after numbers.

## Key Metrics and Targets

| Metric | Good | Needs Work | Poor |
|---|---|---|---|
| Cold start (time-to-initial-display) | < 500ms | 500ms - 1s | > 1s |
| Warm start | < 300ms | 300ms - 700ms | > 700ms |
| Hot start | < 150ms | 150ms - 300ms | > 300ms |
| Frame render time | < 16ms (60fps) | 16ms - 32ms | > 32ms |
| Frame render time (90Hz) | < 11ms | 11ms - 22ms | > 22ms |
| Memory footprint (typical app) | < 100MB | 100MB - 200MB | > 200MB |
| APK size (single density) | < 10MB | 10MB - 30MB | > 30MB |
| AAB download size | < 15MB | 15MB - 50MB | > 50MB |

## Rule

**Always measure before and after optimization.** Intuition about performance is unreliable. Profile-driven optimization is the only kind that consistently delivers real improvements. A change that looks faster in code review but has no benchmark data is not a performance improvement -- it is a code change with unknown performance impact.

## Tool Versions (Current Environment)

- Android CLI: 1.0.16625370
- JDK: 21
- Kotlin: 2.3.20
- Jetpack Compose BOM: 2026.03.01
- Material 3
- AGP: 9.0.1

## Quick Reference: Common Commands

```bash
# Run Macrobenchmark tests
./gradlew :benchmark:connectedBenchmarkAndroidTest

# Generate Baseline Profiles
./gradlew :app:generateBaselineProfile

# Analyze APK size
# Use Android Studio > Build > Analyze APK, or:
./gradlew :app:assembleRelease
# Then open build/outputs/apk/release/*.apk in APK Analyzer

# Check Compose compiler stability reports
# After enabling reportsDestination in build.gradle.kts:
# Reports appear in build/compose_metrics/

# Run Microbenchmark tests
./gradlew :microbenchmark:connectedAndroidTest
```
