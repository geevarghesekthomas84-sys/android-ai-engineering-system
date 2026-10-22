# Compose Architecture & State Management

## Unidirectional Data Flow (UDF)

State flows down from ViewModel to composables. Events flow up from composables to ViewModel via callbacks. The ViewModel is the single source of truth.

```
User Action → ViewModel.onAction(intent) → update StateFlow → Compose recomposes → UI reflects new state
```

```kotlin
// Define UI state
sealed interface TaskListUiState {
    data object Loading : TaskListUiState
    data class Success(
        val tasks: List<Task>,
        val filter: TaskFilter,
        val isRefreshing: Boolean = false,
    ) : TaskListUiState
    data class Error(val message: String) : TaskListUiState
}

// Define user actions (MVI-style intents)
sealed interface TaskListAction {
    data class ChangeFilter(val filter: TaskFilter) : TaskListAction
    data class ToggleComplete(val taskId: String) : TaskListAction
    data object Refresh : TaskListAction
    data class Delete(val taskId: String) : TaskListAction
}
```

## ViewModel with StateFlow

```kotlin
@HiltViewModel
class TaskListViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
) : ViewModel() {

    private val filter = MutableStateFlow(TaskFilter.ALL)
    private val isRefreshing = MutableStateFlow(false)

    val uiState: StateFlow<TaskListUiState> = combine(
        filter,
        isRefreshing,
        filter.flatMapLatest { taskRepository.observeTasks(it) },
    ) { currentFilter, refreshing, tasks ->
        TaskListUiState.Success(
            tasks = tasks,
            filter = currentFilter,
            isRefreshing = refreshing,
        )
    }.catch { emit(TaskListUiState.Error(it.message ?: "Unknown error")) }
     .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TaskListUiState.Loading)

    // Single-event channel for one-shot effects (snackbar, navigation)
    private val _events = Channel<TaskListEvent>(Channel.BUFFERED)
    val events: Flow<TaskListEvent> = _events.receiveAsFlow()

    fun onAction(action: TaskListAction) {
        when (action) {
            is TaskListAction.ChangeFilter -> filter.value = action.filter
            is TaskListAction.ToggleComplete -> toggleTask(action.taskId)
            is TaskListAction.Refresh -> refresh()
            is TaskListAction.Delete -> deleteTask(action.taskId)
        }
    }

    private fun toggleTask(taskId: String) {
        viewModelScope.launch {
            taskRepository.toggleComplete(taskId)
                .onFailure { _events.send(TaskListEvent.ShowError("Failed to update task")) }
        }
    }

    private fun refresh() {
        viewModelScope.launch {
            isRefreshing.value = true
            taskRepository.sync().onFailure {
                _events.send(TaskListEvent.ShowError("Sync failed"))
            }
            isRefreshing.value = false
        }
    }

    private fun deleteTask(taskId: String) {
        viewModelScope.launch {
            taskRepository.delete(taskId)
                .onSuccess { _events.send(TaskListEvent.ShowUndo(taskId)) }
                .onFailure { _events.send(TaskListEvent.ShowError("Delete failed")) }
        }
    }
}

sealed interface TaskListEvent {
    data class ShowError(val message: String) : TaskListEvent
    data class ShowUndo(val taskId: String) : TaskListEvent
}
```

## State Hoisting

Separate stateful containers from stateless UI. The stateless composable is reusable and testable in previews.

```kotlin
// Stateful — owns ViewModel
@Composable
fun TaskListScreen(
    viewModel: TaskListViewModel = hiltViewModel(),
    onNavigateToDetail: (String) -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    // Collect one-shot events
    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is TaskListEvent.ShowError ->
                    snackbarHostState.showSnackbar(event.message)
                is TaskListEvent.ShowUndo ->
                    snackbarHostState.showSnackbar("Task deleted", actionLabel = "Undo")
            }
        }
    }

    TaskListContent(
        uiState = uiState,
        snackbarHostState = snackbarHostState,
        onAction = viewModel::onAction,
        onTaskClick = onNavigateToDetail,
    )
}

// Stateless — pure UI, preview-friendly
@Composable
fun TaskListContent(
    uiState: TaskListUiState,
    snackbarHostState: SnackbarHostState,
    onAction: (TaskListAction) -> Unit,
    onTaskClick: (String) -> Unit,
) {
    Scaffold(snackbarHost = { SnackbarHost(snackbarHostState) }) { padding ->
        when (uiState) {
            is TaskListUiState.Loading -> LoadingIndicator(Modifier.padding(padding))
            is TaskListUiState.Error -> ErrorMessage(uiState.message, Modifier.padding(padding))
            is TaskListUiState.Success -> TaskList(
                tasks = uiState.tasks,
                isRefreshing = uiState.isRefreshing,
                onRefresh = { onAction(TaskListAction.Refresh) },
                onToggle = { onAction(TaskListAction.ToggleComplete(it)) },
                onDelete = { onAction(TaskListAction.Delete(it)) },
                onTaskClick = onTaskClick,
                modifier = Modifier.padding(padding),
            )
        }
    }
}
```

