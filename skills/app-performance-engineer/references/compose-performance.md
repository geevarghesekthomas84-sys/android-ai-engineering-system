# Compose Rendering Performance

## Recomposition Basics

Compose re-executes composable functions whenever their inputs (parameters or read state) change. This process -- recomposition -- is designed to be fast, but unnecessary recomposition wastes CPU time and causes jank.

The three phases of a Compose frame:

1. **Composition** -- determine what UI elements exist (runs composable functions)
2. **Layout** -- measure and place elements
3. **Drawing** -- render pixels

Each phase can be skipped independently. An animation that only changes drawing properties (color, alpha) skips composition and layout entirely.

## Stability and Skippability

The Compose compiler marks composable functions as **skippable** when all parameters are **stable**. A skippable function is not re-executed if none of its inputs changed.

### What Is Stable?

A type is stable when:
- The result of `equals` for two instances will always be the same for the same inputs
- If a public property changes, Compose is notified (e.g., `MutableState`)
- All public properties are themselves stable

Primitives, `String`, and function types (`() -> Unit`) are stable. `List`, `Set`, and `Map` from `kotlin.collections` are **not** stable because the compiler cannot prove they are immutable (they could be `MutableList` cast to `List`).

### Marking Classes Stable

```kotlin
// Option 1: @Immutable -- guarantees all properties are deeply immutable
@Immutable
data class ChartData(
    val labels: List<String>,  // List is now assumed immutable
    val values: List<Float>,
)

// Option 2: @Stable -- guarantees changes will be observed by Compose
@Stable
data class UserProfile(
    val id: String,
    val name: String,
    val avatarUrl: String,
)
```

Use `@Immutable` when the object truly never changes after construction. Use `@Stable` when the object is stable but might be replaced with a new instance.

### Using Kotlinx Immutable Collections

For true immutability, use `kotlinx.collections.immutable`:

```kotlin
import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.persistentListOf

@Immutable
data class FeedState(
    val posts: ImmutableList<Post>,
    val isLoading: Boolean,
)

// Creating
val state = FeedState(
    posts = persistentListOf(post1, post2),
    isLoading = false,
)
```

Dependency:

```kotlin
implementation("org.jetbrains.kotlinx:kotlinx-collections-immutable:0.3.8")
```

## derivedStateOf

Use `derivedStateOf` when you have a computation that depends on state but should only trigger recomposition when its result changes:

```kotlin
@Composable
fun ContactList(contacts: List<Contact>, searchQuery: String) {
    // BAD: filteredContacts recalculated every recomposition,
    // AND triggers recomposition even if the filtered result is the same
    val filteredContacts = contacts.filter { it.name.contains(searchQuery) }

    // GOOD: only recomposes downstream when the filtered list actually changes
    val filteredContacts by remember(contacts, searchQuery) {
        derivedStateOf {
            contacts.filter { it.name.contains(searchQuery, ignoreCase = true) }
        }
    }

    LazyColumn {
        items(filteredContacts, key = { it.id }) { contact ->
            ContactRow(contact)
        }
    }
}
```

`derivedStateOf` is most valuable when the input changes more frequently than the output. Classic case: a scrolling list where you derive "show scroll-to-top button" from scroll position -- the position changes every frame, but the boolean changes rarely.

```kotlin
val listState = rememberLazyListState()

val showScrollToTop by remember {
    derivedStateOf { listState.firstVisibleItemIndex > 5 }
}
```

## remember and rememberSaveable

### remember

`remember` caches a value across recompositions. Without it, objects are recreated every recomposition:

```kotlin
// BAD: new formatter every recomposition
@Composable
fun PriceTag(amount: Double) {
    val formatter = NumberFormat.getCurrencyInstance()
    Text(formatter.format(amount))
}

// GOOD: formatter created once, reused across recompositions
@Composable
fun PriceTag(amount: Double) {
    val formatter = remember { NumberFormat.getCurrencyInstance() }
    Text(formatter.format(amount))
}
```

Use keys to invalidate when inputs change:

```kotlin
val formattedDate = remember(timestamp) {
    DateFormat.getDateInstance().format(Date(timestamp))
}
```

### rememberSaveable

Survives configuration changes (rotation) and process death:

```kotlin
var searchQuery by rememberSaveable { mutableStateOf("") }
```

For complex objects, provide a `Saver`:

```kotlin
val filterSaver = Saver<Filter, Bundle>(
    save = { Bundle().apply { putString("category", it.category) } },
    restore = { Filter(category = it.getString("category", "all")) }
)

var filter by rememberSaveable(stateSaver = filterSaver) {
    mutableStateOf(Filter("all"))
}
```

## LazyColumn Performance

### Always Provide Keys

Without keys, Compose identifies items by position. Insertions and removals cause every subsequent item to recompose.

```kotlin
// BAD: positional identity
LazyColumn {
    items(messages) { message ->
        MessageRow(message)
    }
}

// GOOD: stable identity
LazyColumn {
    items(messages, key = { it.id }) { message ->
        MessageRow(message)
    }
}
```

