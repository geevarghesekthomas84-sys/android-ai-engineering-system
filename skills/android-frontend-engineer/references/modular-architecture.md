# Multi-Module Android Architecture

## Module Structure

```
project-root/
├── app/                          # Application module — wires everything together
├── core/
│   ├── data/                     # Repositories, data sources, DTOs, mappers
│   ├── domain/                   # Domain models, use cases, repository interfaces
│   ├── ui/                       # Shared Compose components, theme, design system
│   ├── network/                  # Retrofit setup, interceptors, API result types
│   ├── database/                 # Room database, DAOs, entities
│   └── common/                   # Utilities, extensions, constants
├── feature/
│   ├── home/                     # Home screen feature
│   ├── tasks/                    # Task list and detail screens
│   ├── auth/                     # Login, registration, password reset
│   ├── profile/                  # User profile and settings
│   └── onboarding/               # First-run experience
└── build-logic/
    └── convention/               # Shared build configuration plugins
```

## Module Dependencies

```
app → feature:home, feature:tasks, feature:auth, feature:profile, feature:onboarding
feature:home → core:domain, core:ui
feature:tasks → core:domain, core:ui
feature:auth → core:domain, core:ui
core:data → core:domain, core:network, core:database
core:network → core:common
core:database → core:common
core:domain → core:common (models only, no Android deps)
core:ui → core:common (Compose, no business logic)
```

Key rules:
- Feature modules never depend on other feature modules.
- Feature modules depend on `core:domain` (interfaces, models) and `core:ui` (shared components), never on `core:data` directly.
- `core:domain` is pure Kotlin — no Android framework dependencies.
- `app` module is the only module that depends on `core:data` (to provide Hilt bindings).

## settings.gradle.kts

```kotlin
pluginManagement {
    includeBuild("build-logic")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "MyApp"

include(":app")
include(":core:common")
include(":core:data")
include(":core:domain")
include(":core:ui")
include(":core:network")
include(":core:database")
include(":feature:home")
include(":feature:tasks")
include(":feature:auth")
include(":feature:profile")
include(":feature:onboarding")
```

## Convention Plugins (build-logic)

Eliminate duplicate build configuration across modules.

### build-logic/convention/build.gradle.kts

```kotlin
plugins {
    `kotlin-dsl`
}

dependencies {
    compileOnly("com.android.tools.build:gradle:9.0.1")
    compileOnly("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.20")
    compileOnly("com.google.devtools.ksp:symbol-processing-gradle-plugin:2.3.20-1.0.31")
}
```

### Android Library Convention Plugin

```kotlin
// build-logic/convention/src/main/kotlin/AndroidLibraryConventionPlugin.kt
import com.android.build.gradle.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure

class AndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("com.android.library")
            pluginManager.apply("org.jetbrains.kotlin.android")

            extensions.configure<LibraryExtension> {
                compileSdk = 36
                defaultConfig {
                    minSdk = 26
                    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
                }
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_21
                    targetCompatibility = JavaVersion.VERSION_21
                }
            }
        }
    }
}
```

### Compose Convention Plugin

```kotlin
// build-logic/convention/src/main/kotlin/ComposeConventionPlugin.kt
class ComposeConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            pluginManager.apply("org.jetbrains.kotlin.plugin.compose")

            extensions.configure<LibraryExtension> {
                buildFeatures {
                    compose = true
                }
            }

            dependencies {
                val bom = platform("androidx.compose:compose-bom:2026.03.01")
                add("implementation", bom)
                add("implementation", "androidx.compose.material3:material3")
                add("implementation", "androidx.compose.ui:ui-tooling-preview")
                add("debugImplementation", "androidx.compose.ui:ui-tooling")
                add("implementation", "androidx.lifecycle:lifecycle-runtime-compose:2.9.1")
            }
        }
    }
}
```

### Register in build-logic/convention/build.gradle.kts

```kotlin
gradlePlugin {
    plugins {
        register("androidLibrary") {
            id = "myapp.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidCompose") {
            id = "myapp.android.compose"
            implementationClass = "ComposeConventionPlugin"
        }
        register("androidHilt") {
            id = "myapp.android.hilt"
            implementationClass = "HiltConventionPlugin"
        }
    }
}
```

### Usage in Feature Modules

```kotlin
// feature/tasks/build.gradle.kts
plugins {
    id("myapp.android.library")
    id("myapp.android.compose")
    id("myapp.android.hilt")
    alias(libs.plugins.kotlin.serialization)
}

dependencies {
    implementation(project(":core:domain"))
    implementation(project(":core:ui"))
}
```

