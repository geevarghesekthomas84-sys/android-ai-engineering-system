# LLM API Integration Patterns

## Server-Side Proxy Architecture

Never call LLM APIs directly from Android. Always route through a server-side proxy.

### FastAPI Proxy (Python)

```python
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import anthropic
import openai
import httpx
import os

app = FastAPI()

claude_client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
openai_client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

class ChatRequest(BaseModel):
    messages: list[dict]
    model: str = "claude-sonnet-4-20250514"
    max_tokens: int = 1024
    stream: bool = False

@app.post("/api/chat")
async def chat(request: ChatRequest, user_id: str = Depends(get_current_user)):
    # Enforce token budget
    if not await check_token_budget(user_id, request.max_tokens):
        raise HTTPException(429, "Token budget exceeded")

    if request.stream:
        return StreamingResponse(
            stream_claude_response(request, user_id),
            media_type="text/event-stream",
        )

    response = claude_client.messages.create(
        model=request.model,
        max_tokens=request.max_tokens,
        system="You are a helpful assistant.",
        messages=request.messages,
    )
    await log_usage(user_id, response.usage.input_tokens, response.usage.output_tokens)
    return {"content": response.content[0].text, "usage": response.usage}

async def stream_claude_response(request: ChatRequest, user_id: str):
    with claude_client.messages.stream(
        model=request.model,
        max_tokens=request.max_tokens,
        system="You are a helpful assistant.",
        messages=request.messages,
    ) as stream:
        for text in stream.text_stream:
            yield f"data: {json.dumps({'type': 'content_block_delta', 'text': text})}\n\n"
        yield "data: [DONE]\n\n"
```

### NestJS Proxy (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";
import { Controller, Post, Body, Sse } from "@nestjs/common";
import { Observable } from "rxjs";

@Controller("api/chat")
export class ChatController {
  private claude = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

  @Post()
  @Sse()
  async streamChat(@Body() request: ChatRequest): Promise<Observable<MessageEvent>> {
    return new Observable((subscriber) => {
      this.claude.messages
        .stream({
          model: request.model ?? "claude-sonnet-4-20250514",
          max_tokens: request.maxTokens ?? 1024,
          system: "You are a helpful assistant.",
          messages: request.messages,
        })
        .on("text", (text) => {
          subscriber.next({ data: JSON.stringify({ type: "delta", text }) });
        })
        .on("end", () => {
          subscriber.next({ data: "[DONE]" });
          subscriber.complete();
        })
        .on("error", (err) => subscriber.error(err));
    });
  }
}
```

## Claude API (Messages API)

### Request Structure

```kotlin
@Serializable
data class ClaudeRequest(
    val model: String = "claude-sonnet-4-20250514",
    @SerialName("max_tokens") val maxTokens: Int = 1024,
    val system: String? = null,
    val messages: List<Message>,
    val tools: List<Tool>? = null,
    val stream: Boolean = false,
)

@Serializable
data class Message(
    val role: String, // "user" or "assistant"
    val content: String,
)

@Serializable
data class Tool(
    val name: String,
    val description: String,
    @SerialName("input_schema") val inputSchema: JsonObject,
)
```

### Tool Use

```kotlin
// Define a tool
val weatherTool = Tool(
    name = "get_weather",
    description = "Get current weather for a location",
    inputSchema = buildJsonObject {
        put("type", "object")
        putJsonObject("properties") {
            putJsonObject("location") {
                put("type", "string")
                put("description", "City name")
            }
        }
        putJsonArray("required") { add("location") }
    }
)

// Handle tool_use in response
when (val block = response.content.first()) {
    is TextBlock -> displayText(block.text)
    is ToolUseBlock -> {
        val result = executeToolCall(block.name, block.input)
        // Send tool_result back to continue conversation
        val followUp = listOf(
            Message("assistant", response.content),
            Message("user", listOf(ToolResultBlock(block.id, result)))
        )
    }
}
```

## OpenAI API (Chat Completions)

```kotlin
@Serializable
data class OpenAIRequest(
    val model: String = "gpt-4o",
    val messages: List<OpenAIMessage>,
    val stream: Boolean = false,
    val functions: List<FunctionDef>? = null,
    @SerialName("response_format") val responseFormat: ResponseFormat? = null,
)

@Serializable
data class OpenAIMessage(
    val role: String, // "system", "user", "assistant", "function"
    val content: String?,
    @SerialName("function_call") val functionCall: FunctionCall? = null,
)
```

## Gemini API (generateContent)

```kotlin
// Using the Google AI SDK for Android
val generativeModel = GenerativeModel(
    modelName = "gemini-2.0-flash",
    apiKey = BuildConfig.GEMINI_API_KEY, // Only for prototyping; use proxy in production
    safetySettings = listOf(
        SafetySetting(HarmCategory.HARASSMENT, BlockThreshold.MEDIUM_AND_ABOVE),
        SafetySetting(HarmCategory.HATE_SPEECH, BlockThreshold.MEDIUM_AND_ABOVE),
    ),
)

// Streaming
generativeModel.generateContentStream(content { text("Explain quantum computing") })
    .collect { chunk ->
        chunk.text?.let { appendToUI(it) }
    }
```

## Common Patterns

### Error Handling with Retry

```kotlin
suspend fun <T> retryWithBackoff(
    maxRetries: Int = 3,
    initialDelayMs: Long = 1000,
    maxDelayMs: Long = 30000,
    retryableStatusCodes: Set<Int> = setOf(429, 500, 502, 503, 529),
    block: suspend () -> T,
): T {
    var currentDelay = initialDelayMs
    repeat(maxRetries) { attempt ->
        try {
            return block()
        } catch (e: HttpException) {
            if (e.code() !in retryableStatusCodes || attempt == maxRetries - 1) throw e
            if (e.code() == 429) {
                val retryAfter = e.response()?.headers()?.get("retry-after")?.toLongOrNull()
                currentDelay = retryAfter?.times(1000) ?: currentDelay
            }
            delay(currentDelay + Random.nextLong(0, currentDelay / 4))
            currentDelay = (currentDelay * 2).coerceAtMost(maxDelayMs)
        }
    }
    throw IllegalStateException("Unreachable")
}
```

### Request/Response Logging

```kotlin
class AiLoggingInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val startTime = System.currentTimeMillis()
        val response = chain.proceed(request)
        val duration = System.currentTimeMillis() - startTime

        Log.d("AI_API", buildString {
            append("${request.method} ${request.url} -> ${response.code} (${duration}ms)")
            response.header("x-ratelimit-remaining")?.let {
                append(" | rate-limit-remaining: $it")
            }
        })
        return response
    }
}
```

### Timeout Configuration

```kotlin
val aiHttpClient = OkHttpClient.Builder()
    .connectTimeout(10, TimeUnit.SECONDS)
    .readTimeout(120, TimeUnit.SECONDS)   // Long timeout for generation
    .writeTimeout(30, TimeUnit.SECONDS)
    .addInterceptor(AiLoggingInterceptor())
    .addInterceptor(HttpLoggingInterceptor().apply {
        level = if (BuildConfig.DEBUG) Level.BODY else Level.BASIC
    })
    .build()
```