### Use contentType

When your list mixes item types, `contentType` enables view recycling across items of the same type:

```kotlin
LazyColumn {
    items(feedItems, key = { it.id }, contentType = { it.type }) { item ->
        when (item) {
            is FeedItem.Post -> PostCard(item)
            is FeedItem.Ad -> AdBanner(item)
            is FeedItem.Header -> SectionHeader(item)
        }
    }
}
```

### Avoid Recomposition of Items

Extract item composables as separate, stable functions so they can be skipped:

```kotlin
// Each MessageRow is skippable because Message is @Stable
@Composable
fun MessageRow(message: Message) {
    Row(modifier = Modifier.padding(16.dp)) {
        AsyncImage(model = message.avatarUrl, contentDescription = null)
        Column {
            Text(message.sender, style = MaterialTheme.typography.titleSmall)
            Text(message.body)
        }
    }
}
```

### Avoid Nested Scrolling Issues

Never put a `LazyColumn` inside a vertically scrollable `Column`. Use `item {}` blocks instead:

```kotlin
LazyColumn {
    item { HeaderSection() }
    items(products, key = { it.id }) { ProductCard(it) }
    item { FooterSection() }
}
```

## Layout Inspector Recomposition Counts

In Android Studio:

1. Open **Layout Inspector** (Running Devices panel or Tools > Layout Inspector)
2. Enable **Show Recomposition Counts** in the toolbar
3. Interact with the app and observe which composables recompose

Red highlights indicate excessive recomposition. Drill into those composables and check:
- Are parameters stable?
- Is state being read at the right scope?
- Are lambda parameters being recreated?

## Compose Compiler Metrics

Enable compiler reports to see exactly which composables are skippable and which classes are stable:

```kotlin
// In the app module's build.gradle.kts
composeCompiler {
    reportsDestination = layout.buildDirectory.dir("compose_metrics")
    metricsDestination = layout.buildDirectory.dir("compose_metrics")
}
```

After building, check:
- `*-composables.txt` -- lists each composable with restartable/skippable status
- `*-classes.txt` -- lists each class with stability status
- `*-module.json` -- aggregate stats

Look for composables marked `restartable` but not `skippable` -- these are your recomposition hotspots.

## Avoiding Unnecessary Allocations in Composition

Every allocation during composition adds GC pressure. Common traps:

```kotlin
// BAD: new lambda instance every recomposition
@Composable
fun ItemList(viewModel: MyViewModel) {
    LazyColumn {
        items(viewModel.items) { item ->
            ItemRow(item, onClick = { viewModel.onItemClick(item.id) })
            // ^ new lambda every recomposition because it captures `item`
        }
    }
}

// GOOD: extract the callback to avoid per-item lambda allocation
@Composable
fun ItemList(viewModel: MyViewModel) {
    val onItemClick = viewModel::onItemClick
    LazyColumn {
        items(viewModel.items, key = { it.id }) { item ->
            ItemRow(item, onItemClick = onItemClick)
        }
    }
}

@Composable
fun ItemRow(item: Item, onItemClick: (String) -> Unit) {
    Card(onClick = { onItemClick(item.id) }) {
        Text(item.name)
    }
}
```

Avoid creating `Modifier` chains inside composition when they can be hoisted:

```kotlin
// BAD: new modifier chain every recomposition
@Composable
fun MyCard(content: @Composable () -> Unit) {
    Box(modifier = Modifier.padding(16.dp).fillMaxWidth().shadow(4.dp)) {
        content()
    }
}

// OK in practice -- Compose caches simple modifier chains effectively.
// Only hoist if profiling shows this is a bottleneck.
```

## State Reads in the Correct Scope

Read state as late (as deep in the tree) as possible. Reading state in a composable causes that composable to recompose. If you read state at the top of a screen composable, the entire screen recomposes.

```kotlin
// BAD: reading scroll state at the screen level recomposes everything
@Composable
fun FeedScreen() {
    val listState = rememberLazyListState()
    val showFab = listState.firstVisibleItemIndex < 3  // read here = screen recomposes

    Scaffold(
        floatingActionButton = {
            if (showFab) FloatingActionButton(onClick = {}) { Icon(...) }
        }
    ) {
        FeedList(listState)
    }
}

// GOOD: defer the read to the scope that needs it
@Composable
fun FeedScreen() {
    val listState = rememberLazyListState()

    Scaffold(
        floatingActionButton = {
            val showFab by remember { derivedStateOf { listState.firstVisibleItemIndex < 3 } }
            if (showFab) FloatingActionButton(onClick = {}) { Icon(...) }
        }
    ) {
        FeedList(listState)
    }
}
```

Use `Modifier.graphicsLayer` for animation-only properties so changes skip composition and layout entirely:

```kotlin
Box(
    modifier = Modifier.graphicsLayer {
        alpha = animatedAlpha.value  // only triggers draw phase
    }
)
```
