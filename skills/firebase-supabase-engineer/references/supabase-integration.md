# Supabase Integration for Android

## SDK Setup (supabase-kt)

```kotlin
// build.gradle.kts (project level)
plugins {
    kotlin("plugin.serialization") version "2.3.20"
}

// build.gradle.kts (app level)
dependencies {
    implementation(platform("io.github.jan-tennert.supabase:bom:3.1.1"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")
    // Ktor engine for Android
    implementation("io.ktor:ktor-client-android:3.1.1")
    // Kotlinx serialization
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
}
```

## Client Initialization

```kotlin
// SupabaseModule.kt (Hilt)
@Module
@InstallIn(SingletonComponent::class)
object SupabaseModule {

    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient {
        return createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY
        ) {
            install(Auth) {
                scheme = "myapp"        // Deep link scheme for OAuth
                host = "callback"
            }
            install(Postgrest)
            install(Storage)
            install(Realtime)
            install(Functions)
        }
    }
}
```

## Authentication

```kotlin
@Serializable
data class UserProfile(
    val id: String,
    val email: String,
    val displayName: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

class SupabaseAuthRepository @Inject constructor(
    private val client: SupabaseClient
) {
    // Email/password sign up
    suspend fun signUp(email: String, password: String) {
        client.auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
    }

    // Email/password sign in
    suspend fun signIn(email: String, password: String) {
        client.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
    }

    // OAuth (Google)
    suspend fun signInWithGoogle(context: Context) {
        client.auth.signInWith(Google) {
            // Opens browser for OAuth flow, returns via deep link
        }
    }

    // Magic link (passwordless)
    suspend fun sendMagicLink(email: String) {
        client.auth.signInWith(OTP) {
            this.email = email
        }
    }

    // Phone OTP
    suspend fun sendPhoneOtp(phone: String) {
        client.auth.signInWith(Phone) {
            this.phone = phone
        }
    }

    suspend fun verifyPhoneOtp(phone: String, token: String) {
        client.auth.verifyPhoneOtp(
            type = OtpType.Phone.SMS,
            phone = phone,
            token = token
        )
    }

    // Session state as Flow
    val sessionStatus: Flow<SessionStatus> = client.auth.sessionStatus

    // Current user
    fun currentUser(): UserInfo? = client.auth.currentUserOrNull()

    // Sign out
    suspend fun signOut() {
        client.auth.signOut()
    }

    // Get access token for API calls
    fun accessToken(): String? = client.auth.currentAccessTokenOrNull()
}
```

## PostgreSQL Queries (PostgREST)

```kotlin
@Serializable
data class Todo(
    val id: Int? = null,
    val title: String,
    val completed: Boolean = false,
    @SerialName("user_id") val userId: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

class TodoRepository @Inject constructor(
    private val client: SupabaseClient
) {
    private val table = client.from("todos")

    // SELECT * FROM todos WHERE user_id = $uid ORDER BY created_at DESC
    suspend fun getTodos(): List<Todo> {
        return table
            .select {
                filter { Todo::userId eq client.auth.currentUserOrNull()?.id }
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Todo>()
    }

    // SELECT * FROM todos WHERE id = $id LIMIT 1
    suspend fun getTodoById(id: Int): Todo {
        return table
            .select {
                filter { Todo::id eq id }
                limit(1)
                single()
            }
            .decodeAs<Todo>()
    }

    // INSERT INTO todos (title, user_id) VALUES ($title, $uid)
    suspend fun createTodo(title: String): Todo {
        return table
            .insert(Todo(title = title, userId = client.auth.currentUserOrNull()?.id)) {
                select()
                single()
            }
            .decodeAs<Todo>()
    }

    // UPDATE todos SET completed = $completed WHERE id = $id
    suspend fun updateTodo(id: Int, completed: Boolean): Todo {
        return table
            .update({ Todo::completed setTo completed }) {
                select()
                filter { Todo::id eq id }
                single()
            }
            .decodeAs<Todo>()
    }

    // DELETE FROM todos WHERE id = $id
    suspend fun deleteTodo(id: Int) {
        table.delete {
            filter { Todo::id eq id }
        }
    }

    // Complex queries
    suspend fun searchTodos(query: String, limit: Int = 20): List<Todo> {
        return table
            .select {
                filter {
                    Todo::title ilike "%$query%"
                    Todo::completed eq false
                }
                limit(limit.toLong())
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Todo>()
    }

    // Pagination
    suspend fun getTodosPaginated(page: Int, pageSize: Int = 20): List<Todo> {
        val from = (page * pageSize).toLong()
        val to = from + pageSize - 1
        return table
            .select {
                range(from, to)
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Todo>()
    }

    // Count
    suspend fun getTodoCount(): Long {
        return table.select {
            count(Count.EXACT)
            filter { Todo::userId eq client.auth.currentUserOrNull()?.id }
        }.countOrNull() ?: 0
    }
}
```

