# Compose UI Testing

## Dependencies

```kotlin
// build.gradle.kts (module-level)
dependencies {
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.03.01"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    // For createAndroidComposeRule with Hilt
    androidTestImplementation("com.google.dagger:hilt-android-testing:2.54.1")
    kspAndroidTest("com.google.dagger:hilt-android-compiler:2.54.1")
}
```

## Test Rules

### createComposeRule (no Activity needed)

```kotlin
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Rule
import org.junit.Test

class GreetingCardTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun greetingCard_displaysName() {
        composeTestRule.setContent {
            GreetingCard(name = "Alice")
        }

        composeTestRule.onNodeWithText("Hello, Alice!").assertIsDisplayed()
    }
}
```

### createAndroidComposeRule (needs Activity context)

```kotlin
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest

@HiltAndroidTest
class ProfileScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    @Before
    fun setUp() {
        hiltRule.inject()
    }

    @Test
    fun profileScreen_showsUserName() {
        composeTestRule.setContent {
            ProfileScreen(userId = "123")
        }

        composeTestRule.onNodeWithTag("profile_name").assertTextEquals("Alice")
    }
}
```

## Finding Nodes

### By Text

```kotlin
// Exact match
composeTestRule.onNodeWithText("Submit")

// Substring match
composeTestRule.onNodeWithText("Submit", substring = true)

// Case-insensitive
composeTestRule.onNodeWithText("submit", ignoreCase = true)

// Multiple nodes
composeTestRule.onAllNodesWithText("Item").assertCountEquals(5)
```

### By Test Tag

```kotlin
// In production code:
Text(
    text = "Price: $9.99",
    modifier = Modifier.testTag("price_label")
)

// In test:
composeTestRule.onNodeWithTag("price_label").assertTextContains("$9.99")
```

### By Content Description

```kotlin
// In production code:
Icon(
    imageVector = Icons.Default.Delete,
    contentDescription = "Delete item"
)

// In test:
composeTestRule
    .onNodeWithContentDescription("Delete item")
    .assertIsDisplayed()
```

### By Semantics Properties

```kotlin
import androidx.compose.ui.test.*

// Node that has a click action
composeTestRule.onNode(hasClickAction())

// Combine matchers
composeTestRule.onNode(
    hasText("Submit") and hasClickAction() and isEnabled()
)

// Node with parent matcher
composeTestRule.onNode(
    hasText("OK") and hasAnyAncestor(hasTestTag("dialog"))
)

// Node with child matcher
composeTestRule.onNode(
    hasTestTag("card") and hasAnyDescendant(hasText("Title"))
)
```

## Performing Actions

```kotlin
// Click
composeTestRule.onNodeWithText("Login").performClick()

// Text input
composeTestRule.onNodeWithTag("email_field").performTextInput("user@example.com")

// Clear and replace text
composeTestRule.onNodeWithTag("email_field").performTextClearance()
composeTestRule.onNodeWithTag("email_field").performTextReplacement("new@example.com")

// Scroll to node (inside a scrollable container)
composeTestRule.onNodeWithText("Footer").performScrollTo()

// Swipe
composeTestRule.onNodeWithTag("pager").performTouchInput {
    swipeLeft()
}

// Long click
composeTestRule.onNodeWithText("Item").performTouchInput {
    longClick()
}

// Custom gesture
composeTestRule.onNodeWithTag("canvas").performTouchInput {
    down(center)
    moveTo(centerRight)
    up()
}

// IME action (e.g., pressing "Done" on keyboard)
composeTestRule.onNodeWithTag("search_field").performImeAction()
```

## Assertions

```kotlin
// Visibility
composeTestRule.onNodeWithText("Welcome").assertIsDisplayed()
composeTestRule.onNodeWithText("Error").assertDoesNotExist()
composeTestRule.onNodeWithTag("hidden").assertIsNotDisplayed()

// Enabled state
composeTestRule.onNodeWithText("Submit").assertIsEnabled()
composeTestRule.onNodeWithText("Submit").assertIsNotEnabled()

// Text content
composeTestRule.onNodeWithTag("counter").assertTextEquals("Count: 5")
composeTestRule.onNodeWithTag("desc").assertTextContains("example")

// Selection state
composeTestRule.onNodeWithTag("checkbox").assertIsSelected()
composeTestRule.onNodeWithTag("checkbox").assertIsNotSelected()
composeTestRule.onNodeWithTag("toggle").assertIsOn()
composeTestRule.onNodeWithTag("toggle").assertIsOff()

// Focus
composeTestRule.onNodeWithTag("input").assertIsFocused()

// Content description
composeTestRule.onNodeWithTag("avatar").assertContentDescriptionEquals("User avatar")

// Node count
composeTestRule.onAllNodesWithTag("list_item").assertCountEquals(10)
```

## Waiting for Conditions

```kotlin
// Wait until a node exists (default timeout: 1000ms)
composeTestRule.waitUntilExactlyOneExists(
    hasText("Data loaded"),
    timeoutMillis = 5_000
)

// Wait until a node count matches
composeTestRule.waitUntilNodeCount(
    hasTestTag("list_item"),
    count = 3,
    timeoutMillis = 5_000
)

// Wait until a custom condition is true
composeTestRule.waitUntil(timeoutMillis = 5_000) {
    composeTestRule
        .onAllNodesWithTag("list_item")
        .fetchSemanticsNodes()
        .size == 3
}

// Wait for idle (all recompositions, animations, pending frames done)
composeTestRule.waitForIdle()
```

