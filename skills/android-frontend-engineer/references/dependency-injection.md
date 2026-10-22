# Hilt Dependency Injection for Android

## Project Setup

```kotlin
// build.gradle.kts (project)
plugins {
    id("com.google.dagger.hilt.android") version "2.56.2" apply false
    id("com.google.devtools.ksp") version "2.3.20-1.0.31" apply false
}

// build.gradle.kts (app)
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

dependencies {
    implementation("com.google.dagger:hilt-android:2.56.2")
    ksp("com.google.dagger:hilt-compiler:2.56.2")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

    // Testing
    testImplementation("com.google.dagger:hilt-android-testing:2.56.2")
    kspTest("com.google.dagger:hilt-compiler:2.56.2")
    androidTestImplementation("com.google.dagger:hilt-android-testing:2.56.2")
    kspAndroidTest("com.google.dagger:hilt-compiler:2.56.2")
}
```

## Application Setup

```kotlin
@HiltAndroidApp
class MyApp : Application()
```

```xml
<!-- AndroidManifest.xml -->
<application
    android:name=".MyApp"
    ... />
```

## Activity and Fragment Entry Points

```kotlin
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MyAppTheme {
                AppNavigation()
            }
        }
    }
}
```

## Constructor Injection

The simplest form. Hilt automatically provides dependencies if their constructors are also `@Inject`-annotated.

```kotlin
class TaskRepositoryImpl @Inject constructor(
    private val taskApi: TaskApi,
    private val taskDao: TaskDao,
    private val dispatcher: CoroutineDispatcher,
) : TaskRepository {
    override fun observeTasks(): Flow<List<Task>> =
        taskDao.observeAll().map { entities -> entities.map { it.toDomain() } }
}
```

## Modules with @Provides and @Binds

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
    ): OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(authInterceptor)
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        })
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit = Retrofit.Builder()
        .baseUrl("https://api.example.com/")
        .client(okHttpClient)
        .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
        .build()

    @Provides
    @Singleton
    fun provideTaskApi(retrofit: Retrofit): TaskApi =
        retrofit.create(TaskApi::class.java)
}

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun provideTaskDao(database: AppDatabase): TaskDao = database.taskDao()
}
```

## @Binds for Interface Binding

More efficient than `@Provides` for simple interface-to-implementation mappings. Must be in an abstract module.

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindTaskRepository(impl: TaskRepositoryImpl): TaskRepository

    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository

    @Binds
    @Singleton
    abstract fun bindAuthManager(impl: AuthManagerImpl): AuthManager
}
```

## Scoping

| Annotation | Scope | Lifecycle |
|---|---|---|
| `@Singleton` | `SingletonComponent` | Application lifetime |
| `@ActivityRetainedScoped` | `ActivityRetainedComponent` | Survives config changes |
| `@ViewModelScoped` | `ViewModelComponent` | ViewModel lifetime |
| `@ActivityScoped` | `ActivityComponent` | Activity lifetime |
| `@FragmentScoped` | `FragmentComponent` | Fragment lifetime |

```kotlin
@Module
@InstallIn(ViewModelComponent::class)
object ViewModelModule {

    @Provides
    @ViewModelScoped
    fun provideGetTasksUseCase(
        taskRepository: TaskRepository,
    ): GetTasksUseCase = GetTasksUseCase(taskRepository)
}
```

## Qualifiers

Use qualifiers to provide multiple bindings of the same type.

```kotlin
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IoDispatcher

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class DefaultDispatcher

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class MainDispatcher

@Module
@InstallIn(SingletonComponent::class)
object DispatcherModule {

    @Provides
    @IoDispatcher
    fun provideIoDispatcher(): CoroutineDispatcher = Dispatchers.IO

    @Provides
    @DefaultDispatcher
    fun provideDefaultDispatcher(): CoroutineDispatcher = Dispatchers.Default

    @Provides
    @MainDispatcher
    fun provideMainDispatcher(): CoroutineDispatcher = Dispatchers.Main
}

// Usage in constructor
class TaskRepositoryImpl @Inject constructor(
    private val taskApi: TaskApi,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : TaskRepository
```