## Real-Time Subscriptions

```kotlin
class RealtimeTodoRepository @Inject constructor(
    private val client: SupabaseClient
) {
    // Subscribe to all changes on todos table
    fun observeTodos(): Flow<List<Todo>> = callbackFlow {
        val todos = mutableListOf<Todo>()

        // Load initial data
        val initial = client.from("todos").select().decodeList<Todo>()
        todos.addAll(initial)
        trySend(todos.toList())

        // Subscribe to changes
        val channel = client.channel("todos-channel")

        val changeFlow = channel.postgresChangeFlow<PostgresAction>("public") {
            table = "todos"
        }

        val job = launch {
            changeFlow.collect { action ->
                when (action) {
                    is PostgresAction.Insert -> {
                        val newTodo = action.decodeRecord<Todo>()
                        todos.add(newTodo)
                    }
                    is PostgresAction.Update -> {
                        val updated = action.decodeRecord<Todo>()
                        val index = todos.indexOfFirst { it.id == updated.id }
                        if (index >= 0) todos[index] = updated
                    }
                    is PostgresAction.Delete -> {
                        val oldRecord = action.decodeOldRecord<Todo>()
                        todos.removeAll { it.id == oldRecord.id }
                    }
                    else -> {}
                }
                trySend(todos.toList())
            }
        }

        channel.subscribe()

        awaitClose {
            job.cancel()
            launch { client.removeChannel(channel) }
        }
    }

    // Subscribe to specific event type only
    fun observeNewTodos(): Flow<Todo> = callbackFlow {
        val channel = client.channel("new-todos")

        val insertFlow = channel.postgresChangeFlow<PostgresAction.Insert>("public") {
            table = "todos"
        }

        val job = launch {
            insertFlow.collect { action ->
                trySend(action.decodeRecord<Todo>())
            }
        }

        channel.subscribe()

        awaitClose {
            job.cancel()
            launch { client.removeChannel(channel) }
        }
    }

    // Broadcast (client-to-client messaging)
    suspend fun sendTypingIndicator(userId: String) {
        val channel = client.channel("typing")
        channel.subscribe()
        channel.broadcast("typing", mapOf("userId" to userId))
    }

    // Presence (track who's online)
    fun observeOnlineUsers(): Flow<List<String>> = callbackFlow {
        val channel = client.channel("online-users")
        val presenceFlow = channel.presenceChangeFlow()

        val job = launch {
            presenceFlow.collect {
                val users = channel.presenceState().map { (_, presences) ->
                    presences.firstOrNull()?.stateAs<Map<String, String>>()?.get("userId") ?: ""
                }.filter { it.isNotEmpty() }
                trySend(users)
            }
        }

        channel.subscribe()
        channel.track(mapOf("userId" to (client.auth.currentUserOrNull()?.id ?: "")))

        awaitClose {
            job.cancel()
            launch {
                channel.untrack()
                client.removeChannel(channel)
            }
        }
    }
}
```

## Storage

