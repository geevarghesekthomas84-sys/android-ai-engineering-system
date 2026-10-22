# Streaming Response Handling

## Server-Sent Events (SSE) with OkHttp

OkHttp's `EventSource` is the most reliable way to consume SSE on Android.

```kotlin
class SseStreamingClient(private val client: OkHttpClient) {

    fun streamChat(
        baseUrl: String,
        messages: List<Message>,
        authToken: String,
    ): Flow<StreamEvent> = callbackFlow {
        val requestBody = Json.encodeToString(
            ChatRequest(messages = messages, stream = true)
        ).toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("$baseUrl/api/chat")
            .header("Authorization", "Bearer $authToken")
            .post(requestBody)
            .build()

        val eventSource = EventSources.createFactory(client)
            .newEventSource(request, object : EventSourceListener() {
                override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
                    if (data == "[DONE]") {
                        trySend(StreamEvent.Done)
                        close()
                        return
                    }
                    try {
                        val chunk = Json.decodeFromString<StreamChunk>(data)
                        trySend(StreamEvent.TextDelta(chunk.text))
                    } catch (e: Exception) {
                        trySend(StreamEvent.Error(e))
                    }
                }

                override fun onFailure(eventSource: EventSource, t: Throwable?, response: Response?) {
                    val error = t ?: IOException("SSE connection failed: ${response?.code}")
                    trySend(StreamEvent.Error(error))
                    close(error)
                }

                override fun onClosed(eventSource: EventSource) {
                    close()
                }
            })

        awaitClose { eventSource.cancel() }
    }
}

sealed interface StreamEvent {
    data class TextDelta(val text: String) : StreamEvent
    data object Done : StreamEvent
    data class Error(val cause: Throwable) : StreamEvent
}
```

## SSE with Ktor Client

```kotlin
class KtorStreamingClient(private val httpClient: HttpClient) {

    fun streamChat(messages: List<Message>): Flow<String> = flow {
        httpClient.preparePost("/api/chat") {
            contentType(ContentType.Application.Json)
            setBody(ChatRequest(messages = messages, stream = true))
        }.execute { response ->
            val channel = response.bodyAsChannel()
            val buffer = StringBuilder()

            while (!channel.isClosedForRead) {
                val line = channel.readUTF8Line() ?: break

                when {
                    line.startsWith("data: [DONE]") -> break
                    line.startsWith("data: ") -> {
                        val data = line.removePrefix("data: ")
                        val chunk = Json.decodeFromString<StreamChunk>(data)
                        emit(chunk.text)
                    }
                    line.isEmpty() -> continue // SSE blank line separator
                }
            }
        }
    }.flowOn(Dispatchers.IO)
}
```

## Streaming with Retrofit (ResponseBody + Flow)

For projects already using Retrofit, consume raw `ResponseBody` as a flow.

```kotlin
interface AiApiService {
    @POST("api/chat")
    @Streaming
    suspend fun streamChat(@Body request: ChatRequest): ResponseBody
}

fun ResponseBody.toSseFlow(): Flow<String> = flow {
    source().use { source ->
        val buffer = okio.Buffer()
        while (!source.exhausted()) {
            source.read(buffer, 8192)
            val text = buffer.readUtf8()
            for (line in text.lines()) {
                when {
                    line.startsWith("data: [DONE]") -> return@flow
                    line.startsWith("data: ") -> {
                        val data = line.removePrefix("data: ")
                        val chunk = Json.decodeFromString<StreamChunk>(data)
                        emit(chunk.text)
                    }
                }
            }
        }
    }
}.flowOn(Dispatchers.IO)

// Usage in repository
class ChatRepositoryImpl @Inject constructor(
    private val api: AiApiService,
) : ChatRepository {
    override fun sendMessageStream(messages: List<Message>): Flow<String> = flow {
        val response = api.streamChat(ChatRequest(messages = messages, stream = true))
        emitAll(response.toSseFlow())
    }
}
```

