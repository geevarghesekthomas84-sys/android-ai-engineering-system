# Navigation3 Complete Guide (1.0.1)

## Core Concepts

Navigation3 replaces the XML/destination-based Navigation Component with a fully type-safe, Compose-first approach. The core primitives:

- **NavKey** — A `@Serializable` data class/object representing a destination. Carries its own arguments.
- **NavBackStack** — An observable list of NavKeys managed by `rememberNavBackStack`.
- **NavDisplay** — The composable that renders the current back stack entry using an `entryProvider`.

## Setup

```kotlin
// build.gradle.kts
dependencies {
    implementation("androidx.navigation3:navigation3:1.0.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.1")
}
```

## Defining NavKeys

Each destination is a `@Serializable` type implementing `NavKey`. Arguments are properties on the data class.

```kotlin
import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data object HomeKey : NavKey

@Serializable
data object SettingsKey : NavKey

@Serializable
data class ProfileKey(val userId: String) : NavKey

@Serializable
data class TaskDetailKey(val taskId: String, val isEditing: Boolean = false) : NavKey

@Serializable
data class SearchResultsKey(val query: String, val category: String? = null) : NavKey
```

## Basic Navigation Setup

```kotlin
import androidx.navigation3.runtime.NavBackStack
import androidx.navigation3.runtime.NavDisplay
import androidx.navigation3.runtime.entry
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack

@Composable
fun AppNavigation() {
    val backStack = rememberNavBackStack(HomeKey)

    NavDisplay(
        backStack = backStack,
        entryProvider = entryProvider {
            entry<HomeKey> { key ->
                HomeScreen(
                    onNavigateToProfile = { userId ->
                        backStack.add(ProfileKey(userId))
                    },
                    onNavigateToSettings = {
                        backStack.add(SettingsKey)
                    },
                )
            }

            entry<ProfileKey> { key ->
                ProfileScreen(
                    userId = key.userId,
                    onNavigateBack = { backStack.removeLastOrNull() },
                    onNavigateToSettings = { backStack.add(SettingsKey) },
                )
            }

            entry<SettingsKey> { key ->
                SettingsScreen(
                    onNavigateBack = { backStack.removeLastOrNull() },
                )
            }

            entry<TaskDetailKey> { key ->
                TaskDetailScreen(
                    taskId = key.taskId,
                    isEditing = key.isEditing,
                    onNavigateBack = { backStack.removeLastOrNull() },
                )
            }
        },
    )
}
```

## Passing Arguments via NavKeys

Arguments are type-safe properties on the data class. No more string-based argument extraction.

```kotlin
@Serializable
data class OrderDetailKey(
    val orderId: String,
    val showTracking: Boolean = false,
) : NavKey

// Navigating with arguments
backStack.add(OrderDetailKey(orderId = "ORD-123", showTracking = true))

// Receiving arguments — directly from the key
entry<OrderDetailKey> { key ->
    OrderDetailScreen(
        orderId = key.orderId,
        showTracking = key.showTracking,
        onNavigateBack = { backStack.removeLastOrNull() },
    )
}
```

## ViewModel Integration with SavedStateHandle

Navigation3 serializes NavKey properties into the `SavedStateHandle`. Access them by property name.

```kotlin
@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    // Property names match the NavKey data class fields
    private val orderId: String = savedStateHandle["orderId"]!!
    private val showTracking: Boolean = savedStateHandle["showTracking"] ?: false

    val uiState: StateFlow<OrderDetailUiState> = orderRepository
        .observeOrder(orderId)
        .map { order -> OrderDetailUiState.Success(order, showTracking) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), OrderDetailUiState.Loading)
}
```

## Bottom Navigation Integration

```kotlin
@Serializable
data object HomeTab : NavKey
@Serializable
data object SearchTab : NavKey
@Serializable
data object ProfileTab : NavKey

data class BottomNavItem(
    val label: String,
    val icon: ImageVector,
    val key: NavKey,
)

val bottomNavItems = listOf(
    BottomNavItem("Home", Icons.Default.Home, HomeTab),
    BottomNavItem("Search", Icons.Default.Search, SearchTab),
    BottomNavItem("Profile", Icons.Default.Person, ProfileTab),
)

@Composable
fun MainScreen() {
    val backStack = rememberNavBackStack(HomeTab)
    // Track selected tab independently so bottom bar highlights correctly
    var selectedTab by remember { mutableStateOf<NavKey>(HomeTab) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                bottomNavItems.forEach { item ->
                    NavigationBarItem(
                        selected = selectedTab == item.key,
                        onClick = {
                            selectedTab = item.key
                            // Clear to root and navigate to tab
                            backStack.removeAll { true }
                            backStack.add(item.key)
                        },
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) },
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            NavDisplay(
                backStack = backStack,
                entryProvider = entryProvider {
                    entry<HomeTab> { HomeScreen(onNavigateToDetail = { backStack.add(TaskDetailKey(it)) }) }
                    entry<SearchTab> { SearchScreen() }
                    entry<ProfileTab> { ProfileScreen() }
                    entry<TaskDetailKey> { key -> TaskDetailScreen(key.taskId) }
                },
            )
        }
    }
}
```

