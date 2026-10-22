# Kotlin Development for Android

## Kotlin Coding Standards

### Naming Conventions
- Classes/interfaces: `PascalCase` — `UserRepository`, `MainViewModel`
- Functions/properties: `camelCase` — `getUserById`, `isLoading`
- Constants: `UPPER_SNAKE_CASE` — `MAX_RETRY_COUNT`
- Packages: `lowercase` — `com.example.app.data.repository`
- Backing properties: prefix with underscore — `_uiState` backing `uiState`

### Null Safety
```kotlin
// Prefer non-null types
val name: String = "default"

// Use nullable only when null is a valid domain state
val middleName: String? = null

// Safe calls and elvis operator
val length = name?.length ?: 0

// Never use !! except in tests. Use requireNotNull() or checkNotNull()
val user = requireNotNull(getUser()) { "User must be logged in" }
```

### Coroutines and Flow

```kotlin
// ViewModel coroutine scope
class UserViewModel @Inject constructor(
    private val getUserUseCase: GetUserUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow<UserUiState>(UserUiState.Loading)
    val uiState: StateFlow<UserUiState> = _uiState.asStateFlow()

    fun loadUser(id: String) {
        viewModelScope.launch {
            _uiState.value = UserUiState.Loading
            getUserUseCase(id)
                .catch { e -> _uiState.value = UserUiState.Error(e.message ?: "Unknown error") }
                .collect { user -> _uiState.value = UserUiState.Success(user) }
        }
    }
}

sealed interface UserUiState {
    data object Loading : UserUiState
    data class Success(val user: User) : UserUiState
    data class Error(val message: String) : UserUiState
}
```

### Extension Functions
```kotlin
// Use for clear, domain-specific operations
fun String.toFormattedPhone(): String {
    return replace(Regex("(\\d{3})(\\d{3})(\\d{4})"), "($1) $2-$3")
}

// Context extensions for common Android operations
fun Context.showToast(message: String) {
    Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
}
```

### Data Classes and Sealed Types
```kotlin
// Data models
data class User(
    val id: String,
    val name: String,
    val email: String
)

// Sealed hierarchy for exhaustive when expressions
sealed interface Result<out T> {
    data class Success<T>(val data: T) : Result<T>
    data class Error(val exception: Throwable) : Result<Nothing>
    data object Loading : Result<Nothing>
}
```

### Scope Functions
```kotlin
// apply — configure an object
val textView = TextView(context).apply {
    text = "Hello"
    textSize = 16f
}

// let — transform nullable or scoped value
user?.let { saveToDatabase(it) }

// also — side effects
val user = getUser().also { log("Fetched user: ${it.id}") }

// with — multiple operations on same object
with(binding) {
    nameText.text = user.name
    emailText.text = user.email
}

// run — compute a result with receiver
val result = service.run { fetchData().process() }
```

## Android-Specific Kotlin Patterns

### Lifecycle-Aware Collection
```kotlin
// In Compose
@Composable
fun UserScreen(viewModel: UserViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    // ...
}

// In Fragment/Activity (when not using Compose)
lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
        viewModel.uiState.collect { state -> updateUi(state) }
    }
}
```

### Parcelize
```kotlin
@Parcelize
data class UserParcel(
    val id: String,
    val name: String
) : Parcelable
```

### Serialization (kotlinx.serialization)
```kotlin
@Serializable
data class ApiResponse(
    @SerialName("user_name") val userName: String,
    val items: List<Item> = emptyList()
)
```

### Type-Safe Navigation Arguments
```kotlin
// Define route with arguments
@Serializable
data class UserProfile(val userId: String)

// Navigate
navController.navigate(UserProfile(userId = "123"))
```

## Dependency Versions (Latest Stable as of 2026)

Use `android studio version-lookup` or `android docs search` to verify current
versions before adding dependencies. These are reference baselines:

| Library | Group | Artifact |
|---------|-------|----------|
| Compose BOM | androidx.compose | compose-bom |
| Material 3 | androidx.compose.material3 | material3 |
| Navigation Compose | androidx.navigation | navigation-compose |
| Hilt | com.google.dagger | hilt-android |
| Room | androidx.room | room-runtime, room-compiler |
| Retrofit | com.squareup.retrofit2 | retrofit |
| OkHttp | com.squareup.okhttp3 | okhttp |
| DataStore | androidx.datastore | datastore-preferences |
| Lifecycle | androidx.lifecycle | lifecycle-viewmodel-compose |
| Coroutines | org.jetbrains.kotlinx | kotlinx-coroutines-android |
| Serialization | org.jetbrains.kotlinx | kotlinx-serialization-json |
