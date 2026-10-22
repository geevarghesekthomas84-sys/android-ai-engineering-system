# App Architecture Templates

## E-Commerce App

### Core Entities
- User, Product, Category, Cart, CartItem, Order, OrderItem, Payment, Review, Address, Wishlist

### Module Structure
```
feature-catalog/       Product listing, search, filtering, product detail
feature-cart/          Cart management, quantity updates, promo codes
feature-checkout/      Address selection, payment, order confirmation
feature-orders/        Order history, order detail, tracking
feature-reviews/       Product reviews, ratings
feature-auth/          Login, signup, password reset
feature-profile/       User profile, addresses, payment methods
feature-search/        Search bar, suggestions, recent searches, filters
```

### Key Architecture Decisions
- **Offline catalog**: Cache products and categories in Room; sync on pull-to-refresh and background WorkManager job
- **Cart**: Local-first in Room (works offline), synced to server when online; conflict resolution favors server state on merge
- **Checkout flow**: Single-Activity with Navigation graph; steps = address -> shipping method -> payment -> review -> confirm
- **Product images**: Coil with disk cache; preload visible items; progressive loading with thumbnails
- **Search**: Debounced input (300ms), local recent-searches in DataStore, remote search API with cancellation
- **Payments**: Delegate to payment SDK (Stripe, Razorpay); never store card details locally; tokenize on server

### API Endpoints
```
GET    /products?category={id}&cursor={c}&limit=25&sort=price:asc
GET    /products/{id}
GET    /categories
POST   /cart/items
PATCH  /cart/items/{id}
DELETE /cart/items/{id}
POST   /orders
GET    /orders/{id}
GET    /orders/{id}/tracking
POST   /payments/intent
POST   /reviews
GET    /products/{id}/reviews?cursor={c}&limit=10
```

### State Management
```kotlin
data class CatalogUiState(
    val products: List<ProductUi> = emptyList(),
    val categories: List<CategoryUi> = emptyList(),
    val selectedCategory: String? = null,
    val isLoading: Boolean = false,
    val error: UiError? = null,
    val endReached: Boolean = false
)
```

---

## Social / Community App

### Core Entities
- User, Profile, Post, Comment, Like, Follow, Message, Conversation, Notification, Report, Media

### Module Structure
```
feature-feed/          Timeline, post creation, reactions
feature-profile/       User profile, followers/following, media grid
feature-messaging/     Conversations, real-time chat, media sharing
feature-notifications/ Push and in-app notifications
feature-discovery/     Explore, trending, suggested users
feature-auth/          Login, signup, phone/email verification
feature-media/         Camera, gallery picker, cropping, upload
feature-settings/      Privacy, blocked users, notification prefs
```

### Key Architecture Decisions
- **Feed**: Paginated with cursor; cache in Room for instant load; new posts inserted at top via WebSocket event
- **Real-time messaging**: WebSocket (OkHttp) for active conversations; FCM push for background; message queue for offline sends
- **Media upload**: Chunked upload via WorkManager (survives process death); compress images before upload; generate thumbnails locally
- **Notifications**: FCM for push; local notification channel per type (messages, likes, follows); in-app notification feed from REST API
- **Infinite scroll**: Paging 3 with RemoteMediator backed by Room (single source of truth pattern)
- **Content moderation**: Client-side image hash check; server-side ML filtering; report flow stored locally until synced

### Real-Time Architecture
```kotlin
// WebSocket message sealed class
sealed class WsEvent {
    data class NewMessage(val message: MessageDto) : WsEvent()
    data class TypingIndicator(val userId: String, val conversationId: String) : WsEvent()
    data class PresenceUpdate(val userId: String, val isOnline: Boolean) : WsEvent()
    data class PostReaction(val postId: String, val reaction: ReactionDto) : WsEvent()
}

// Connection management
class WebSocketManager(private val okHttpClient: OkHttpClient) {
    private val _events = MutableSharedFlow<WsEvent>(replay = 0, extraBufferCapacity = 64)
    val events: SharedFlow<WsEvent> = _events.asSharedFlow()

    fun connect(token: String) { /* ... */ }
    fun disconnect() { /* ... */ }
    fun send(action: WsAction) { /* ... */ }
}
```

