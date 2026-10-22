# AI Chat UI in Jetpack Compose

## Chat Screen Architecture

```kotlin
@Composable
fun ChatScreen(viewModel: ChatViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()

    // Auto-scroll to bottom when new messages arrive
    LaunchedEffect(uiState.messages.size, uiState.streamingText) {
        if (uiState.messages.isNotEmpty()) {
            listState.animateScrollToItem(0) // index 0 is bottom in reversed list
        }
    }

    Scaffold(
        bottomBar = {
            ChatInputBar(
                onSend = viewModel::sendMessage,
                isLoading = uiState.isLoading,
                enabled = !uiState.isLoading,
            )
        }
    ) { padding ->
        if (uiState.messages.isEmpty()) {
            EmptyStateWelcome(modifier = Modifier.padding(padding))
        } else {
            ChatMessageList(
                messages = uiState.messages,
                streamingText = uiState.streamingText,
                isLoading = uiState.isLoading,
                listState = listState,
                onRetry = viewModel::retryLastMessage,
                onCopy = viewModel::copyToClipboard,
                onFeedback = viewModel::submitFeedback,
                modifier = Modifier.padding(padding),
            )
        }
    }
}
```

## Chat Message List

```kotlin
@Composable
fun ChatMessageList(
    messages: List<ChatMessage>,
    streamingText: String?,
    isLoading: Boolean,
    listState: LazyListState,
    onRetry: () -> Unit,
    onCopy: (String) -> Unit,
    onFeedback: (String, Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        state = listState,
        reverseLayout = true, // newest messages at the bottom, scroll starts at bottom
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.Bottom),
        modifier = modifier.fillMaxSize(),
    ) {
        // Streaming message (currently being generated)
        if (streamingText != null) {
            item(key = "streaming") {
                AiMessageBubble(
                    text = streamingText,
                    isStreaming = true,
                    onCopy = { onCopy(streamingText) },
                    onFeedback = { /* disabled while streaming */ },
                )
            }
        }

        // Loading indicator
        if (isLoading && streamingText == null) {
            item(key = "loading") {
                TypingIndicator()
            }
        }

        // Message history (reversed, so index 0 is the latest message)
        items(
            items = messages.reversed(),
            key = { it.id },
        ) { message ->
            when (message.role) {
                Role.USER -> UserMessageBubble(text = message.content)
                Role.ASSISTANT -> AiMessageBubble(
                    text = message.content,
                    isStreaming = false,
                    isError = message.isError,
                    onCopy = { onCopy(message.content) },
                    onFeedback = { positive -> onFeedback(message.id, positive) },
                    onRetry = if (message.isError) onRetry else null,
                )
            }
        }
    }
}
```

## Message Bubbles

```kotlin
@Composable
fun UserMessageBubble(text: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
    ) {
        Surface(
            shape = RoundedCornerShape(20.dp, 20.dp, 4.dp, 20.dp),
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.widthIn(max = 300.dp),
        ) {
            Text(
                text = text,
                color = MaterialTheme.colorScheme.onPrimary,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            )
        }
    }
}

@Composable
fun AiMessageBubble(
    text: String,
    isStreaming: Boolean,
    isError: Boolean = false,
    onCopy: () -> Unit,
    onFeedback: (Boolean) -> Unit,
    onRetry: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.Start,
    ) {
        Surface(
            shape = RoundedCornerShape(20.dp, 20.dp, 20.dp, 4.dp),
            color = if (isError) MaterialTheme.colorScheme.errorContainer
                    else MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.widthIn(max = 340.dp),
        ) {
            Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
                if (isError) {
                    ErrorContent(text = text, onRetry = onRetry)
                } else {
                    MarkdownText(
                        markdown = text,
                        style = MaterialTheme.typography.bodyLarge.copy(
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        ),
                    )
                    if (isStreaming) {
                        BlinkingCursor()
                    }
                }
            }
        }

        // Action row (copy, feedback) - shown only for completed AI messages
        if (!isStreaming && !isError) {
            MessageActions(onCopy = onCopy, onFeedback = onFeedback)
        }
    }
}
```

## Streaming Text with Typewriter Effect

```kotlin
@Composable
fun StreamingText(
    fullText: String,
    modifier: Modifier = Modifier,
    charDelayMs: Long = 15,
) {
    var displayedText by remember { mutableStateOf("") }

    LaunchedEffect(fullText) {
        // When fullText grows (new chunk arrived), animate only the new characters
        val newChars = fullText.removePrefix(displayedText)
        for (char in newChars) {
            displayedText += char
            delay(charDelayMs)
        }
    }

    MarkdownText(markdown = displayedText, modifier = modifier)
}

@Composable
fun BlinkingCursor(modifier: Modifier = Modifier) {
    val alpha by rememberInfiniteTransition(label = "cursor").animateFloat(
        initialValue = 1f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "cursor_blink",
    )
    Box(
        modifier = modifier
            .padding(start = 2.dp)
            .size(width = 2.dp, height = 18.dp)
            .alpha(alpha)
            .background(MaterialTheme.colorScheme.primary),
    )
}
```

## Markdown Rendering

