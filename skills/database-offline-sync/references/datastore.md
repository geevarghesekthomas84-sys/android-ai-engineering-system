# DataStore Guide

## Dependencies

```kotlin
dependencies {
    // Preferences DataStore
    implementation("androidx.datastore:datastore-preferences:1.1.7")
    // Proto DataStore
    implementation("androidx.datastore:datastore:1.1.7")
    // Protobuf lite runtime (for Proto DataStore)
    implementation("com.google.protobuf:protobuf-javalite:4.29.3")
}

// For Proto DataStore, add protobuf plugin
plugins {
    id("com.google.protobuf") version "0.9.4"
}

protobuf {
    protoc { artifact = "com.google.protobuf:protoc:4.29.3" }
    generateProtoTasks {
        all().forEach { task ->
            task.builtins { id("java") { option("lite") } }
        }
    }
}
```

## Preferences DataStore

### Creating the DataStore

```kotlin
// Top-level declaration (singleton per file, at module level)
val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "settings"
)

// Define keys
object PreferenceKeys {
    val DARK_MODE = booleanPreferencesKey("dark_mode")
    val FONT_SIZE = intPreferencesKey("font_size")
    val AUTH_TOKEN = stringPreferencesKey("auth_token")
    val LAST_SYNC = longPreferencesKey("last_sync_timestamp")
    val SELECTED_TAGS = stringSetPreferencesKey("selected_tags")
}
```

### Reading with Flow

```kotlin
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    val darkModeFlow: Flow<Boolean> = context.settingsDataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map { preferences ->
            preferences[PreferenceKeys.DARK_MODE] ?: false
        }

    val userSettingsFlow: Flow<UserSettings> = context.settingsDataStore.data
        .catch { if (it is IOException) emit(emptyPreferences()) else throw it }
        .map { prefs ->
            UserSettings(
                darkMode = prefs[PreferenceKeys.DARK_MODE] ?: false,
                fontSize = prefs[PreferenceKeys.FONT_SIZE] ?: 14,
                lastSync = prefs[PreferenceKeys.LAST_SYNC] ?: 0L
            )
        }
}

data class UserSettings(
    val darkMode: Boolean,
    val fontSize: Int,
    val lastSync: Long
)
```

### Writing with edit

```kotlin
suspend fun setDarkMode(enabled: Boolean) {
    context.settingsDataStore.edit { prefs ->
        prefs[PreferenceKeys.DARK_MODE] = enabled
    }
}

suspend fun updateLastSync() {
    context.settingsDataStore.edit { prefs ->
        prefs[PreferenceKeys.LAST_SYNC] = System.currentTimeMillis()
    }
}

suspend fun clearAll() {
    context.settingsDataStore.edit { it.clear() }
}
```

### Migration from SharedPreferences

```kotlin
val Context.settingsDataStore by preferencesDataStore(
    name = "settings",
    produceMigrations = { context ->
        listOf(SharedPreferencesMigration(context, "old_shared_prefs_name"))
    }
)
// SharedPreferences file is deleted after migration completes successfully
```

## Proto DataStore

### Protobuf Schema (src/main/proto/user_preferences.proto)

```protobuf
syntax = "proto3";

option java_package = "com.example.app.data";
option java_multiple_files = true;

message UserPreferences {
    bool dark_mode = 1;
    int32 font_size = 2;
    string language = 3;
    SortOrder sort_order = 4;
    repeated string favorite_ids = 5;

    enum SortOrder {
        UNSPECIFIED = 0;
        BY_NAME = 1;
        BY_DATE = 2;
        BY_PRIORITY = 3;
    }
}
```

### Serializer

```kotlin
object UserPreferencesSerializer : Serializer<UserPreferences> {
    override val defaultValue: UserPreferences = UserPreferences.getDefaultInstance()

    override suspend fun readFrom(input: InputStream): UserPreferences {
        try {
            return UserPreferences.parseFrom(input)
        } catch (e: InvalidProtocolBufferException) {
            throw CorruptionException("Cannot read proto.", e)
        }
    }

    override suspend fun writeTo(t: UserPreferences, output: OutputStream) {
        t.writeTo(output)
    }
}
```

### Creating Proto DataStore

```kotlin
val Context.userPreferencesStore: DataStore<UserPreferences> by dataStore(
    fileName = "user_preferences.pb",
    serializer = UserPreferencesSerializer
)
```

### Reading and Writing

```kotlin
class UserPreferencesRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    val preferencesFlow: Flow<UserPreferences> = context.userPreferencesStore.data
        .catch { if (it is IOException) emit(UserPreferences.getDefaultInstance()) else throw it }

    suspend fun setDarkMode(enabled: Boolean) {
        context.userPreferencesStore.updateData { prefs ->
            prefs.toBuilder().setDarkMode(enabled).build()
        }
    }

    suspend fun setSortOrder(order: UserPreferences.SortOrder) {
        context.userPreferencesStore.updateData { prefs ->
            prefs.toBuilder().setSortOrder(order).build()
        }
    }

    suspend fun addFavorite(id: String) {
        context.userPreferencesStore.updateData { prefs ->
            prefs.toBuilder().addFavoriteIds(id).build()
        }
    }
}
```

## Hilt Integration

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DataStoreModule {
    @Provides
    @Singleton
    fun providePreferencesDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
        context.settingsDataStore

    @Provides
    @Singleton
    fun provideUserPreferencesDataStore(@ApplicationContext context: Context): DataStore<UserPreferences> =
        context.userPreferencesStore
}
```

## DataStore vs SharedPreferences

| Feature | DataStore | SharedPreferences |
|---|---|---|
| Async API | Flow + suspend | Synchronous (can block UI) |
| Thread safety | Safe by default | apply() async, commit() blocks |
| Error handling | Flow catch | No error signaling |
| Type safety | Proto: full type safety | Strings/primitives only |
| Migration | Built-in migration API | Manual |
| Multi-process | Supported (1.1+) | MODE_MULTI_PROCESS deprecated |
| Schema evolution | Proto: backward compatible | Manual versioning |

## Error Handling

DataStore throws IOException on disk read/write failures. Always catch in the Flow:

```kotlin
val data: Flow<Settings> = dataStore.data
    .catch { exception ->
        if (exception is IOException) {
            // Log and emit default
            Log.e("DataStore", "Error reading preferences", exception)
            emit(emptyPreferences())
        } else {
            throw exception
        }
    }
    .map { /* transform */ }
```

## Multi-Process DataStore

```kotlin
val Context.multiProcessDataStore by dataStore(
    fileName = "multi_process_prefs.pb",
    serializer = UserPreferencesSerializer,
    corruptionHandler = ReplaceFileCorruptionHandler { UserPreferences.getDefaultInstance() },
    produceMigrations = { listOf() },
    scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
)
// Multi-process safety is supported in DataStore 1.1+ by default for file-based DataStore
```
