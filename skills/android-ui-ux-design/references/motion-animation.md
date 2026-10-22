# Motion & Animation in Compose

## Animation Specs

Compose provides three core animation specifications:

```kotlin
// Spring: physics-based, natural feel. Default for most animations.
spring<Float>(
    dampingRatio = Spring.DampingRatioMediumBouncy,  // 0.5f
    stiffness = Spring.StiffnessMedium,               // 1500f
)

// Tween: duration-based with easing curves
tween<Float>(
    durationMillis = 300,
    delayMillis = 0,
    easing = FastOutSlowInEasing,
)

// Snap: instant jump, no interpolation
snap<Float>(delayMillis = 0)
```

Common easing curves: `FastOutSlowInEasing` (standard), `LinearOutSlowInEasing` (decelerate), `FastOutLinearInEasing` (accelerate), `LinearEasing`, `EaseInOutCubic`.

## AnimatedVisibility

Enter and exit transitions for composables.

```kotlin
var visible by remember { mutableStateOf(false) }

AnimatedVisibility(
    visible = visible,
    enter = fadeIn(animationSpec = tween(300)) +
            slideInVertically(initialOffsetY = { -40 }),
    exit = fadeOut(animationSpec = tween(200)) +
           slideOutVertically(targetOffsetY = { -40 }),
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Text("This content animates in and out", modifier = Modifier.padding(16.dp))
    }
}
```

Built-in enter transitions: `fadeIn`, `slideIn`, `slideInHorizontally`, `slideInVertically`, `expandIn`, `expandHorizontally`, `expandVertically`, `scaleIn`.

Built-in exit transitions: `fadeOut`, `slideOut`, `slideOutHorizontally`, `slideOutVertically`, `shrinkOut`, `shrinkHorizontally`, `shrinkVertically`, `scaleOut`.

Combine with `+` operator.

## AnimatedContent

Animates between different content based on a target state.

```kotlin
var count by remember { mutableIntStateOf(0) }

AnimatedContent(
    targetState = count,
    transitionSpec = {
        if (targetState > initialState) {
            slideInVertically { height -> height } + fadeIn() togetherWith
                slideOutVertically { height -> -height } + fadeOut()
        } else {
            slideInVertically { height -> -height } + fadeIn() togetherWith
                slideOutVertically { height -> height } + fadeOut()
        }.using(SizeTransform(clip = false))
    },
    label = "counter",
) { targetCount ->
    Text(
        text = "$targetCount",
        style = MaterialTheme.typography.displayMedium,
    )
}
```

## Crossfade

Simple crossfade between composables keyed by a state value.

```kotlin
var currentTab by remember { mutableStateOf(Tab.HOME) }

Crossfade(
    targetState = currentTab,
    animationSpec = tween(300),
    label = "tab_crossfade",
) { tab ->
    when (tab) {
        Tab.HOME -> HomeContent()
        Tab.SEARCH -> SearchContent()
        Tab.PROFILE -> ProfileContent()
    }
}
```

## animate*AsState

Animate a single value when the target changes. Use for color, size, offset, alpha, etc.

```kotlin
val expanded by remember { mutableStateOf(false) }

val cardElevation by animateDpAsState(
    targetValue = if (expanded) 8.dp else 2.dp,
    animationSpec = spring(stiffness = Spring.StiffnessLow),
    label = "elevation",
)

val backgroundColor by animateColorAsState(
    targetValue = if (expanded) MaterialTheme.colorScheme.primaryContainer
                  else MaterialTheme.colorScheme.surfaceContainerLow,
    animationSpec = tween(300),
    label = "bg_color",
)

val cornerRadius by animateDpAsState(
    targetValue = if (expanded) 28.dp else 12.dp,
    label = "corner",
)
```

Available: `animateFloatAsState`, `animateDpAsState`, `animateColorAsState`, `animateSizeAsState`, `animateOffsetAsState`, `animateIntAsState`, `animateIntOffsetAsState`, `animateIntSizeAsState`.

## animateContentSize

Smoothly animates size changes of a composable.

```kotlin
var expanded by remember { mutableStateOf(false) }

Column(
    modifier = Modifier
        .fillMaxWidth()
        .clickable { expanded = !expanded }
        .animateContentSize(animationSpec = spring(stiffness = Spring.StiffnessLow)),
) {
    Text("Title", style = MaterialTheme.typography.titleMedium)
    if (expanded) {
        Text(
            "Detailed description that appears when expanded. " +
            "The parent Column smoothly animates its height.",
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}
```

## Transition

Orchestrate multiple animations that run together on a shared state.

```kotlin
var selected by remember { mutableStateOf(false) }
val transition = updateTransition(targetState = selected, label = "selection")

val borderWidth by transition.animateDp(label = "border") { isSelected ->
    if (isSelected) 2.dp else 0.dp
}
val elevation by transition.animateDp(label = "elevation") { isSelected ->
    if (isSelected) 8.dp else 2.dp
}
val backgroundColor by transition.animateColor(label = "bg") { isSelected ->
    if (isSelected) MaterialTheme.colorScheme.primaryContainer
    else MaterialTheme.colorScheme.surface
}
```