### API Endpoints
```
GET    /feed?cursor={c}&limit=20
POST   /posts
DELETE /posts/{id}
POST   /posts/{id}/like
DELETE /posts/{id}/like
GET    /posts/{id}/comments?cursor={c}&limit=20
POST   /posts/{id}/comments
GET    /users/{id}/profile
POST   /users/{id}/follow
DELETE /users/{id}/follow
GET    /conversations
GET    /conversations/{id}/messages?cursor={c}&limit=50
POST   /conversations/{id}/messages
GET    /notifications?cursor={c}&limit=30
PATCH  /notifications/read
```

---

## Finance / Banking App

### Core Entities
- User, Account, Transaction, Transfer, Payee, Budget, Category, Card, Statement, KycDocument

### Module Structure
```
feature-dashboard/     Account overview, balance, recent transactions
feature-transactions/  Transaction list, detail, search, filters
feature-transfers/     Send money, schedule transfers, recurring payments
feature-cards/         Virtual/physical card management, freeze, limits
feature-budgets/       Budget creation, tracking, alerts
feature-auth/          Biometric login, PIN, MFA
feature-onboarding/    KYC document upload, identity verification
feature-settings/      Security settings, notification prefs, linked accounts
```

### Key Architecture Decisions
- **Security first**: Certificate pinning via OkHttp CertificatePinner; root/emulator detection; no sensitive data in logs; encrypted SharedPreferences for tokens
- **Biometric auth**: BiometricPrompt for unlock; store encrypted session token in AndroidKeyStore; auto-lock after 5 min background
- **Transaction list**: Paging 3 with date-grouped sections; local cache for recent (last 90 days); older fetched on demand
- **Offline**: Read-only offline; transfers queued locally with pending status; executed on reconnect with idempotency key
- **Amount handling**: Always `BigDecimal` in domain; stored as `Long` (cents) in Room and API; formatted per locale with `NumberFormat.getCurrencyInstance()`
- **Encryption**: SQLCipher for Room database; encrypted DataStore for preferences; no PII in plain text anywhere on device

### Security Layer
```kotlin
// Certificate pinning
val certificatePinner = CertificatePinner.Builder()
    .add("api.mybank.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    .add("api.mybank.com", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=")
    .build()

// Encrypted storage
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val encryptedPrefs = EncryptedSharedPreferences.create(
    context, "secure_prefs", masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)

// Inactivity lock
class InactivityTracker(private val timeoutMs: Long = 5 * 60 * 1000L) {
    private var lastActivity: Long = SystemClock.elapsedRealtime()

    fun touch() { lastActivity = SystemClock.elapsedRealtime() }
    fun isExpired(): Boolean = SystemClock.elapsedRealtime() - lastActivity > timeoutMs
}
```

### API Endpoints
```
GET    /accounts
GET    /accounts/{id}/transactions?from={date}&to={date}&cursor={c}
GET    /accounts/{id}/balance
POST   /transfers
GET    /transfers/{id}
GET    /payees
POST   /payees
GET    /budgets
POST   /budgets
PATCH  /budgets/{id}
GET    /cards
POST   /cards/{id}/freeze
POST   /cards/{id}/unfreeze
PATCH  /cards/{id}/limits
```

---

## Productivity / Task Management App

### Core Entities
- User, Workspace, Project, Task, Subtask, Label, Comment, Attachment, Reminder, TimeEntry

### Module Structure
```
feature-inbox/         Incoming tasks, quick capture
feature-today/         Today's tasks, overdue, upcoming
feature-projects/      Project boards (list/kanban), project settings
feature-task-detail/   Task editing, subtasks, comments, attachments
feature-calendar/      Calendar view, deadline visualization
feature-search/        Full-text search across tasks, projects, comments
feature-auth/          Login, workspace selection
feature-settings/      Theme, default project, notification schedule
```

