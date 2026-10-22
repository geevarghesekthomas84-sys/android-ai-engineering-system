# Project Scaffolding Reference

## Multi-Module Android Project Structure

### Recommended Module Layout

```
my-app/
  app/                          # Application module - wiring only
  feature/
    feature-home/               # Home screen feature
    feature-auth/               # Authentication flows
    feature-profile/            # User profile
    feature-orders/             # Order management
    feature-settings/           # App settings
  core/
    core-ui/                    # Shared Compose components, theme, design tokens
    core-network/               # Retrofit setup, interceptors, API result wrapper
    core-database/              # Room database, DAOs, entities
    core-data/                  # Repositories, data sources, mappers
    core-domain/                # Use cases, domain models, repository interfaces
    core-common/                # Utilities, extensions, constants
    core-testing/               # Shared test utilities, fakes, test fixtures
    core-datastore/             # DataStore preferences, proto definitions
  build-logic/
    convention/                 # Convention plugins for consistent build config
  gradle/
    libs.versions.toml          # Version catalog
```

### Module Dependency Rules

```
app -> feature-* -> core-domain -> (nothing)
                  -> core-ui     -> core-common
                  -> core-data   -> core-domain
                                 -> core-network
                                 -> core-database
                                 -> core-datastore
```

Key rules:
- **Feature modules never depend on other feature modules** - shared behavior goes in core
- **core-domain has zero Android dependencies** - pure Kotlin, testable without Robolectric
- **app module** only wires DI and navigation; no business logic
- **core-data** implements repository interfaces defined in core-domain

### Module build.gradle.kts (Feature Example)

```kotlin
plugins {
    id("myapp.android.feature")  // Convention plugin
}

android {
    namespace = "com.myapp.feature.orders"
}

dependencies {
    implementation(projects.core.coreDomain)
    implementation(projects.core.coreUi)
    implementation(projects.core.coreData)

    testImplementation(projects.core.coreTesting)
}
```

## Convention Plugins (build-logic)

Convention plugins eliminate duplication across modules.

### build-logic/convention/build.gradle.kts

```kotlin
plugins {
    `kotlin-dsl`
}

dependencies {
    compileOnly(libs.android.gradlePlugin)
    compileOnly(libs.kotlin.gradlePlugin)
    compileOnly(libs.compose.compiler.gradlePlugin)
    compileOnly(libs.ksp.gradlePlugin)
}

gradlePlugin {
    plugins {
        register("androidApplication") {
            id = "myapp.android.application"
            implementationClass = "AndroidApplicationConventionPlugin"
        }
        register("androidFeature") {
            id = "myapp.android.feature"
            implementationClass = "AndroidFeatureConventionPlugin"
        }
        register("androidLibrary") {
            id = "myapp.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidCompose") {
            id = "myapp.android.compose"
            implementationClass = "AndroidComposeConventionPlugin"
        }
        register("jvmLibrary") {
            id = "myapp.jvm.library"
            implementationClass = "JvmLibraryConventionPlugin"
        }
        register("androidHilt") {
            id = "myapp.android.hilt"
            implementationClass = "AndroidHiltConventionPlugin"
        }
    }
}
```

### Android Library Convention Plugin

```kotlin
import com.android.build.gradle.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure

class AndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("com.android.library")
        pluginManager.apply("org.jetbrains.kotlin.android")

        extensions.configure<LibraryExtension> {
            compileSdk = 35
            defaultConfig {
                minSdk = 26
                testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
                isCoreLibraryDesugaringEnabled = true
            }
            buildFeatures {
                buildConfig = false
            }
        }

        dependencies.add("coreLibraryDesugaring", libs.findLibrary("desugar.jdk.libs").get())
        dependencies.add("testImplementation", libs.findLibrary("junit").get())
        dependencies.add("testImplementation", libs.findLibrary("kotlinx.coroutines.test").get())
    }
}
```

### Feature Convention Plugin

```kotlin
class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("myapp.android.library")
        pluginManager.apply("myapp.android.compose")
        pluginManager.apply("myapp.android.hilt")

        dependencies.add("implementation", libs.findLibrary("androidx.lifecycle.viewmodel.compose").get())
        dependencies.add("implementation", libs.findLibrary("androidx.lifecycle.runtime.compose").get())
        dependencies.add("implementation", libs.findLibrary("androidx.navigation.compose").get())
        dependencies.add("implementation", libs.findLibrary("androidx.hilt.navigation.compose").get())
    }
}
```

## Version Catalog (libs.versions.toml)