## Controlling the Main Clock

```kotlin
@Test
fun animatedCounter_showsFinalValue() {
    composeTestRule.mainClock.autoAdvance = false

    composeTestRule.setContent {
        AnimatedCounter(targetValue = 100)
    }

    // Advance time by specific amount
    composeTestRule.mainClock.advanceTimeBy(500L)

    composeTestRule.onNodeWithTag("counter").assertTextContains("50")

    // Advance to the end of animation
    composeTestRule.mainClock.advanceTimeBy(500L)

    composeTestRule.onNodeWithTag("counter").assertTextEquals("100")
}

@Test
fun loadingIndicator_appearsBeforeDataLoads() {
    composeTestRule.mainClock.autoAdvance = false

    composeTestRule.setContent {
        DataScreen()
    }

    // Loading should be visible before coroutines complete
    composeTestRule.onNodeWithTag("loading").assertIsDisplayed()

    // Advance past the loading delay
    composeTestRule.mainClock.advanceTimeBy(2_000L)
    composeTestRule.waitForIdle()

    composeTestRule.onNodeWithTag("loading").assertDoesNotExist()
    composeTestRule.onNodeWithTag("content").assertIsDisplayed()
}
```

## Testing Navigation

```kotlin
@Test
fun navigation_loginToHome() {
    composeTestRule.setContent {
        val navController = rememberNavController()
        AppNavHost(navController = navController)
    }

    // Start on login screen
    composeTestRule.onNodeWithTag("login_screen").assertIsDisplayed()

    // Fill in credentials and submit
    composeTestRule.onNodeWithTag("email_input").performTextInput("user@test.com")
    composeTestRule.onNodeWithTag("password_input").performTextInput("password123")
    composeTestRule.onNodeWithText("Sign In").performClick()

    composeTestRule.waitForIdle()

    // Should navigate to home
    composeTestRule.onNodeWithTag("home_screen").assertIsDisplayed()
    composeTestRule.onNodeWithTag("login_screen").assertDoesNotExist()
}
```

## Testing with Navigation3

```kotlin
@Test
fun navigation3_backStackManagement() {
    composeTestRule.setContent {
        var backStack by remember { mutableStateOf(listOf(HomeRoute)) }

        NavDisplay(
            backStack = backStack,
            onBack = { backStack = backStack.dropLast(1) },
            entryProvider = entryProvider {
                entry<HomeRoute> { route ->
                    HomeScreen(
                        onNavigateToDetail = { id ->
                            backStack = backStack + DetailRoute(id)
                        }
                    )
                }
                entry<DetailRoute> { route ->
                    DetailScreen(itemId = route.id)
                }
            }
        )
    }

    composeTestRule.onNodeWithTag("home_screen").assertIsDisplayed()
    composeTestRule.onNodeWithText("Item 1").performClick()
    composeTestRule.onNodeWithTag("detail_screen").assertIsDisplayed()
}
```

## Testing LazyColumn / LazyList

```kotlin
@Test
fun lazyColumn_displaysAllItems() {
    val items = (1..50).map { "Item $it" }

    composeTestRule.setContent {
        LazyColumn(Modifier.testTag("list")) {
            items(items) { item ->
                Text(text = item, modifier = Modifier.testTag("item_$item"))
            }
        }
    }

    // First item is visible
    composeTestRule.onNodeWithText("Item 1").assertIsDisplayed()

    // Scroll to item 50
    composeTestRule.onNodeWithTag("list").performScrollToIndex(49)

    composeTestRule.onNodeWithText("Item 50").assertIsDisplayed()
}

@Test
fun lazyColumn_scrollToKey() {
    composeTestRule.setContent {
        ItemList(items = generateItems(100))
    }

    composeTestRule.onNodeWithTag("item_list")
        .performScrollToKey("item_75")

    composeTestRule.onNodeWithText("Item 75").assertIsDisplayed()
}
```

## Custom Semantic Matchers

```kotlin
fun hasError(): SemanticsMatcher =
    SemanticsMatcher("has error") { node ->
        node.config.getOrNull(SemanticsProperties.Error) != null
    }

fun hasProgressValue(expected: Float): SemanticsMatcher =
    SemanticsMatcher("has progress $expected") { node ->
        val range = node.config.getOrNull(SemanticsProperties.ProgressBarRangeInfo)
        range != null && abs(range.current - expected) < 0.01f
    }

@Test
fun progressBar_showsHalfway() {
    composeTestRule.setContent {
        LinearProgressIndicator(progress = { 0.5f })
    }

    composeTestRule.onNode(hasProgressValue(0.5f)).assertIsDisplayed()
}
```

## Debugging Tests

```kotlin
// Print the semantics tree to logcat
composeTestRule.onRoot().printToLog("COMPOSE_TEST")

// Print all nodes with a specific tag
composeTestRule.onAllNodesWithTag("item").printToLog("LIST_ITEMS")

// Use unmerged tree to see individual nodes inside merged semantics
composeTestRule.onRoot(useUnmergedTree = true).printToLog("UNMERGED")
```

## Gradle Execution

```bash
# Run all connected (instrumented) tests
./gradlew connectedDebugAndroidTest

# Run a specific test class
./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.example.GreetingCardTest

# Run with orchestrator for test isolation
# (requires androidTestUtil dependency and testOptions config)
./gradlew connectedDebugAndroidTest
```
