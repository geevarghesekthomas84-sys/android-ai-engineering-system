# Android Architecture Patterns

## MVVM with Clean Architecture

### Layer Structure
```
app/src/main/java/com/example/app/
├── di/                    # Hilt modules
│   ├── AppModule.kt
│   ├── DatabaseModule.kt
│   └── NetworkModule.kt
├── data/
│   ├── local/
│   │   ├── AppDatabase.kt
│   │   ├── dao/
│   │   └── entity/
│   ├── remote/
│   │   ├── api/
│   │   ├── dto/
│   │   └── interceptor/
│   └── repository/        # Repository implementations
├── domain/
│   ├── model/             # Domain models
│   ├── repository/        # Repository interfaces
│   └── usecase/           # Use cases
└── ui/
    ├── theme/
    ├── navigation/
    ├── common/            # Shared composables
    └── feature/           # Feature screens
        ├── home/
        │   ├── HomeScreen.kt
        │   └── HomeViewModel.kt
        └── detail/
            ├── DetailScreen.kt
            └── DetailViewModel.kt
```

### Key Principles
- **UI layer** observes state from ViewModels. No business logic in composables.
- **Domain layer** contains business logic in use cases. Depends on nothing.
- **Data layer** implements repository interfaces, manages data sources.
- Dependencies flow inward: UI → Domain ← Data.
- Domain models are separate from DTOs and entities.

## Hilt Dependency Injection

### Setup in build.gradle.kts (project)
```kotlin
plugins {
    id("com.google.dagger.hilt.android") version "2.53.1" apply false
    id("com.google.devtools.ksp") version "2.1.0-1.0.29" apply false
}
```

### Setup in build.gradle.kts (app)
```kotlin
plugins {
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

dependencies {
    implementation("com.google.dagger:hilt-android:2.53.1")
    ksp("com.google.dagger:hilt-compiler:2.53.1")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")
}
```

### Application Class
```kotlin
@HiltAndroidApp
class MyApplication : Application()
```

### Activity
```kotlin
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppTheme { MainNavigation() }
        }
    }
}
```

### Module Example
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            })
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl("https://api.example.com/")
            .client(okHttpClient)
            .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
            .build()
    }

    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService {
        return retrofit.create(ApiService::class.java)
    }
}

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
            .build()
    }

    @Provides
    fun provideUserDao(database: AppDatabase): UserDao = database.userDao()
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}
```

### ViewModel with Hilt
```kotlin
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val getUsersUseCase: GetUsersUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow<HomeUiState>(HomeUiState.Loading)
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init { loadUsers() }

    fun loadUsers() {
        viewModelScope.launch {
            _uiState.value = HomeUiState.Loading
            getUsersUseCase()
                .catch { e -> _uiState.value = HomeUiState.Error(e.message ?: "Error") }
                .collect { users -> _uiState.value = HomeUiState.Success(users) }
        }
    }
}
```

### Injecting ViewModel in Compose
```kotlin
@Composable
fun HomeScreen(viewModel: HomeViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    // Use uiState
}
```

## Navigation Compose

### Type-Safe Routes
```kotlin
// Define routes as serializable classes
@Serializable data object Home
@Serializable data object Settings
@Serializable data class UserDetail(val userId: String)

// Navigation graph
@Composable
fun AppNavGraph(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = Home) {
        composable<Home> {
            HomeScreen(
                onUserClick = { userId -> navController.navigate(UserDetail(userId)) },
                onSettingsClick = { navController.navigate(Settings) }
            )
        }
        composable<UserDetail> { backStackEntry ->
            val route = backStackEntry.toRoute<UserDetail>()
            UserDetailScreen(userId = route.userId)
        }
        composable<Settings> { SettingsScreen() }
    }
}
```

## Room Database

### Entity
```kotlin
@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "user_name") val name: String,
    val email: String,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis()
)
```

### DAO
```kotlin
@Dao
interface UserDao {
    @Query("SELECT * FROM users ORDER BY user_name ASC")
    fun getAll(): Flow<List<UserEntity>>

    @Query("SELECT * FROM users WHERE id = :id")
    suspend fun getById(id: String): UserEntity?

    @Upsert
    suspend fun upsert(user: UserEntity)

    @Delete
    suspend fun delete(user: UserEntity)
}
```

### Database
```kotlin
@Database(entities = [UserEntity::class], version = 1, exportSchema = true)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
}
```

## Retrofit API Layer

### API Service
```kotlin
interface ApiService {
    @GET("users")
    suspend fun getUsers(): List<UserDto>

    @GET("users/{id}")
    suspend fun getUser(@Path("id") id: String): UserDto

    @POST("users")
    suspend fun createUser(@Body user: CreateUserRequest): UserDto
}
```

### DTO and Mapper
```kotlin
@Serializable
data class UserDto(
    val id: String,
    @SerialName("user_name") val name: String,
    val email: String
)

fun UserDto.toDomain() = User(id = id, name = name, email = email)
fun UserEntity.toDomain() = User(id = id, name = name, email = email)
fun User.toEntity() = UserEntity(id = id, name = name, email = email)
```

## Repository Pattern (Offline-First)

```kotlin
interface UserRepository {
    fun getUsers(): Flow<List<User>>
    suspend fun refreshUsers()
    suspend fun getUser(id: String): User?
}

class UserRepositoryImpl @Inject constructor(
    private val api: ApiService,
    private val dao: UserDao
) : UserRepository {

    override fun getUsers(): Flow<List<User>> {
        return dao.getAll().map { entities -> entities.map { it.toDomain() } }
    }

    override suspend fun refreshUsers() {
        val remoteUsers = api.getUsers()
        dao.upsert(*remoteUsers.map { it.toDomain().toEntity() }.toTypedArray())
    }

    override suspend fun getUser(id: String): User? {
        return dao.getById(id)?.toDomain()
            ?: api.getUser(id).toDomain().also { dao.upsert(it.toEntity()) }
    }
}
```

## Use Cases

```kotlin
class GetUsersUseCase @Inject constructor(
    private val repository: UserRepository
) {
    operator fun invoke(): Flow<List<User>> = repository.getUsers()
}

class RefreshUsersUseCase @Inject constructor(
    private val repository: UserRepository
) {
    suspend operator fun invoke() = repository.refreshUsers()
}
```

## DataStore Preferences

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DataStoreModule {
    @Provides
    @Singleton
    fun provideDataStore(@ApplicationContext context: Context): DataStore<Preferences> {
        return PreferenceDataStoreFactory.create {
            context.preferencesDataStoreFile("settings")
        }
    }
}

class SettingsRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>
) {
    private val DARK_MODE_KEY = booleanPreferencesKey("dark_mode")

    val isDarkMode: Flow<Boolean> = dataStore.data.map { prefs ->
        prefs[DARK_MODE_KEY] ?: false
    }

    suspend fun setDarkMode(enabled: Boolean) {
        dataStore.edit { prefs -> prefs[DARK_MODE_KEY] = enabled }
    }
}
```
