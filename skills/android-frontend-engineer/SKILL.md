---
name: android-frontend-engineer
description: Expert Android frontend engineering with Kotlin, Jetpack Compose, Navigation3, MVVM/MVI, dependency injection, coroutines, and modular architecture
metadata:
  author: Custom
  keywords:
  - kotlin
  - compose
  - navigation3
  - mvvm
  - mvi
  - hilt
  - coroutines
  - architecture
---

# Android Frontend Engineer Skill

## Trigger Conditions

Activate this skill when the task involves:
- Building a new screen or feature in an Android app
- Implementing or refactoring Compose UI components
- Setting up navigation flows with Navigation3
- Making architecture decisions (MVVM vs MVI, module boundaries, state management)
- Integrating state management with ViewModel and StateFlow
- Wiring dependency injection with Hilt
- Handling background work, push notifications, or deep links
- Performance optimization of Compose rendering or data layers
- Offline-first architecture or network layer design

## Capabilities

### Language & UI
- **Kotlin idioms**: sealed interfaces, data classes, extension functions, scope functions, delegation, destructuring, inline/reified generics, contracts
- **Jetpack Compose (BOM 2026.03.01)**: Material 3 components, theming, custom layouts, modifiers, animations (`animateContentSize`, `AnimatedVisibility`, `Crossfade`, `updateTransition`), lazy lists with keys and content types
- **Navigation3 (1.0.1)**: `NavKey` with `@Serializable`, `rememberNavBackStack`, `NavDisplay`, `entryProvider`, type-safe argument passing, deep link handling, bottom nav integration

### Architecture & Data
- **MVVM/MVI patterns**: ViewModel with `StateFlow<UiState>`, single-event channels, intent-based action dispatch
- **Lifecycle-aware collection**: `collectAsStateWithLifecycle()` for safe UI state observation
- **Hilt DI**: `@HiltAndroidApp`, `@AndroidEntryPoint`, `hiltViewModel()`, module scoping, multi-module injection
- **Coroutines & Flow**: structured concurrency, `viewModelScope`, Flow operators (`map`, `filter`, `combine`, `stateIn`, `shareIn`), `conflate`, `debounce`
- **Networking**: Retrofit with `kotlinx.serialization`, OkHttp interceptors, sealed Result types, retry logic, connectivity monitoring
- **Persistence**: Room with Flow-based queries, DataStore for preferences, offline-first caching

### Features & Platform
- **API-driven UI**: loading/error/success states, pull-to-refresh, pagination (Paging 3 with `collectAsLazyPagingItems`)
- **Image loading**: Coil 3 with `AsyncImage`, transformations, caching, placeholder/error drawables
- **Push notifications**: FCM setup, notification channels (Android 8+), data vs notification messages, deep link from payload
- **Deep links**: Navigation3 deep link matching, intent filters in manifest, deferred deep links
- **Runtime permissions**: `rememberLauncherForActivityResult` with `ActivityResultContracts.RequestPermission`, rationale flows
- **File uploads**: multipart with Retrofit `@Multipart`/`@Part`, progress tracking with OkHttp `RequestBody` wrapper
- **Background work**: WorkManager (one-time, periodic, chained, constrained), foreground services
- **Error handling**: global exception handler, Compose `ErrorBoundary` patterns, graceful degradation
- **Modular architecture**: feature modules, core modules, convention plugins, API-vs-implementation dependencies

## Development Workflow

When implementing a feature, follow this sequence:

1. **Analyze requirements** — Identify screens, user interactions, data sources, and edge cases (empty states, errors, offline).
2. **Define data models** — Create `@Serializable` data classes for API responses and Room entities. Map between layers with extension functions.
3. **Implement repository** — Build the data layer with Retrofit interface, Room DAO, and a repository that exposes `Flow<T>` with offline-first logic.
4. **Create ViewModel** — Define `UiState` sealed interface, expose `StateFlow<UiState>`, handle user actions, orchestrate use cases.
5. **Build Compose UI** — Implement screens as stateless composables receiving state and lambda callbacks. Use Material 3 components.
6. **Wire navigation** — Define `@Serializable` NavKey data classes, register entries in `entryProvider`, connect user actions to navigation events.
7. **Test** — Unit test ViewModel with Turbine for Flow assertions, UI test with `createComposeRule`, fake repositories.
8. **Optimize** — Profile with Layout Inspector, fix unnecessary recompositions with `Stable`/`Immutable` annotations, use `derivedStateOf` and lambda-based modifiers.

## Quick Reference

### New Screen Skeleton
```kotlin
// NavKey
@Serializable
data class ProfileKey(val userId: String) : NavKey

// UiState
sealed interface ProfileUiState {
    data object Loading : ProfileUiState
    data class Success(val user: User) : ProfileUiState
    data class Error(val message: String) : ProfileUiState
}

// ViewModel
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val userRepository: UserRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val userId: String = savedStateHandle["userId"]!!
    val uiState: StateFlow<ProfileUiState> = userRepository
        .getUser(userId)
        .map<User, ProfileUiState> { ProfileUiState.Success(it) }
        .catch { emit(ProfileUiState.Error(it.message ?: "Unknown error")) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ProfileUiState.Loading)
}

// Composable
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    ProfileContent(uiState = uiState, onNavigateBack = onNavigateBack)
}
```

### Common Gradle Dependencies (BOM 2026.03.01)
```kotlin
// build.gradle.kts (app)
dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.03.01")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.navigation3:navigation3:1.0.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.1")
    implementation("com.google.dagger:hilt-android:2.56.2")
    ksp("com.google.dagger:hilt-compiler:2.56.2")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")
    implementation("io.coil-kt.coil3:coil-compose:3.2.0")
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    implementation("androidx.room:room-runtime:2.7.1")
    implementation("androidx.room:room-ktx:2.7.1")
    ksp("androidx.room:room-compiler:2.7.1")
    implementation("androidx.work:work-runtime-ktx:2.10.1")
}
```

## Reference Documents

- `references/kotlin-patterns.md` — Modern Kotlin idioms and coroutine patterns
- `references/compose-architecture.md` — Compose state management and side effects
- `references/navigation3-guide.md` — Navigation3 setup and routing
- `references/dependency-injection.md` — Hilt DI configuration and patterns
- `references/networking.md` — Retrofit, OkHttp, and offline-first networking
- `references/background-work.md` — WorkManager, FCM, and background processing
- `references/modular-architecture.md` — Multi-module project structure and conventions
