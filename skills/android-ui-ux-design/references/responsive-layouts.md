# Responsive & Adaptive Layouts

## WindowSizeClass

WindowSizeClass categorizes the available window dimensions into three width classes and three height classes. Use width classes to drive layout decisions.

| Width Class | Breakpoint | Typical Devices |
|---|---|---|
| Compact | < 600dp | Phones portrait |
| Medium | 600dp - 839dp | Foldables, phones landscape, small tablets |
| Expanded | >= 840dp | Tablets, desktop |

### Setup

Add the dependency:
```kotlin
// build.gradle.kts
implementation("androidx.compose.material3.adaptive:adaptive:1.1.0")
implementation("androidx.compose.material3.adaptive:adaptive-layout:1.1.0")
implementation("androidx.compose.material3.adaptive:adaptive-navigation:1.1.0")
```

### Calculating WindowSizeClass

```kotlin
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.window.core.layout.WindowWidthSizeClass

@Composable
fun AdaptiveScreen() {
    val adaptiveInfo = currentWindowAdaptiveInfo()
    val widthSizeClass = adaptiveInfo.windowSizeClass.windowWidthSizeClass

    when (widthSizeClass) {
        WindowWidthSizeClass.COMPACT -> CompactLayout()
        WindowWidthSizeClass.MEDIUM -> MediumLayout()
        WindowWidthSizeClass.EXPANDED -> ExpandedLayout()
    }
}
```

## NavigationSuiteScaffold

Automatically selects the appropriate navigation component (bottom bar, rail, or drawer) based on window size.

```kotlin
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold

enum class AppDestination(
    val label: String,
    val icon: ImageVector,
    val contentDescription: String,
) {
    HOME("Home", Icons.Default.Home, "Home"),
    SEARCH("Search", Icons.Default.Search, "Search"),
    FAVORITES("Favorites", Icons.Default.Favorite, "Favorites"),
    PROFILE("Profile", Icons.Default.Person, "Profile"),
}

@Composable
fun AppNavigation() {
    var currentDestination by remember { mutableStateOf(AppDestination.HOME) }

    NavigationSuiteScaffold(
        navigationSuiteItems = {
            AppDestination.entries.forEach { destination ->
                item(
                    selected = currentDestination == destination,
                    onClick = { currentDestination = destination },
                    icon = { Icon(destination.icon, contentDescription = destination.contentDescription) },
                    label = { Text(destination.label) },
                )
            }
        },
    ) {
        when (currentDestination) {
            AppDestination.HOME -> HomeScreen()
            AppDestination.SEARCH -> SearchScreen()
            AppDestination.FAVORITES -> FavoritesScreen()
            AppDestination.PROFILE -> ProfileScreen()
        }
    }
}
```

## ListDetailPaneScaffold

A canonical list-detail layout that adapts between single-pane (compact) and two-pane (expanded) presentations.

```kotlin
import androidx.compose.material3.adaptive.layout.ListDetailPaneScaffold
import androidx.compose.material3.adaptive.layout.ListDetailPaneScaffoldRole
import androidx.compose.material3.adaptive.navigation.rememberListDetailPaneScaffoldNavigator

@OptIn(ExperimentalMaterial3AdaptiveApi::class)
@Composable
fun ListDetailScreen(items: List<Item>) {
    val navigator = rememberListDetailPaneScaffoldNavigator<Item>()

    ListDetailPaneScaffold(
        directive = navigator.scaffoldDirective,
        value = navigator.scaffoldValue,
        listPane = {
            LazyColumn {
                items(items) { item ->
                    ListItem(
                        headlineContent = { Text(item.title) },
                        supportingContent = { Text(item.subtitle) },
                        modifier = Modifier.clickable {
                            navigator.navigateTo(
                                pane = ListDetailPaneScaffoldRole.Detail,
                                content = item,
                            )
                        },
                    )
                }
            }
        },
        detailPane = {
            val selectedItem = navigator.currentDestination?.content
            if (selectedItem != null) {
                DetailContent(item = selectedItem)
            } else {
                EmptyDetailPlaceholder()
            }
        },
    )
}
```