## collectAsStateWithLifecycle

Always use `collectAsStateWithLifecycle()` instead of `collectAsState()`. It stops collection when the lifecycle drops below the minimum state, preventing wasted work and crashes.

```kotlin
// Correct — lifecycle-aware, pauses in background
val uiState by viewModel.uiState.collectAsStateWithLifecycle()

// With custom minimum lifecycle state
val uiState by viewModel.uiState.collectAsStateWithLifecycle(
    minActiveState = Lifecycle.State.RESUMED,
)
```

Requires dependency: `androidx.lifecycle:lifecycle-runtime-compose`.

## Side Effects

### LaunchedEffect
Runs a suspend block when entering composition or when keys change. Cancels and relaunches on key change.

```kotlin
@Composable
fun SearchScreen(viewModel: SearchViewModel = hiltViewModel()) {
    var query by remember { mutableStateOf("") }

    // Debounced search — relaunches when query changes
    LaunchedEffect(query) {
        delay(300)
        viewModel.search(query)
    }
}
```

### SideEffect
Runs on every successful recomposition. Use to sync Compose state with non-Compose code.

```kotlin
@Composable
fun AnalyticsScreen(screenName: String) {
    val analytics = LocalAnalytics.current
    SideEffect {
        analytics.setCurrentScreen(screenName)
    }
}
```

### DisposableEffect
Runs setup on enter, cleanup on leave or key change. Use for listeners and callbacks.

```kotlin
@Composable
fun LifecycleObserver(onResume: () -> Unit, onPause: () -> Unit) {
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> onResume()
                Lifecycle.Event.ON_PAUSE -> onPause()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
}
```

### rememberCoroutineScope
For launching coroutines from callbacks (not from composition).

```kotlin
@Composable
fun ScrollToTopButton(listState: LazyListState) {
    val scope = rememberCoroutineScope()
    FloatingActionButton(onClick = {
        scope.launch { listState.animateScrollToItem(0) }
    }) {
        Icon(Icons.Default.ArrowUpward, contentDescription = "Scroll to top")
    }
}
```

## derivedStateOf

Computes derived state that only triggers recomposition when the result actually changes.

```kotlin
@Composable
fun TaskList(tasks: List<Task>) {
    val listState = rememberLazyListState()

    // Only recomposes when the boolean value changes, not on every scroll pixel
    val showScrollToTop by remember {
        derivedStateOf { listState.firstVisibleItemIndex > 5 }
    }

    Box {
        LazyColumn(state = listState) {
            items(tasks, key = { it.id }) { task -> TaskCard(task) }
        }
        if (showScrollToTop) {
            ScrollToTopButton(listState)
        }
    }
}
```

## snapshotFlow

Converts Compose snapshot state reads into a Flow for use in coroutines.

```kotlin
LaunchedEffect(listState) {
    snapshotFlow { listState.firstVisibleItemIndex }
        .distinctUntilChanged()
        .filter { it > 0 }
        .collect { index ->
            analytics.logScroll(index)
        }
}
```

## CompositionLocal

Provide ambient values down the tree without explicit parameter passing. Use sparingly — prefer explicit parameters for most cases.

```kotlin
// Define
val LocalAnalytics = staticCompositionLocalOf<AnalyticsTracker> {
    error("No AnalyticsTracker provided")
}

// Provide at the top level
@Composable
fun App(analyticsTracker: AnalyticsTracker) {
    CompositionLocalProvider(LocalAnalytics provides analyticsTracker) {
        AppNavigation()
    }
}

// Consume anywhere below
@Composable
fun ProductCard(product: Product) {
    val analytics = LocalAnalytics.current
    Card(onClick = {
        analytics.logEvent("product_click", mapOf("id" to product.id))
    }) { /* ... */ }
}
```

## Stability and Performance

### @Stable and @Immutable Annotations

The Compose compiler skips recomposition of composables whose parameters have not changed. It can infer stability for simple data classes, but complex or external types need hints.

```kotlin
// Compose compiler treats this as stable automatically (all vals, primitive/String types)
data class UserInfo(val id: String, val name: String, val avatarUrl: String)

// External or mutable-looking types need @Stable
@Stable
data class CartState(
    val items: List<CartItem>,  // List is unstable by default
    val total: Double,
)

// @Immutable for truly immutable data
@Immutable
data class Theme(val primary: Color, val background: Color, val textStyle: TextStyle)
```

### Lambda Stability

Wrap lambdas with `remember` or use method references to prevent unstable lambda allocations.

```kotlin
// Unstable — new lambda every recomposition
items(products) { product ->
    ProductCard(onClick = { viewModel.onProductClick(product.id) })
}

// Stable — method reference, same instance
items(products) { product ->
    ProductCard(onClick = remember(product.id) { { viewModel.onProductClick(product.id) } })
}
```

### Key Best Practices in LazyColumn

```kotlin
LazyColumn {
    items(
        items = tasks,
        key = { it.id },           // Stable identity for diffing
        contentType = { it.type }, // Enables view recycling by type
    ) { task ->
        TaskCard(task)
    }
}
```