```kotlin
// Using compose-richtext or a custom solution
@Composable
fun MarkdownText(
    markdown: String,
    style: TextStyle = LocalTextStyle.current,
    modifier: Modifier = Modifier,
) {
    val parsedNodes = remember(markdown) { MarkdownParser.parse(markdown) }

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (node in parsedNodes) {
            when (node) {
                is MarkdownNode.Paragraph -> Text(text = node.annotatedString, style = style)
                is MarkdownNode.CodeBlock -> CodeBlockView(
                    code = node.code,
                    language = node.language,
                )
                is MarkdownNode.Heading -> Text(
                    text = node.text,
                    style = when (node.level) {
                        1 -> MaterialTheme.typography.headlineSmall
                        2 -> MaterialTheme.typography.titleLarge
                        else -> MaterialTheme.typography.titleMedium
                    },
                    fontWeight = FontWeight.Bold,
                )
                is MarkdownNode.BulletList -> BulletListView(items = node.items, style = style)
            }
        }
    }
}

@Composable
fun CodeBlockView(code: String, language: String?) {
    val clipboardManager = LocalClipboardManager.current

    Surface(
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHighest,
    ) {
        Column {
            // Header with language label and copy button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = language ?: "code",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                IconButton(onClick = { clipboardManager.setText(AnnotatedString(code)) }) {
                    Icon(Icons.Default.ContentCopy, contentDescription = "Copy code", modifier = Modifier.size(16.dp))
                }
            }
            // Code content
            SelectionContainer {
                Text(
                    text = code,
                    style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    modifier = Modifier
                        .horizontalScroll(rememberScrollState())
                        .padding(12.dp),
                )
            }
        }
    }
}
```

## Chat Input Bar

```kotlin
@Composable
fun ChatInputBar(
    onSend: (String) -> Unit,
    isLoading: Boolean,
    enabled: Boolean,
    modifier: Modifier = Modifier,
) {
    var text by rememberSaveable { mutableStateOf("") }

    Surface(
        tonalElevation = 3.dp,
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .navigationBarsPadding()
                .imePadding(),
            verticalAlignment = Alignment.Bottom,
        ) {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                placeholder = { Text("Message...") },
                modifier = Modifier.weight(1f),
                maxLines = 5,
                enabled = enabled,
                shape = RoundedCornerShape(24.dp),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Sentences,
                    imeAction = ImeAction.Default, // allow multiline
                ),
            )
            Spacer(Modifier.width(8.dp))
            FilledIconButton(
                onClick = {
                    if (text.isNotBlank()) {
                        onSend(text.trim())
                        text = ""
                    }
                },
                enabled = enabled && text.isNotBlank(),
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp,
                    )
                } else {
                    Icon(Icons.AutoMirrored.Default.Send, contentDescription = "Send")
                }
            }
        }
    }
}
```

## Typing Indicator

```kotlin
@Composable
fun TypingIndicator(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "typing")
    val dots = listOf(0, 1, 2)

    Row(
        modifier = modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        dots.forEach { index ->
            val offsetY by infiniteTransition.animateFloat(
                initialValue = 0f,
                targetValue = -6f,
                animationSpec = infiniteRepeatable(
                    animation = tween(400, delayMillis = index * 150, easing = EaseInOutQuad),
                    repeatMode = RepeatMode.Reverse,
                ),
                label = "dot_$index",
            )
            Box(
                modifier = Modifier
                    .offset(y = offsetY.dp)
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)),
            )
        }
    }
}
```

## Message Actions (Feedback)

```kotlin
@Composable
fun MessageActions(
    onCopy: () -> Unit,
    onFeedback: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.padding(start = 8.dp, top = 2.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        SmallActionButton(icon = Icons.Default.ContentCopy, description = "Copy", onClick = onCopy)
        SmallActionButton(icon = Icons.Default.ThumbUp, description = "Helpful", onClick = { onFeedback(true) })
        SmallActionButton(icon = Icons.Default.ThumbDown, description = "Not helpful", onClick = { onFeedback(false) })
    }
}

@Composable
private fun SmallActionButton(icon: ImageVector, description: String, onClick: () -> Unit) {
    IconButton(onClick = onClick, modifier = Modifier.size(32.dp)) {
        Icon(icon, contentDescription = description, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f))
    }
}
```

## ViewModel

```kotlin
@HiltViewModel
class ChatViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val clipboardManager: ClipboardManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    fun sendMessage(text: String) {
        val userMessage = ChatMessage(role = Role.USER, content = text)
        _uiState.update { it.copy(messages = it.messages + userMessage, isLoading = true, streamingText = null) }

        viewModelScope.launch {
            try {
                chatRepository.sendMessageStream(_uiState.value.messages)
                    .collect { chunk ->
                        _uiState.update { state ->
                            state.copy(streamingText = (state.streamingText ?: "") + chunk)
                        }
                    }
                // Stream complete: move streaming text to messages
                val aiMessage = ChatMessage(role = Role.ASSISTANT, content = _uiState.value.streamingText ?: "")
                _uiState.update { it.copy(messages = it.messages + aiMessage, isLoading = false, streamingText = null) }
            } catch (e: Exception) {
                val errorMessage = ChatMessage(role = Role.ASSISTANT, content = e.localizedMessage ?: "An error occurred", isError = true)
                _uiState.update { it.copy(messages = it.messages + errorMessage, isLoading = false, streamingText = null) }
            }
        }
    }

    fun retryLastMessage() {
        _uiState.update { state ->
            val withoutError = state.messages.dropLast(1) // remove error message
            state.copy(messages = withoutError)
        }
        val lastUserMessage = _uiState.value.messages.lastOrNull { it.role == Role.USER }
        lastUserMessage?.let { sendMessage(it.content) }
    }

    fun copyToClipboard(text: String) { clipboardManager.setText(AnnotatedString(text)) }

    fun submitFeedback(messageId: String, positive: Boolean) {
        viewModelScope.launch { chatRepository.submitFeedback(messageId, positive) }
    }
}

data class ChatUiState(
    val messages: List<ChatMessage> = emptyList(),
    val isLoading: Boolean = false,
    val streamingText: String? = null,
)
```