```toml
[versions]
agp = "8.7.3"
kotlin = "2.1.0"
ksp = "2.1.0-1.0.29"
compose-bom = "2024.12.01"
compose-compiler = "1.5.15"
hilt = "2.53.1"
room = "2.6.1"
retrofit = "2.11.0"
okhttp = "4.12.0"
coroutines = "1.9.0"
lifecycle = "2.8.7"
navigation = "2.8.5"
kotlinx-serialization = "1.7.3"
coil = "2.7.0"
timber = "5.0.1"
desugar = "2.1.4"

# Testing
junit = "4.13.2"
junit5 = "5.11.4"
turbine = "1.2.0"
mockk = "1.13.13"
truth = "1.4.4"

[libraries]
# AndroidX Compose
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-runtime = { group = "androidx.compose.runtime", name = "runtime" }

# Lifecycle
androidx-lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }
androidx-lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }

# Navigation
androidx-navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation" }
androidx-hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.2.0" }

# Hilt
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-compiler", version.ref = "hilt" }

# Room
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }

# Network
retrofit = { group = "com.squareup.retrofit2", name = "retrofit", version.ref = "retrofit" }
retrofit-kotlinx-serialization = { group = "com.squareup.retrofit2", name = "converter-kotlinx-serialization", version.ref = "retrofit" }
okhttp = { group = "com.squareup.okhttp3", name = "okhttp", version.ref = "okhttp" }
okhttp-logging = { group = "com.squareup.okhttp3", name = "logging-interceptor", version.ref = "okhttp" }

# Serialization
kotlinx-serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "kotlinx-serialization" }

# Coroutines
kotlinx-coroutines-core = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-core", version.ref = "coroutines" }
kotlinx-coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }
kotlinx-coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutines" }

# Misc
coil-compose = { group = "io.coil-kt", name = "coil-compose", version.ref = "coil" }
timber = { group = "com.jakewharton.timber", name = "timber", version.ref = "timber" }
desugar-jdk-libs = { group = "com.android.tools", name = "desugar_jdk_libs", version.ref = "desugar" }

# Testing
junit = { group = "junit", name = "junit", version.ref = "junit" }
turbine = { group = "app.cash.turbine", name = "turbine", version.ref = "turbine" }
mockk = { group = "io.mockk", name = "mockk", version.ref = "mockk" }
truth = { group = "com.google.truth", name = "truth", version.ref = "truth" }

# Build logic dependencies
android-gradlePlugin = { group = "com.android.tools.build", name = "gradle", version.ref = "agp" }
kotlin-gradlePlugin = { group = "org.jetbrains.kotlin", name = "kotlin-gradle-plugin", version.ref = "kotlin" }
compose-compiler-gradlePlugin = { group = "org.jetbrains.kotlin", name = "compose-compiler-gradle-plugin", version.ref = "kotlin" }
ksp-gradlePlugin = { group = "com.google.devtools.ksp", name = "com.google.devtools.ksp.gradle.plugin", version.ref = "ksp" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
room = { id = "androidx.room", version.ref = "room" }
```

## CI Template (GitHub Actions)

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
      - name: Run lint
        run: ./gradlew lintDebug

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
      - name: Run unit tests
        run: ./gradlew testDebugUnitTest
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: "**/build/reports/tests/"

  build:
    runs-on: ubuntu-latest
    needs: [lint, unit-tests]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
      - name: Build debug APK
        run: ./gradlew assembleDebug
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk

  instrumented-tests:
    runs-on: ubuntu-latest
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - name: Run instrumented tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          arch: x86_64
          script: ./gradlew connectedDebugAndroidTest
```

### .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
        run: echo "$KEYSTORE_BASE64" | base64 -d > app/release.keystore

      - name: Build release bundle
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: ./gradlew bundleRelease

      - name: Upload AAB
        uses: actions/upload-artifact@v4
        with:
          name: release-aab
          path: app/build/outputs/bundle/release/app-release.aab
```

## Project Init Checklist

When scaffolding a new project:

1. **Create settings.gradle.kts** with `enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")` and include all modules
2. **Set up build-logic** with convention plugins before adding modules
3. **Create version catalog** with all dependencies pinned
4. **Add .editorconfig** for consistent formatting (indent = 4 spaces, max line = 120)
5. **Add .gitignore** covering `build/`, `.gradle/`, `*.apk`, `*.aab`, `local.properties`, `.idea/`, `*.jks`
6. **Add detekt or ktlint** configuration for static analysis
7. **Add pre-commit hook** running `./gradlew lintDebug testDebugUnitTest`
8. **Configure ProGuard/R8** rules per module in `proguard-rules.pro`
9. **Set up signing configs** using environment variables, not hardcoded values
10. **Create core modules first**, then feature modules that depend on them