```kotlin
class SupabaseStorageRepository @Inject constructor(
    private val client: SupabaseClient
) {
    private val bucket = client.storage.from("avatars")

    // Upload file
    suspend fun uploadAvatar(userId: String, bytes: ByteArray): String {
        val path = "$userId/avatar.jpg"
        bucket.upload(path, bytes) {
            upsert = true
            contentType = ContentType.Image.JPEG
        }
        return bucket.publicUrl(path)
    }

    // Download file
    suspend fun downloadAvatar(userId: String): ByteArray {
        return bucket.downloadAuthenticated("$userId/avatar.jpg")
    }

    // Get signed URL (time-limited access)
    suspend fun getSignedUrl(path: String): String {
        return bucket.createSignedUrl(path, expiresIn = 3600.seconds)
    }

    // Delete file
    suspend fun deleteAvatar(userId: String) {
        bucket.delete("$userId/avatar.jpg")
    }

    // List files in directory
    suspend fun listUserFiles(userId: String): List<BucketItem> {
        return bucket.list(userId)
    }
}
```

## Row Level Security (RLS)

```sql
-- Enable RLS on the table
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- Users can only see their own todos
CREATE POLICY "Users can view own todos"
    ON todos FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own todos
CREATE POLICY "Users can create own todos"
    ON todos FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own todos
CREATE POLICY "Users can update own todos"
    ON todos FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own todos
CREATE POLICY "Users can delete own todos"
    ON todos FOR DELETE
    USING (auth.uid() = user_id);

-- Admins can do anything (uses a custom claim or a roles table)
CREATE POLICY "Admins have full access"
    ON todos FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_roles
            WHERE user_roles.user_id = auth.uid()
            AND user_roles.role = 'admin'
        )
    );
```

## Edge Functions

```typescript
// supabase/functions/send-notification/index.ts
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

serve(async (req: Request) => {
    const { userId, message } = await req.json();

    const supabase = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data, error } = await supabase
        .from("notifications")
        .insert({ user_id: userId, message })
        .select()
        .single();

    if (error) return new Response(JSON.stringify({ error }), { status: 400 });
    return new Response(JSON.stringify(data), {
        headers: { "Content-Type": "application/json" }
    });
});
```

```kotlin
// Call Edge Function from Android
suspend fun callEdgeFunction(userId: String, message: String): String {
    val response = client.functions.invoke("send-notification") {
        body = buildJsonObject {
            put("userId", userId)
            put("message", message)
        }
    }
    return response.body.toString()
}
```

## Database Functions (RPC)

```sql
-- Create a database function
CREATE OR REPLACE FUNCTION get_todo_stats(uid UUID)
RETURNS JSON AS $$
    SELECT json_build_object(
        'total', COUNT(*),
        'completed', COUNT(*) FILTER (WHERE completed = true),
        'pending', COUNT(*) FILTER (WHERE completed = false)
    )
    FROM todos
    WHERE user_id = uid;
$$ LANGUAGE sql SECURITY DEFINER;
```

```kotlin
// Call RPC from Android
@Serializable
data class TodoStats(val total: Int, val completed: Int, val pending: Int)

suspend fun getTodoStats(): TodoStats {
    return client.postgrest.rpc("get_todo_stats", mapOf(
        "uid" to client.auth.currentUserOrNull()?.id
    )).decodeAs<TodoStats>()
}
```

## Using Supabase with Ktor Client

```kotlin
// Custom Ktor client with Supabase auth headers
val httpClient = HttpClient(Android) {
    install(ContentNegotiation) {
        json(Json { ignoreUnknownKeys = true })
    }
    defaultRequest {
        url(BuildConfig.SUPABASE_URL)
        header("apikey", BuildConfig.SUPABASE_ANON_KEY)
        header("Authorization", "Bearer ${supabaseClient.auth.currentAccessTokenOrNull()}")
    }
}

// Direct REST call when supabase-kt doesn't cover your need
suspend fun customQuery(): JsonElement {
    return httpClient.get("/rest/v1/todos") {
        parameter("select", "id,title,completed")
        parameter("completed", "eq.false")
        parameter("order", "created_at.desc")
    }.body()
}
```