## Hilt with Compose — hiltViewModel()

```kotlin
@Composable
fun TaskListScreen(
    viewModel: TaskListViewModel = hiltViewModel(),
    onNavigateToDetail: (String) -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    // ...
}

// ViewModel with @HiltViewModel
@HiltViewModel
class TaskListViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {
    // Hilt provides all constructor dependencies automatically
}
```

## Multi-Module Setup

Each feature module declares its own Hilt modules. Hilt discovers them at compile time via annotation processing.

```kotlin
// :core:data module
@Module
@InstallIn(SingletonComponent::class)
abstract class CoreDataModule {
    @Binds
    @Singleton
    abstract fun bindTokenStore(impl: TokenStoreImpl): TokenStore
}

// :feature:tasks module
@Module
@InstallIn(SingletonComponent::class)
abstract class TaskModule {
    @Binds
    @Singleton
    abstract fun bindTaskRepository(impl: TaskRepositoryImpl): TaskRepository
}

// :feature:auth module
@Module
@InstallIn(SingletonComponent::class)
abstract class AuthModule {
    @Binds
    @Singleton
    abstract fun bindAuthManager(impl: AuthManagerImpl): AuthManager
}
```

KSP must be applied in every module that contains `@Module`, `@HiltViewModel`, or `@AndroidEntryPoint`.

```kotlin
// build.gradle.kts for a feature module
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

dependencies {
    implementation("com.google.dagger:hilt-android:2.56.2")
    ksp("com.google.dagger:hilt-compiler:2.56.2")
}
```

## Testing with Hilt

### Unit Tests (ViewModel)

No Hilt needed — just pass fakes directly.

```kotlin
class TaskListViewModelTest {
    private val fakeRepository = FakeTaskRepository()
    private val viewModel = TaskListViewModel(
        taskRepository = fakeRepository,
        savedStateHandle = SavedStateHandle(),
    )

    @Test
    fun `loading state is emitted initially`() = runTest {
        val state = viewModel.uiState.first()
        assertThat(state).isInstanceOf(TaskListUiState.Loading::class.java)
    }
}
```

### Android Instrumented Tests

```kotlin
@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class TaskListScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @BindValue
    val taskRepository: TaskRepository = FakeTaskRepository()

    @Before
    fun setup() {
        hiltRule.inject()
    }

    @Test
    fun showsTasks_whenLoaded() {
        (taskRepository as FakeTaskRepository).emit(listOf(Task("1", "Buy groceries")))
        composeRule.onNodeWithText("Buy groceries").assertIsDisplayed()
    }
}
```

### Custom Test Runner

```kotlin
// In app/src/androidTest
class HiltTestRunner : AndroidJUnitRunner() {
    override fun newApplication(
        cl: ClassLoader?,
        className: String?,
        context: Context?,
    ): Application = Instrumentation.newApplication(HiltTestApplication::class.java, context)
}
```

```kotlin
// build.gradle.kts
android {
    defaultConfig {
        testInstrumentationRunner = "com.example.HiltTestRunner"
    }
}
```

## @EntryPoint for Non-Hilt Classes

When you need Hilt dependencies in classes that Hilt does not inject (e.g., ContentProvider, WorkManager initializer).

```kotlin
@EntryPoint
@InstallIn(SingletonComponent::class)
interface AppInitializerEntryPoint {
    fun analyticsTracker(): AnalyticsTracker
    fun authManager(): AuthManager
}

// Usage
class MyContentProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        val entryPoint = EntryPointAccessors.fromApplication(
            context!!.applicationContext,
            AppInitializerEntryPoint::class.java,
        )
        val analytics = entryPoint.analyticsTracker()
        return true
    }
}
```