## Foldable Support

Detect folding features to adapt layouts for foldable devices.

```kotlin
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.window.layout.FoldingFeature

@Composable
fun FoldableAwareLayout(content: @Composable () -> Unit) {
    val adaptiveInfo = currentWindowAdaptiveInfo()
    val postures = adaptiveInfo.windowPosture

    // Check for table-top posture (device folded horizontally, like a laptop)
    val isTableTop = postures.isTabletop

    if (isTableTop) {
        // Split layout: top half for content, bottom half for controls
        Column(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            ) {
                ContentPane()
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            ) {
                ControlsPane()
            }
        }
    } else {
        content()
    }
}
```

## Tablet Layout with NavigationRail

For expanded screens, use NavigationRail alongside content instead of a bottom bar.

```kotlin
@Composable
fun TabletLayout(
    currentRoute: String,
    onNavigate: (String) -> Unit,
    content: @Composable () -> Unit,
) {
    Row(modifier = Modifier.fillMaxSize()) {
        NavigationRail(
            header = {
                FloatingActionButton(
                    onClick = { onNavigate("compose") },
                    modifier = Modifier.padding(vertical = 12.dp),
                ) {
                    Icon(Icons.Default.Edit, contentDescription = "Compose")
                }
            },
        ) {
            Spacer(modifier = Modifier.weight(1f))
            NavigationRailItem(
                selected = currentRoute == "home",
                onClick = { onNavigate("home") },
                icon = { Icon(Icons.Default.Home, contentDescription = "Home") },
                label = { Text("Home") },
            )
            NavigationRailItem(
                selected = currentRoute == "search",
                onClick = { onNavigate("search") },
                icon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                label = { Text("Search") },
            )
            NavigationRailItem(
                selected = currentRoute == "settings",
                onClick = { onNavigate("settings") },
                icon = { Icon(Icons.Default.Settings, contentDescription = "Settings") },
                label = { Text("Settings") },
            )
            Spacer(modifier = Modifier.weight(1f))
        }

        VerticalDivider()

        Box(modifier = Modifier.weight(1f)) {
            content()
        }
    }
}
```

## Adaptive Content Grid

Use `LazyVerticalGrid` with adaptive column sizing to fill available space.

```kotlin
@Composable
fun AdaptiveGrid(items: List<GridItem>) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 160.dp),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        items(items, key = { it.id }) { item ->
            GridCard(item = item)
        }
    }
}
```

## Responsive Padding & Spacing

Adjust content padding based on window size for comfortable reading widths.

```kotlin
@Composable
fun ResponsiveContentPadding(): PaddingValues {
    val widthSizeClass = currentWindowAdaptiveInfo().windowSizeClass.windowWidthSizeClass

    return when (widthSizeClass) {
        WindowWidthSizeClass.COMPACT -> PaddingValues(horizontal = 16.dp)
        WindowWidthSizeClass.MEDIUM -> PaddingValues(horizontal = 32.dp)
        WindowWidthSizeClass.EXPANDED -> PaddingValues(horizontal = 64.dp)
        else -> PaddingValues(horizontal = 16.dp)
    }
}

@Composable
fun ResponsiveScreen(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(ResponsiveContentPadding()),
    ) {
        Box(
            modifier = Modifier.widthIn(max = 840.dp).align(Alignment.TopCenter),
        ) {
            content()
        }
    }
}
```

## Best Practices

- Always test on Compact, Medium, and Expanded window sizes.
- Use `NavigationSuiteScaffold` as the default navigation strategy -- it handles size transitions automatically.
- Use `ListDetailPaneScaffold` for any master-detail pattern. It handles back navigation on compact screens.
- Constrain maximum content width on expanded screens to maintain readability (600-840dp max).
- Avoid hardcoded widths. Use `fillMaxWidth()`, `weight()`, and adaptive grid columns.
- Test foldable postures in the Android Emulator using the Foldable device profiles.
