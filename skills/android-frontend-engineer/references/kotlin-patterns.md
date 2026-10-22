# Modern Kotlin Patterns for Android

## Sealed Interfaces for State Modeling

Prefer sealed interfaces over sealed classes when subclasses carry distinct data. They allow multi-hierarchy implementation and have no constructor overhead.

```kotlin
sealed interface UiState<out T> {
    data object Loading : UiState<Nothing>
    data class Success<T>(val data: T) : UiState<T>
    data class Error(val exception: Throwable) : UiState<Nothing>
}

// Exhaustive when
fun <T> UiState<T>.render() = when (this) {
    is UiState.Loading -> showLoading()
    is UiState.Success -> showData(data)
    is UiState.Error -> showError(exception)
}
```

## Data Classes and Value Classes

```kotlin
// Data class for multi-field DTOs
data class User(
    val id: String,
    val name: String,
    val email: String,
    val avatarUrl: String?,
)

// Value class for type-safe primitives — zero allocation overhead at runtime
@JvmInline
value class UserId(val value: String)

@JvmInline
value class Email(val value: String) {
    init { require(value.contains("@")) { "Invalid email" } }
}
```

## Extension Functions

```kotlin
// Context extensions
fun Context.toast(message: String, duration: Int = Toast.LENGTH_SHORT) {
    Toast.makeText(this, message, duration).show()
}

// Nullable receivers for safe transformations
fun String?.orEmpty(): String = this ?: ""

// Domain extensions for readability
fun Instant.isToday(): Boolean {
    val now = Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault()).date
    return this.toLocalDateTime(TimeZone.currentSystemDefault()).date == now
}

// Flow extensions for common patterns
fun <T> Flow<T>.throttleFirst(windowMs: Long): Flow<T> = flow {
    var lastEmitTime = 0L
    collect { value ->
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastEmitTime >= windowMs) {
            lastEmitTime = currentTime
            emit(value)
        }
    }
}
```

## Scope Functions Reference

```kotlin
// let — transform nullable, introduce scoped variable
val length: Int? = name?.let { it.trim().length }

// run — execute block on object, return result
val result = service.run {
    configure()
    execute()
}

// with — operate on object without chaining, return result
val description = with(user) {
    "$name ($email) — joined ${joinDate.format()}"
}

// apply — configure object, return the object itself
val request = Request.Builder().apply {
    url(endpoint)
    header("Authorization", "Bearer $token")
    post(body)
}.build()

// also — side effects, return the object itself
fun createUser(name: String): User =
    User(name = name).also { logger.info("Created user: ${it.id}") }
```

## Delegation

```kotlin
// Property delegation
class SettingsRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) {
    val theme: Flow<AppTheme> = dataStore.data.map { prefs ->
        AppTheme.valueOf(prefs[THEME_KEY] ?: AppTheme.SYSTEM.name)
    }
}

// Interface delegation for decoration
class LoggingUserRepository(
    private val delegate: UserRepository,
    private val logger: Logger,
) : UserRepository by delegate {
    override suspend fun getUser(id: String): User {
        logger.d("Fetching user: $id")
        return delegate.getUser(id)
    }
}

// Map delegation for config objects
class Config(private val map: Map<String, Any>) {
    val apiUrl: String by map
    val timeout: Int by map
}
```

## Inline and Reified Generics

```kotlin
// Reified type for JSON parsing without passing Class<T>
inline fun <reified T> String.fromJson(): T =
    Json.decodeFromString<T>(this)

// Inline for higher-order functions to avoid lambda allocation
inline fun <T> measureTimeAndReturn(block: () -> T): Pair<T, Duration> {
    val mark = TimeSource.Monotonic.markNow()
    val result = block()
    return result to mark.elapsedNow()
}

// Reified for intent creation
inline fun <reified T : Activity> Context.startActivity(
    configIntent: Intent.() -> Unit = {},
) {
    startActivity(Intent(this, T::class.java).apply(configIntent))
}
```

## Coroutine Builders

```kotlin
// launch — fire-and-forget in a scope
viewModelScope.launch {
    repository.syncData()
}

// async — concurrent decomposition, await results
suspend fun loadDashboard(): Dashboard = coroutineScope {
    val userDeferred = async { userRepo.getCurrent() }
    val statsDeferred = async { statsRepo.getStats() }
    Dashboard(user = userDeferred.await(), stats = statsDeferred.await())
}

// withContext — switch dispatcher for blocking work
suspend fun readFile(path: String): String = withContext(Dispatchers.IO) {
    File(path).readText()
}
```

## Flow Operators

```kotlin
// Transforming and combining flows
val searchResults: StateFlow<List<Product>> = searchQuery
    .debounce(300)
    .filter { it.length >= 2 }
    .distinctUntilChanged()
    .flatMapLatest { query -> productRepo.search(query) }
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

// Combining multiple flows
val uiState: StateFlow<HomeUiState> = combine(
    userRepo.currentUser,
    settingsRepo.theme,
    notificationRepo.unreadCount,
) { user, theme, unreadCount ->
    HomeUiState(user = user, theme = theme, unreadCount = unreadCount)
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HomeUiState.Loading)

// shareIn for one-to-many (hot) sharing
val connectionStatus: SharedFlow<ConnectionStatus> = connectivityMonitor
    .observe()
    .shareIn(appScope, SharingStarted.Eagerly, replay = 1)
```

## Structured Concurrency

```kotlin
// supervisorScope — one child failure does not cancel siblings
suspend fun syncAll() = supervisorScope {
    launch { syncUsers() }
    launch { syncPosts() }   // Failure here does not cancel syncUsers
    launch { syncSettings() }
}

// coroutineScope — structured, all-or-nothing
suspend fun fetchUserWithPosts(userId: String): UserWithPosts = coroutineScope {
    val user = async { userApi.getUser(userId) }
    val posts = async { postApi.getUserPosts(userId) }
    UserWithPosts(user.await(), posts.await()) // If either fails, both cancel
}
```

## Error Handling with Result and runCatching

```kotlin
// runCatching wraps in Result<T>
suspend fun safeApiCall(): Result<User> = runCatching {
    apiService.getUser()
}

// Chaining with map/recover
val displayName: String = runCatching { apiService.getUser() }
    .map { it.displayName }
    .recover { "Guest" }
    .getOrThrow()

// fold for exhaustive handling
runCatching { repository.save(data) }.fold(
    onSuccess = { showSuccess("Saved") },
    onFailure = { error ->
        when (error) {
            is IOException -> showError("Network error")
            is HttpException -> showError("Server error: ${error.code()}")
            else -> throw error // rethrow unexpected
        }
    },
)

// Custom Result type for domain errors
sealed interface DataResult<out T> {
    data class Success<T>(val data: T) : DataResult<T>
    data class Failure(val error: DomainError) : DataResult<Nothing>
}

sealed interface DomainError {
    data object NetworkUnavailable : DomainError
    data class ServerError(val code: Int, val message: String) : DomainError
    data class ValidationError(val field: String, val reason: String) : DomainError
}
```