### Key Architecture Decisions
- **Offline-first**: Room is source of truth; all mutations apply locally first; sync engine reconciles with server via timestamps and conflict resolution
- **Sync strategy**: Modified-since polling every 60s when active; push via FCM for changes by others; full sync on first launch and after long offline
- **Conflict resolution**: Last-write-wins for simple fields; merge for lists (subtasks, labels); server arbiter for ordering conflicts
- **Quick capture**: Foreground service with persistent notification for instant task creation; share intent receiver for links/text
- **Drag and drop**: LazyColumn with drag-to-reorder; optimistic local reorder; batch position update to server
- **Reminders**: AlarmManager for exact-time reminders; WorkManager for recurring; notification channels per project

### Sync Engine Pattern
```kotlin
class SyncEngine(
    private val localDataSource: LocalDataSource,
    private val remoteDataSource: RemoteDataSource,
    private val conflictResolver: ConflictResolver
) {
    suspend fun sync() {
        // 1. Push local changes
        val pendingChanges = localDataSource.getPendingChanges()
        for (change in pendingChanges) {
            try {
                remoteDataSource.push(change)
                localDataSource.markSynced(change.id)
            } catch (e: ConflictException) {
                val resolved = conflictResolver.resolve(change, e.serverVersion)
                localDataSource.applyResolved(resolved)
            }
        }

        // 2. Pull remote changes
        val lastSync = localDataSource.getLastSyncTimestamp()
        val remoteChanges = remoteDataSource.getChangesSince(lastSync)
        localDataSource.applyRemoteChanges(remoteChanges)
        localDataSource.updateLastSyncTimestamp(Clock.System.now())
    }
}
```

### API Endpoints
```
GET    /workspaces
GET    /projects?workspace={id}
POST   /projects
GET    /tasks?project={id}&status={s}&cursor={c}
POST   /tasks
PATCH  /tasks/{id}
DELETE /tasks/{id}
POST   /tasks/{id}/subtasks
PATCH  /tasks/{id}/order
POST   /tasks/{id}/comments
GET    /tasks/{id}/attachments
POST   /tasks/{id}/attachments  (multipart)
GET    /sync/changes?since={timestamp}
POST   /sync/push
```

---

## Health / Fitness App

### Core Entities
- User, HealthProfile, Workout, Exercise, WorkoutSet, DailyLog, Meal, FoodItem, WaterIntake, SleepRecord, Goal, Achievement

### Module Structure
```
feature-dashboard/     Daily summary, streaks, progress rings
feature-workouts/      Workout plans, active workout, exercise library
feature-nutrition/     Food diary, meal logging, calorie tracking, barcode scan
feature-progress/      Charts, body measurements, progress photos
feature-goals/         Goal setting, milestones, achievements
feature-sleep/         Sleep tracking integration, sleep score
feature-auth/          Login, health profile setup
feature-settings/      Units (metric/imperial), connected devices, data export
```

### Key Architecture Decisions
- **Health Connect integration**: Read/write via Health Connect API for interop with Google Fit, Samsung Health, etc.; request only needed permissions
- **Active workout**: Foreground service with ongoing notification; timer and set tracking survive process death via saved state in Room
- **Charts**: MPAndroidChart or Vico for weight/calorie trends; 7-day, 30-day, 90-day, 1-year views; data aggregated in SQL queries
- **Barcode scanning**: ML Kit barcode scanner -> OpenFoodFacts API lookup; cache scanned items locally
- **Offline**: All logging works offline; daily logs stored in Room; sync optional (user may never sync)
- **Units**: Store everything in metric internally; convert on display based on user preference in DataStore
- **Reminders**: Workout reminders, water intake nudges, meal logging prompts via AlarmManager

### Health Connect Integration
```kotlin
class HealthConnectManager(private val context: Context) {
    private val healthConnectClient by lazy { HealthConnectClient.getOrCreate(context) }

    val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
    )

    suspend fun readStepsToday(): Long {
        val now = Instant.now()
        val startOfDay = now.atZone(ZoneId.systemDefault())
            .toLocalDate().atStartOfDay(ZoneId.systemDefault()).toInstant()

        val response = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = StepsRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfDay, now)
            )
        )
        return response.records.sumOf { it.count }
    }

    suspend fun writeWorkout(workout: Workout) {
        val record = ExerciseSessionRecord(
            startTime = workout.startTime,
            startZoneOffset = ZoneOffset.systemDefault().rules.getOffset(workout.startTime),
            endTime = workout.endTime,
            endZoneOffset = ZoneOffset.systemDefault().rules.getOffset(workout.endTime),
            exerciseType = mapExerciseType(workout.type),
            title = workout.name
        )
        healthConnectClient.insertRecords(listOf(record))
    }
}
```

