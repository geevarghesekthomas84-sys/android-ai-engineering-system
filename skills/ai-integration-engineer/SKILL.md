---
name: ai-integration-engineer
description: AI integration engineering for Android and full-stack apps covering LLM APIs, chat interfaces, streaming responses, RAG, embeddings, on-device inference, and privacy-aware AI architecture
metadata:
  author: Custom
  keywords:
  - ai
  - llm
  - chat
  - streaming
  - rag
  - embeddings
  - on-device
  - ml-kit
---

# AI Integration Engineer

Specialized skill for building AI-powered Android and full-stack applications. Covers LLM API integration, chat user interfaces, streaming response handling, retrieval-augmented generation, on-device inference, and privacy-aware AI architecture.

## Trigger Conditions

Activate this skill when the task involves any of:

- Building an AI chat feature or conversational interface
- Integrating LLM APIs (Claude, OpenAI, Gemini) into an application
- Implementing on-device ML (ML Kit, MediaPipe, TensorFlow Lite, ONNX Runtime)
- Building a RAG (Retrieval-Augmented Generation) pipeline
- Document processing with AI (extraction, summarization, classification)
- AI-powered search (semantic search, hybrid search, re-ranking)
- Streaming response handling (SSE, WebSocket, chunked transfer)
- Embedding generation, vector storage, or similarity search
- Prompt engineering, tool calling, or function calling
- AI safety, content filtering, or prompt injection defense
- Token management, cost optimization, or usage monitoring

## Capabilities

### Chat and Conversational UI
- Chat message lists with Jetpack Compose (LazyColumn, reversed layout, sticky headers)
- Message bubbles with distinct user/AI styling and timestamps
- Streaming text display with typewriter animation effect
- Markdown rendering inside chat messages (headings, lists, bold, italic, code)
- Code block syntax highlighting with copy-to-clipboard
- Chat input bar with multi-line support, send button, and attachment handling
- Loading indicators, typing animations, and skeleton screens
- Error states with retry actions and offline handling
- Conversation history management and persistence with Room

### LLM API Integration
- Claude API: Messages API, streaming with Server-Sent Events, system prompts, tool use, vision
- OpenAI API: Chat Completions, streaming, function calling, JSON mode, vision
- Gemini API: generateContent, streaming, safety settings, grounding, multimodal
- Server-side proxy architecture with NestJS (TypeScript) or FastAPI (Python)
- API key management with environment variables and secret managers
- Request/response type modeling with kotlinx.serialization
- Error handling with exponential backoff retry logic
- Timeout handling, request cancellation, and circuit breakers

### On-Device Inference
- ML Kit: text recognition (OCR), barcode scanning, face detection, image labeling, translation, smart reply, entity extraction
- MediaPipe: gesture recognition, object detection, face landmarking, pose estimation, image segmentation
- TensorFlow Lite: model loading, interpreter setup, GPU/NNAPI delegates, custom model inference
- ONNX Runtime Mobile: cross-platform model execution, optimization profiles
- Model optimization: quantization (INT8, FP16), pruning, knowledge distillation
- Performance profiling: inference latency, memory footprint, battery impact

### RAG and Embeddings
- Document ingestion: PDF extraction, text chunking (fixed-size, semantic, recursive character splitting)
- Embedding generation: OpenAI text-embedding-3-small/large, sentence-transformers, Cohere embed
- Vector databases: Pinecone, Chroma, pgvector, Qdrant, Weaviate
- Similarity search: cosine similarity, dot product, Euclidean distance, HNSW indexing
- Context window management: token counting, chunk selection, context compression
- Prompt construction: system prompt + retrieved context + user query assembly
- Re-ranking: cross-encoder re-ranking, Cohere Rerank, reciprocal rank fusion
- Hybrid search: combining semantic search with BM25 keyword search

### Tool Calling and Function Calling
- Claude tool use: defining tools with JSON Schema, handling tool_use/tool_result blocks
- OpenAI function calling: function definitions, parallel function calling, forced function calls
- Gemini function declarations: function calling mode, automatic function calling
- Client-side tool execution: parsing tool calls, executing local functions, returning results
- Multi-step agent loops: iterative tool use until task completion

### AI Safety and Security
- Prompt injection prevention: input sanitization, system prompt isolation, output validation
- Content filtering: toxicity detection, NSFW filtering, custom content policies
- PII detection and redaction before sending to external APIs
- Rate limiting per user and per conversation
- Cost controls: token budgets, usage alerts, spending caps
- Monitoring and audit logging for AI interactions
- User feedback collection (thumbs up/down, report, regenerate)

## CRITICAL RULES

1. **Do not expose provider API keys inside Android APKs.** API keys embedded in client-side code can be extracted trivially with `apktool` or `jadx`. Always use a server-side proxy that holds the keys and forwards requests to the LLM provider. The Android app authenticates to your proxy with user-scoped tokens (Firebase Auth, JWT), never with provider API keys.

2. **Validate and sanitize all AI model outputs before rendering.** LLM outputs can contain unexpected content including HTML, JavaScript, or markdown that could be exploited. Sanitize before rendering in WebView; use safe Compose text rendering for chat UIs.

3. **Implement token budgets and cost controls from day one.** Runaway API costs are a real risk. Set per-user and per-request token limits, monitor usage, and implement circuit breakers for cost anomalies.

4. **Never send PII to external AI providers without explicit user consent.** Implement PII detection and redaction in the proxy layer. Log what data flows to which provider for compliance.

## Workflow

Follow this sequence when building an AI-powered feature:

1. **Define the AI feature** -- Identify the user problem, determine what AI capability solves it (generation, classification, extraction, search, conversation), and define success metrics.

2. **Choose the model** -- Select the appropriate model based on task complexity, latency requirements, cost constraints, and privacy needs. Use cheaper/faster models for simple tasks (classification, routing) and more capable models for complex generation.

3. **Design the API proxy** -- Build a server-side proxy (NestJS or FastAPI) that holds API keys, enforces rate limits, logs usage, filters content, and manages costs. Define the contract between the Android client and the proxy.

4. **Implement the client** -- Build the Android networking layer using Retrofit/Ktor, define request/response models with kotlinx.serialization, implement streaming with OkHttp EventSource or Ktor SSE, and handle errors gracefully.

5. **Build the UI** -- Implement the chat interface or AI feature UI in Jetpack Compose. Handle streaming text display, loading states, error states, and user interactions (send, retry, copy, share, feedback).

6. **Add safety layers** -- Implement prompt injection defense, content filtering, PII redaction, output validation, and user feedback mechanisms.

7. **Test thoroughly** -- Test with adversarial inputs, edge cases (empty responses, very long responses, malformed chunks), network failures, and concurrent usage. Validate cost projections with realistic traffic.

8. **Optimize cost and performance** -- Implement response caching, prompt optimization, model routing (use cheap models for simple queries), and monitor token usage. Set up alerts for cost anomalies.

## Reference Files

- `references/llm-apis.md` -- LLM API integration patterns (Claude, OpenAI, Gemini)
- `references/chat-ui.md` -- AI chat UI implementation in Jetpack Compose
- `references/streaming.md` -- Streaming response handling (SSE, WebSocket, Flow)
- `references/rag-architecture.md` -- RAG pipeline architecture and implementation
- `references/on-device-ml.md` -- On-device ML with ML Kit, MediaPipe, TFLite
- `references/ai-safety.md` -- AI safety, security, and prompt injection defense
- `references/cost-optimization.md` -- Token management and cost optimization
