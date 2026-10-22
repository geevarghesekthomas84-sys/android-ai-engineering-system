# CI/CD Testing Automation

## GitHub Actions Workflow

### Complete Android CI Pipeline

```yaml
# .github/workflows/android-ci.yml
name: Android CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
  checks: write
  pull-requests: write

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: "21"
          distribution: "temurin"

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4
        with:
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}

      - name: Run unit tests
        run: ./gradlew testDebugUnitTest --continue

      - name: Publish test results
        if: always()
        uses: EnricoMi/publish-unit-test-result-action@v2
        with:
          files: "**/build/test-results/testDebugUnitTest/*.xml"
          check_name: "Unit Test Results"

      - name: Upload test reports
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: unit-test-reports
          path: "**/build/reports/tests/testDebugUnitTest/"
          retention-days: 7

  lint-and-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: "21"
          distribution: "temurin"

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Run Android Lint
        run: ./gradlew lintDebug

      - name: Run detekt
        run: ./gradlew detekt

      - name: Run ktlint
        run: ./gradlew ktlintCheck

      - name: Upload lint results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lint-reports
          path: |
            **/build/reports/lint-results-debug.html
            **/build/reports/detekt/*.html
          retention-days: 7

  screenshot-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: "21"
          distribution: "temurin"

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Verify screenshot tests
        run: ./gradlew verifyRoborazziDebug

      - name: Upload screenshot diffs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: screenshot-diffs
          path: "**/build/outputs/roborazzi/"
          retention-days: 7

  instrumented-tests:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    strategy:
      fail-fast: false
      matrix:
        api-level: [30, 34]
        target: [google_apis]
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: "21"
          distribution: "temurin"

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm

      - name: AVD cache
        uses: actions/cache@v4
        id: avd-cache
        with:
          path: |
            ~/.android/avd/*
            ~/.android/adb*
          key: avd-${{ matrix.api-level }}-${{ matrix.target }}

      - name: Create AVD and generate snapshot
        if: steps.avd-cache.outputs.cache-hit != 'true'
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: ${{ matrix.api-level }}
          target: ${{ matrix.target }}
          arch: x86_64
          force-avd-creation: false
          emulator-options: -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim
          disable-animations: true
          script: echo "Generated AVD snapshot for caching."

      - name: Run instrumented tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: ${{ matrix.api-level }}
          target: ${{ matrix.target }}
          arch: x86_64
          force-avd-creation: false
          emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim
          disable-animations: true
          script: ./gradlew connectedDebugAndroidTest --continue

      - name: Publish instrumented test results
        if: always()
        uses: EnricoMi/publish-unit-test-result-action@v2
        with:
          files: "**/build/outputs/androidTest-results/connected/debug/*.xml"
          check_name: "Instrumented Tests (API ${{ matrix.api-level }})"

      - name: Upload test reports
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: instrumented-test-reports-api${{ matrix.api-level }}
          path: "**/build/reports/androidTests/connected/debug/"
          retention-days: 7

  coverage:
    needs: [unit-tests]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: "21"
          distribution: "temurin"

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Generate coverage report
        run: ./gradlew jacocoTestReport

      - name: Check coverage thresholds
        run: ./gradlew jacocoTestCoverageVerification

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: "**/build/reports/jacoco/"
          retention-days: 14
```

## JaCoCo Coverage Configuration