## API vs Implementation Dependencies

```kotlin
// core/data/build.gradle.kts
plugins {
    id("myapp.android.library")
    id("myapp.android.hilt")
}

dependencies {
    // Exposed to consumers via api — they can see domain models
    api(project(":core:domain"))

    // Hidden from consumers — implementation detail
    implementation(project(":core:network"))
    implementation(project(":core:database"))
}
```

- Use `api` when consumers need the transitive dependency (domain models, interfaces).
- Use `implementation` for internal details (Retrofit, Room). This speeds up builds because changes in implementation dependencies do not recompile consumers.

## Navigation Across Modules

Feature modules define their own NavKeys. The `app` module wires them into the global `entryProvider`.

```kotlin
// feature/tasks/src/.../navigation/TaskNavKeys.kt
@Serializable
data object TaskListKey : NavKey

@Serializable
data class TaskDetailKey(val taskId: String) : NavKey

// feature/tasks/src/.../navigation/TaskNavEntries.kt
fun EntryProviderBuilder.taskEntries(
    backStack: NavBackStack,
    onNavigateToProfile: (String) -> Unit,
) {
    entry<TaskListKey> { key ->
        TaskListScreen(
            onNavigateToDetail = { backStack.add(TaskDetailKey(it)) },
            onNavigateToProfile = onNavigateToProfile,
        )
    }
    entry<TaskDetailKey> { key ->
        TaskDetailScreen(
            taskId = key.taskId,
            onNavigateBack = { backStack.removeLastOrNull() },
        )
    }
}
```

```kotlin
// app/src/.../AppNavigation.kt
@Composable
fun AppNavigation() {
    val backStack = rememberNavBackStack(HomeKey)

    NavDisplay(
        backStack = backStack,
        entryProvider = entryProvider {
            homeEntries(backStack)
            taskEntries(backStack, onNavigateToProfile = { backStack.add(ProfileKey(it)) })
            authEntries(backStack)
            profileEntries(backStack)
        },
    )
}
```

## Dependency Injection Across Modules

Each module provides its own Hilt `@Module`. The `app` module's Hilt component aggregates them all at compile time.

```kotlin
// core/data/src/.../di/DataModule.kt
@Module
@InstallIn(SingletonComponent::class)
abstract class DataModule {
    @Binds
    @Singleton
    abstract fun bindTaskRepository(impl: TaskRepositoryImpl): TaskRepository

    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}

// core/network/src/.../di/NetworkModule.kt
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit = /* ... */
}

// core/database/src/.../di/DatabaseModule.kt
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase = /* ... */
}
```

The `app` module depends on all modules, so Hilt sees every `@Module` and builds the complete dependency graph.

## Version Catalog (gradle/libs.versions.toml)

Centralize dependency versions across all modules.

```toml
[versions]
agp = "9.0.1"
kotlin = "2.3.20"
ksp = "2.3.20-1.0.31"
compose-bom = "2026.03.01"
navigation3 = "1.0.1"
hilt = "2.56.2"
lifecycle = "2.9.1"
room = "2.7.1"
retrofit = "2.11.0"
okhttp = "4.12.0"
coil = "3.2.0"
serialization = "1.8.1"
coroutines = "1.10.2"
work = "2.10.1"

[libraries]
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
compose-ui-tooling = { group = "androidx.compose.ui", name = "ui-tooling" }
navigation3 = { group = "androidx.navigation3", name = "navigation3", version.ref = "navigation3" }
lifecycle-viewmodel-compose = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }
lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.2.0" }
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
retrofit = { group = "com.squareup.retrofit2", name = "retrofit", version.ref = "retrofit" }
retrofit-serialization = { group = "com.squareup.retrofit2", name = "converter-kotlinx-serialization", version.ref = "retrofit" }
okhttp = { group = "com.squareup.okhttp3", name = "okhttp", version.ref = "okhttp" }
okhttp-logging = { group = "com.squareup.okhttp3", name = "logging-interceptor", version.ref = "okhttp" }
coil-compose = { group = "io.coil-kt.coil3", name = "coil-compose", version.ref = "coil" }
serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "serialization" }
coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }
coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutines" }
work-runtime = { group = "androidx.work", name = "work-runtime-ktx", version.ref = "work" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
```

Usage in build files:

```kotlin
// app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.navigation3)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
}
```