## Nested Navigation

Create separate back stacks for nested flows such as onboarding or authentication.

```kotlin
@Serializable
data object OnboardingFlowKey : NavKey

@Serializable
data object WelcomeStepKey : NavKey
@Serializable
data object NameStepKey : NavKey
@Serializable
data object InterestsStepKey : NavKey

@Composable
fun OnboardingFlow(onComplete: () -> Unit) {
    val onboardingStack = rememberNavBackStack(WelcomeStepKey)

    NavDisplay(
        backStack = onboardingStack,
        entryProvider = entryProvider {
            entry<WelcomeStepKey> {
                WelcomeStep(onNext = { onboardingStack.add(NameStepKey) })
            }
            entry<NameStepKey> {
                NameStep(
                    onNext = { onboardingStack.add(InterestsStepKey) },
                    onBack = { onboardingStack.removeLastOrNull() },
                )
            }
            entry<InterestsStepKey> {
                InterestsStep(
                    onComplete = onComplete,
                    onBack = { onboardingStack.removeLastOrNull() },
                )
            }
        },
    )
}
```

## Deep Link Handling

Register deep links in the manifest and map incoming intents to NavKeys.

```xml
<!-- AndroidManifest.xml -->
<activity android:name=".MainActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" android:host="task" />
        <data android:scheme="https" android:host="myapp.example.com" android:pathPrefix="/task" />
    </intent-filter>
</activity>
```

```kotlin
// In MainActivity
fun handleDeepLink(intent: Intent, backStack: NavBackStack) {
    val uri = intent.data ?: return
    when {
        uri.pathSegments.firstOrNull() == "task" -> {
            val taskId = uri.pathSegments.getOrNull(1) ?: return
            backStack.add(TaskDetailKey(taskId))
        }
        uri.pathSegments.firstOrNull() == "profile" -> {
            val userId = uri.pathSegments.getOrNull(1) ?: return
            backStack.add(ProfileKey(userId))
        }
    }
}

// Wire to activity
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val backStack = rememberNavBackStack(HomeKey)

            LaunchedEffect(Unit) {
                handleDeepLink(intent, backStack)
            }

            AppNavigation(backStack = backStack)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle deep link when activity is already running
    }
}
```

## Back Stack Manipulation

```kotlin
// Navigate forward
backStack.add(ProfileKey(userId))

// Go back one step
backStack.removeLastOrNull()

// Pop to specific destination (clear everything above it)
backStack.removeAll { it !is HomeKey }

// Replace current destination
backStack.removeLastOrNull()
backStack.add(NewDestinationKey)

// Clear and restart
backStack.removeAll { true }
backStack.add(HomeKey)
```

## Conditional Navigation (Auth Gate)

```kotlin
@Composable
fun RootNavigation(isLoggedIn: Boolean) {
    val backStack = rememberNavBackStack(
        if (isLoggedIn) HomeKey else LoginKey,
    )

    // React to auth state changes
    LaunchedEffect(isLoggedIn) {
        if (!isLoggedIn) {
            backStack.removeAll { true }
            backStack.add(LoginKey)
        } else if (backStack.lastOrNull() is LoginKey) {
            backStack.removeAll { true }
            backStack.add(HomeKey)
        }
    }

    NavDisplay(
        backStack = backStack,
        entryProvider = entryProvider {
            entry<LoginKey> {
                LoginScreen(onLoginSuccess = {
                    backStack.removeAll { true }
                    backStack.add(HomeKey)
                })
            }
            entry<HomeKey> { HomeScreen(/* ... */) }
            // ... other entries
        },
    )
}
```

## Transition Animations

Navigation3 supports custom entry and exit animations through the `NavDisplay` API.

```kotlin
NavDisplay(
    backStack = backStack,
    entryProvider = entryProvider {
        entry<HomeKey>(
            metadata = mapOf(
                NavDisplay.transitionSpec to {
                    slideInHorizontally(initialOffsetX = { it }) togetherWith
                        slideOutHorizontally(targetOffsetX = { -it })
                },
            ),
        ) {
            HomeScreen()
        }
    },
)
```