## WebSocket-Based Streaming

Use WebSocket when you need bidirectional communication (typing indicators, interruptions).

```kotlin
class WebSocketStreamingClient(private val client: OkHttpClient) {

    fun connect(url: String, authToken: String): Flow<StreamEvent> = callbackFlow {
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $authToken")
            .build()

        val webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) {
                val event = Json.decodeFromString<WsEvent>(text)
                when (event.type) {
                    "text_delta" -> trySend(StreamEvent.TextDelta(event.text ?: ""))
                    "done" -> trySend(StreamEvent.Done)
                    "error" -> trySend(StreamEvent.Error(Exception(event.error)))
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                trySend(StreamEvent.Error(t))
                close(t)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { close() }
        })

        awaitClose { webSocket.close(1000, "Client closed") }
    }

    fun sendMessage(webSocket: WebSocket, message: String) {
        webSocket.send(Json.encodeToString(WsMessage("user_message", message)))
    }

    // Interrupt generation
    fun cancelGeneration(webSocket: WebSocket) {
        webSocket.send(Json.encodeToString(WsMessage("cancel", null)))
    }
}
```

## Buffering and Display

Accumulate text deltas into a `StateFlow` for smooth UI updates.

```kotlin
class StreamBuffer {
    private val _text = MutableStateFlow("")
    val text: StateFlow<String> = _text.asStateFlow()

    private val buffer = StringBuilder()
    private val mutex = Mutex()

    suspend fun append(chunk: String) {
        mutex.withLock {
            buffer.append(chunk)
            _text.value = buffer.toString()
        }
    }

    fun reset() {
        buffer.clear()
        _text.value = ""
    }

    fun getFullText(): String = buffer.toString()
}
```

## Error Handling and Reconnection

```kotlin
fun <T> Flow<T>.retryWithExponentialBackoff(
    maxRetries: Int = 3,
    initialDelayMs: Long = 1000,
): Flow<T> = retryWhen { cause, attempt ->
    if (attempt >= maxRetries) false
    else if (cause is IOException || (cause is HttpException && cause.code() in listOf(429, 500, 502, 503))) {
        val delay = initialDelayMs * 2.0.pow(attempt.toDouble()).toLong()
        delay(delay + Random.nextLong(0, delay / 4))
        true
    } else false
}

// Usage
chatRepository.sendMessageStream(messages)
    .retryWithExponentialBackoff(maxRetries = 2)
    .catch { e -> emit("[Error: ${e.message}]") }
    .collect { chunk -> streamBuffer.append(chunk) }
```

## Cancellation

Always support cancelling ongoing generation.

```kotlin
class ChatViewModel : ViewModel() {
    private var streamJob: Job? = null

    fun sendMessage(text: String) {
        streamJob?.cancel() // cancel any in-progress stream
        streamJob = viewModelScope.launch {
            chatRepository.sendMessageStream(messages)
                .collect { chunk ->
                    _uiState.update { it.copy(streamingText = (it.streamingText ?: "") + chunk) }
                }
        }
    }

    fun cancelGeneration() {
        streamJob?.cancel()
        streamJob = null
        _uiState.update { state ->
            val partial = state.streamingText
            if (partial != null) {
                val msg = ChatMessage(role = Role.ASSISTANT, content = partial + " [cancelled]")
                state.copy(messages = state.messages + msg, isLoading = false, streamingText = null)
            } else state.copy(isLoading = false)
        }
    }
}
```

## Backpressure with Flow

Use `buffer()` and `conflate()` to keep the UI responsive when chunks arrive faster than rendering.

```kotlin
chatRepository.sendMessageStream(messages)
    .buffer(Channel.BUFFERED) // buffer chunks if UI is slow
    .scan("") { accumulated, chunk -> accumulated + chunk } // running accumulation
    .conflate() // drop intermediate states if UI is behind
    .collect { fullText ->
        _uiState.update { it.copy(streamingText = fullText) }
    }
```