### Data Aggregation Queries
```kotlin
@Dao
interface DailyLogDao {
    @Query("""
        SELECT
            date,
            SUM(calories) as totalCalories,
            SUM(protein) as totalProtein,
            SUM(carbs) as totalCarbs,
            SUM(fat) as totalFat,
            SUM(water_ml) as totalWaterMl
        FROM daily_logs
        WHERE date BETWEEN :startDate AND :endDate
        GROUP BY date
        ORDER BY date ASC
    """)
    fun getDailySummaries(startDate: String, endDate: String): Flow<List<DailySummary>>

    @Query("""
        SELECT
            strftime('%Y-%W', date) as week,
            AVG(calories) as avgCalories,
            COUNT(*) as loggedDays
        FROM daily_logs
        WHERE date >= :sinceDate
        GROUP BY week
        ORDER BY week ASC
    """)
    fun getWeeklyAverages(sinceDate: String): Flow<List<WeeklySummary>>
}
```

### API Endpoints
```
GET    /health-profile
PATCH  /health-profile
GET    /workouts?from={date}&to={date}&cursor={c}
POST   /workouts
GET    /exercises
GET    /meals?date={date}
POST   /meals
GET    /food/search?q={query}
GET    /food/barcode/{code}
GET    /progress/weight?from={date}&to={date}
POST   /progress/weight
GET    /progress/measurements
GET    /goals
POST   /goals
PATCH  /goals/{id}
GET    /achievements
GET    /sleep?from={date}&to={date}
```

---

## Cross-Cutting Template Patterns

### Navigation Graph (Any App)

```kotlin
@Composable
fun AppNavHost(navController: NavHostController) {
    NavHost(navController = navController, startDestination = "home") {
        // Feature-owned nav graphs
        homeGraph(navController)
        authGraph(navController)
        profileGraph(navController)
        settingsGraph(navController)
    }
}

// Each feature exposes a NavGraphBuilder extension
fun NavGraphBuilder.homeGraph(navController: NavHostController) {
    navigation(startDestination = "home/feed", route = "home") {
        composable("home/feed") { HomeFeedScreen(navController) }
        composable("home/detail/{id}") { DetailScreen(navController) }
    }
}
```

### ViewModel Pattern (Any App)

```kotlin
@HiltViewModel
class ListViewModel @Inject constructor(
    private val getItemsUseCase: GetItemsUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(ListUiState())
    val uiState: StateFlow<ListUiState> = _uiState.asStateFlow()

    init { loadItems() }

    fun onEvent(event: ListEvent) {
        when (event) {
            is ListEvent.Refresh -> loadItems()
            is ListEvent.LoadMore -> loadMore()
            is ListEvent.Search -> search(event.query)
        }
    }

    private fun loadItems() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            getItemsUseCase()
                .catch { e -> _uiState.update { it.copy(isLoading = false, error = e.toUiError()) } }
                .collect { items -> _uiState.update { it.copy(items = items, isLoading = false) } }
        }
    }
}
```

### Error Handling (Any App)

```kotlin
sealed class UiError {
    object Network : UiError()
    object Unauthorized : UiError()
    object NotFound : UiError()
    object RateLimited : UiError()
    data class Server(val message: String) : UiError()
    data class Validation(val fields: Map<String, String>) : UiError()
    data class Unknown(val message: String?) : UiError()
}

fun Throwable.toUiError(): UiError = when (this) {
    is java.net.UnknownHostException -> UiError.Network
    is java.net.SocketTimeoutException -> UiError.Network
    is HttpException -> when (code()) {
        401 -> UiError.Unauthorized
        404 -> UiError.NotFound
        429 -> UiError.RateLimited
        in 400..499 -> parseValidationError(this)
        else -> UiError.Server(message())
    }
    else -> UiError.Unknown(message)
}
```