```kotlin
// build.gradle.kts (module-level)
plugins {
    id("jacoco")
}

jacoco {
    toolVersion = "0.8.12"
}

tasks.register<JacocoReport>("jacocoTestReport") {
    dependsOn("testDebugUnitTest")

    reports {
        xml.required.set(true)
        html.required.set(true)
        csv.required.set(false)
    }

    val mainSrc = "$projectDir/src/main/java"
    val kotlinClasses = fileTree("$buildDir/tmp/kotlin-classes/debug") {
        exclude(
            "**/R.class",
            "**/R$*.class",
            "**/BuildConfig.*",
            "**/*_Factory.*",
            "**/*_HiltModules*",
            "**/*Module_*.*",
            "**/*Hilt_*.*",
            "**/*_Impl*.*",
            "**/Hilt_*.*",
            "**/*ComposableSingletons*",
        )
    }

    sourceDirectories.setFrom(mainSrc)
    classDirectories.setFrom(kotlinClasses)
    executionData.setFrom(
        fileTree(buildDir) { include("jacoco/testDebugUnitTest.exec") }
    )
}

tasks.register<JacocoCoverageVerification>("jacocoTestCoverageVerification") {
    dependsOn("jacocoTestReport")

    violationRules {
        rule {
            limit {
                minimum = "0.70".toBigDecimal() // 70% line coverage minimum
            }
        }
        rule {
            element = "CLASS"
            excludes = listOf(
                "*.BuildConfig",
                "*.R",
                "*.*Module*",
                "*.di.*",
            )
            limit {
                counter = "BRANCH"
                minimum = "0.60".toBigDecimal()
            }
        }
    }

    sourceDirectories.setFrom("$projectDir/src/main/java")
    classDirectories.setFrom(
        fileTree("$buildDir/tmp/kotlin-classes/debug") {
            exclude("**/R.class", "**/R$*.class", "**/BuildConfig.*")
        }
    )
    executionData.setFrom(
        fileTree(buildDir) { include("jacoco/testDebugUnitTest.exec") }
    )
}
```

## Static Analysis Setup

### detekt

```kotlin
// build.gradle.kts (module-level)
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.7"
}

detekt {
    config.setFrom("$rootDir/config/detekt/detekt.yml")
    buildUponDefaultConfig = true
    parallel = true
}

dependencies {
    detektPlugins("io.gitlab.arturbosch.detekt:detekt-formatting:1.23.7")
    detektPlugins("io.gitlab.arturbosch.detekt:detekt-rules-libraries:1.23.7")
}
```

### ktlint via ktlint-gradle

```kotlin
// build.gradle.kts (project-level)
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.1.2"
}

// build.gradle.kts (module-level)
plugins {
    id("org.jlleitschuh.gradle.ktlint")
}

ktlint {
    version.set("1.5.0")
    android.set(true)
    reporters {
        reporter(org.jlleitschuh.gradle.ktlint.reporter.ReporterType.HTML)
        reporter(org.jlleitschuh.gradle.ktlint.reporter.ReporterType.SARIF)
    }
}
```

## Parallel Test Execution

```kotlin
// build.gradle.kts (module-level)
tasks.withType<Test> {
    maxParallelForks = (Runtime.getRuntime().availableProcessors() / 2).coerceAtLeast(1)
    forkEvery = 100 // restart worker after 100 tests (prevent memory leaks)
}
```

## Test Sharding on Multiple API Levels

For large test suites, shard across multiple emulators:

```yaml
# In the GitHub Actions matrix, split by test package
strategy:
  matrix:
    include:
      - api-level: 30
        shard: "com.example.app.feature.auth"
      - api-level: 30
        shard: "com.example.app.feature.home"
      - api-level: 34
        shard: "com.example.app.feature.auth"
      - api-level: 34
        shard: "com.example.app.feature.home"

# In the run step:
- name: Run sharded tests
  uses: reactivecircus/android-emulator-runner@v2
  with:
    api-level: ${{ matrix.api-level }}
    script: >
      ./gradlew connectedDebugAndroidTest
      -Pandroid.testInstrumentationRunnerArguments.package=${{ matrix.shard }}
```

## Gradle Caching

The `gradle/actions/setup-gradle@v4` action handles caching automatically. For additional control:

```yaml
- name: Setup Gradle
  uses: gradle/actions/setup-gradle@v4
  with:
    cache-read-only: ${{ github.ref != 'refs/heads/main' }}
    gradle-home-cache-includes: |
      caches
      notifications
      jdks
```

Keep `cache-read-only: true` on PRs so only main builds write to the cache, preventing cache poisoning.

## Local Testing Commands

```bash
# Run all checks locally (mirrors CI)
./gradlew check

# Run unit tests with coverage
./gradlew testDebugUnitTest jacocoTestReport

# Run lint + detekt + ktlint
./gradlew lintDebug detekt ktlintCheck

# Run connected tests on a specific device
adb devices
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.SmokeTest

# Run screenshot tests
./gradlew verifyRoborazziDebug

# Format code before committing
./gradlew ktlintFormat
```