## InfiniteTransition

Animations that loop indefinitely. Use for loading indicators, pulsing effects, shimmer.

```kotlin
val infiniteTransition = rememberInfiniteTransition(label = "loading")

val alpha by infiniteTransition.animateFloat(
    initialValue = 0.3f,
    targetValue = 1f,
    animationSpec = infiniteRepeatable(
        animation = tween(durationMillis = 800),
        repeatMode = RepeatMode.Reverse,
    ),
    label = "pulse",
)

Box(
    modifier = Modifier
        .size(48.dp)
        .background(
            color = MaterialTheme.colorScheme.primary.copy(alpha = alpha),
            shape = CircleShape,
        ),
)
```

## Shared Element Transitions with Navigation3

Shared element transitions animate an element between two screens during navigation.

```kotlin
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.animation.SharedTransitionScope
import androidx.navigation3.runtime.NavKey
import androidx.navigation3.runtime.NavHost
import androidx.navigation3.runtime.rememberNavController

@Composable
fun AppNavigation() {
    val navController = rememberNavController(startKey = ListKey)

    SharedTransitionLayout {
        NavHost(navController = navController) { key ->
            when (key) {
                is ListKey -> {
                    ProductListScreen(
                        onProductClick = { product ->
                            navController.navigate(DetailKey(product.id))
                        },
                        sharedTransitionScope = this@SharedTransitionLayout,
                        animatedVisibilityScope = this@NavHost,
                    )
                }
                is DetailKey -> {
                    ProductDetailScreen(
                        productId = key.productId,
                        sharedTransitionScope = this@SharedTransitionLayout,
                        animatedVisibilityScope = this@NavHost,
                    )
                }
            }
        }
    }
}

@Composable
fun SharedTransitionScope.ProductImage(
    imageUrl: String,
    productId: String,
    animatedVisibilityScope: AnimatedVisibilityScope,
    modifier: Modifier = Modifier,
) {
    AsyncImage(
        model = imageUrl,
        contentDescription = null,
        modifier = modifier.sharedElement(
            state = rememberSharedContentState(key = "image_$productId"),
            animatedVisibilityScope = animatedVisibilityScope,
        ),
    )
}
```

## Micro-interactions

### Button Press Feedback

```kotlin
@Composable
fun AnimatedButton(onClick: () -> Unit, text: String, modifier: Modifier = Modifier) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(stiffness = Spring.StiffnessHigh),
        label = "press_scale",
    )

    Button(
        onClick = onClick,
        modifier = modifier.graphicsLayer { scaleX = scale; scaleY = scale },
        interactionSource = interactionSource,
    ) {
        Text(text)
    }
}
```

### Expandable Card

```kotlin
@Composable
fun ExpandableCard(title: String, description: String, modifier: Modifier = Modifier) {
    var expanded by remember { mutableStateOf(false) }
    val rotationAngle by animateFloatAsState(
        targetValue = if (expanded) 180f else 0f,
        animationSpec = tween(300),
        label = "chevron_rotation",
    )

    ElevatedCard(
        modifier = modifier.fillMaxWidth().clickable { expanded = !expanded },
    ) {
        Column(modifier = Modifier.padding(16.dp).animateContentSize()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Icon(
                    Icons.Default.ExpandMore,
                    contentDescription = if (expanded) "Collapse" else "Expand",
                    modifier = Modifier.graphicsLayer { rotationZ = rotationAngle },
                )
            }
            if (expanded) {
                Text(
                    description,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
        }
    }
}
```

### Skeleton Shimmer Effect

```kotlin
@Composable
fun ShimmerEffect(modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "shimmer")
    val shimmerTranslate by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "shimmer_translate",
    )

    val shimmerBrush = Brush.linearGradient(
        colors = listOf(
            MaterialTheme.colorScheme.surfaceContainerHighest,
            MaterialTheme.colorScheme.surfaceContainerLow,
            MaterialTheme.colorScheme.surfaceContainerHighest,
        ),
        start = Offset(shimmerTranslate - 200f, 0f),
        end = Offset(shimmerTranslate, 0f),
    )

    Box(modifier = modifier.background(shimmerBrush, shape = MaterialTheme.shapes.small))
}
```

## Performance Tips

- Use `label` parameter in all animation APIs for Android Studio animation preview.
- Prefer `graphicsLayer` for scale, rotation, alpha, and translation -- these avoid recomposition.
- Use `spring()` as the default spec. Tween for precise timing control.
- Avoid animating layout-affecting properties (padding, size) in tight loops; use `graphicsLayer` transforms instead.
- Set `Modifier.drawBehind` or `Modifier.graphicsLayer` to animate at the draw phase, skipping recomposition and layout phases.
