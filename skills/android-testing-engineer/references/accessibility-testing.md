# Accessibility Testing

## Compose Semantics Assertions

Compose exposes accessibility information through the semantics tree. Test it directly.

### Content Descriptions

```kotlin
import androidx.compose.ui.test.*

@Test
fun avatar_hasContentDescription() {
    composeTestRule.setContent {
        UserAvatar(
            imageUrl = "https://example.com/photo.jpg",
            userName = "Alice"
        )
    }

    composeTestRule
        .onNodeWithTag("user_avatar")
        .assertContentDescriptionEquals("Profile photo of Alice")
}

@Test
fun decorativeImage_hasNoContentDescription() {
    composeTestRule.setContent {
        DecorativeDivider()
    }

    // Decorative elements should be invisible to screen readers
    composeTestRule
        .onNodeWithTag("divider_image")
        .assert(
            SemanticsMatcher("no content description") {
                it.config.getOrNull(SemanticsProperties.ContentDescription) == null
            }
        )
}
```

### Click Actions and Roles

```kotlin
@Test
fun button_hasClickAction() {
    composeTestRule.setContent {
        PrimaryButton(text = "Submit", onClick = {})
    }

    composeTestRule
        .onNodeWithText("Submit")
        .assertHasClickAction()
        .assert(hasAnyAncestor(isRoot())) // reachable from root
}

@Test
fun readOnlyLabel_hasNoClickAction() {
    composeTestRule.setContent {
        StatusLabel(text = "Active")
    }

    composeTestRule
        .onNodeWithText("Active")
        .assertHasNoClickAction()
}

@Test
fun navItem_hasCorrectRole() {
    composeTestRule.setContent {
        BottomNavBar(selectedTab = Tab.HOME)
    }

    composeTestRule
        .onNodeWithText("Home")
        .assert(
            SemanticsMatcher("has Tab role") {
                it.config.getOrNull(SemanticsProperties.Role) == Role.Tab
            }
        )
}
```

### State Descriptions

```kotlin
@Test
fun toggle_announcesSwitchState() {
    composeTestRule.setContent {
        var enabled by remember { mutableStateOf(false) }
        SettingsToggle(
            label = "Dark Mode",
            checked = enabled,
            onCheckedChange = { enabled = it }
        )
    }

    composeTestRule
        .onNodeWithText("Dark Mode")
        .assertIsOff()

    composeTestRule
        .onNodeWithText("Dark Mode")
        .performClick()
        .assertIsOn()
}

@Test
fun dropdown_announcesExpandedState() {
    composeTestRule.setContent {
        CategoryDropdown(selected = "All", options = listOf("All", "Active", "Done"))
    }

    composeTestRule
        .onNodeWithText("All")
        .assert(
            SemanticsMatcher("has collapsed state") {
                it.config.getOrNull(SemanticsProperties.CollectionInfo) != null ||
                    it.config.contains(SemanticsActions.Expand)
            }
        )
}
```

## Touch Target Size Validation

WCAG 2.1 requires touch targets of at least 48dp x 48dp (Android guidance: 48dp).

```kotlin
@Test
fun iconButton_meetsTouchTargetSize() {
    composeTestRule.setContent {
        IconButton(onClick = {}) {
            Icon(Icons.Default.Close, contentDescription = "Close")
        }
    }

    val node = composeTestRule
        .onNodeWithContentDescription("Close")
        .fetchSemanticsNode()

    val bounds = node.boundsInRoot
    val widthDp = with(composeTestRule.density) { (bounds.right - bounds.left).toDp() }
    val heightDp = with(composeTestRule.density) { (bounds.bottom - bounds.top).toDp() }

    assertTrue(
        widthDp >= 48.dp,
        "Touch target width ($widthDp) is below 48dp minimum"
    )
    assertTrue(
        heightDp >= 48.dp,
        "Touch target height ($heightDp) is below 48dp minimum"
    )
}
```

### Batch Touch Target Validation

```kotlin
@Test
fun allClickableElements_meetMinimumTouchTarget() {
    composeTestRule.setContent {
        AppTheme { MainScreen() }
    }

    val clickableNodes = composeTestRule
        .onAllNodes(hasClickAction())
        .fetchSemanticsNodes()

    clickableNodes.forEach { node ->
        val bounds = node.boundsInRoot
        val width = bounds.right - bounds.left
        val height = bounds.bottom - bounds.top
        val minPx = with(composeTestRule.density) { 48.dp.toPx() }

        assertTrue(
            width >= minPx && height >= minPx,
            "Node '${node.config.getOrNull(SemanticsProperties.TestTag) ?: node.id}' " +
                "has touch target ${width}x${height}px, minimum is ${minPx}px"
        )
    }
}
```

## Heading Hierarchy

Screen readers use headings for navigation. Validate heading structure.

```kotlin
@Test
fun screen_hasCorrectHeadingHierarchy() {
    composeTestRule.setContent {
        SettingsScreen()
    }

    // The screen title should be a heading
    composeTestRule
        .onNodeWithText("Settings")
        .assert(
            SemanticsMatcher("is heading") {
                it.config.getOrNull(SemanticsProperties.Heading) != null
            }
        )

    // Section titles should be headings
    composeTestRule
        .onNodeWithText("Account")
        .assert(
            SemanticsMatcher("is heading") {
                it.config.getOrNull(SemanticsProperties.Heading) != null
            }
        )
}
```

## Live Region Testing

```kotlin
@Test
fun errorMessage_isLiveRegion() {
    composeTestRule.setContent {
        var showError by remember { mutableStateOf(false) }
        Column {
            Button(onClick = { showError = true }) { Text("Submit") }
            if (showError) {
                Text(
                    text = "Form has errors",
                    modifier = Modifier.semantics {
                        liveRegion = LiveRegionMode.Assertive
                    }
                )
            }
        }
    }

    composeTestRule.onNodeWithText("Submit").performClick()

    composeTestRule
        .onNodeWithText("Form has errors")
        .assert(
            SemanticsMatcher("is assertive live region") {
                it.config.getOrNull(SemanticsProperties.LiveRegion) == LiveRegionMode.Assertive
            }
        )
}
```

## TalkBack Manual Testing Checklist

Automated tests cannot cover everything. Run through this checklist manually with TalkBack enabled:

1. **Focus order**: Swipe right through the entire screen. Is the order logical (top-to-bottom, left-to-right for LTR)?
2. **All interactive elements reachable**: Can every button, link, toggle, and input be focused?
3. **Announcements are meaningful**: Does each element announce its purpose, role, and state?
4. **No orphaned text**: Is every visible text part of a logical group or labeled element?
5. **Custom actions**: Do complex widgets (sliders, date pickers) expose custom accessibility actions?
6. **Error announcements**: Are validation errors announced immediately when they appear?
7. **Modal dialogs**: Does focus trap inside the dialog? Is the dialog title announced?
8. **Loading states**: Is a loading indicator announced ("Loading, please wait")?
9. **Dynamic content**: Are list updates and content changes announced via live regions?
10. **Dismiss gestures**: Can bottom sheets and dialogs be dismissed with the back gesture?

## Accessibility Scanner

Google's Accessibility Scanner app identifies common issues. For CI automation, use `AccessibilityChecks` from the Espresso accessibility framework:

```kotlin
dependencies {
    androidTestImplementation("androidx.test.espresso:espresso-accessibility:3.6.1")
}
```

```kotlin
import androidx.test.espresso.accessibility.AccessibilityChecks

class AccessibilityIntegrationTest {

    companion object {
        @BeforeClass
        @JvmStatic
        fun enableAccessibilityChecks() {
            AccessibilityChecks.enable()
                .setRunChecksFromRootView(true)
                .setThrowExceptionFor(
                    AccessibilityCheckResult.AccessibilityCheckResultType.ERROR
                )
        }
    }

    @get:Rule
    val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test
    fun mainScreen_passesAccessibilityChecks() {
        // Every Espresso assertion now also runs accessibility checks.
        // Touch target sizes, contrast ratios, labels are all validated.
        onView(withId(R.id.root_layout)).check(matches(isDisplayed()))
    }
}
```

## WCAG 2.1 AA Compliance Checklist for Android

| Criterion | Check | How to Test |
|-----------|-------|-------------|
| 1.1.1 Non-text Content | All images have contentDescription (or null for decorative) | Semantics assertion |
| 1.3.1 Info and Relationships | Headings use `Modifier.semantics { heading() }` | Heading hierarchy test |
| 1.4.3 Contrast (Minimum) | 4.5:1 for normal text, 3:1 for large text | Accessibility Scanner |
| 1.4.11 Non-text Contrast | 3:1 for UI components and graphical objects | Manual review |
| 2.1.1 Keyboard | All functions accessible via keyboard/D-pad | Test with hardware keyboard |
| 2.4.3 Focus Order | Logical navigation order | TalkBack swipe-through |
| 2.4.6 Headings and Labels | Descriptive headings and labels | Semantics tree inspection |
| 2.5.5 Target Size | Touch targets at least 44x44 CSS px (48dp on Android) | Touch target batch test |
| 3.3.1 Error Identification | Errors are described in text | UI test after invalid input |
| 3.3.2 Labels or Instructions | Input fields have visible labels | Semantics assertion |
| 4.1.2 Name, Role, Value | Custom widgets expose correct semantics | Role and state assertions |

## Automated CI Accessibility Checks

Add accessibility checks to existing UI tests by enabling them globally in a base test class:

```kotlin
abstract class BaseAccessibilityTest {

    companion object {
        @BeforeClass
        @JvmStatic
        fun setUp() {
            AccessibilityChecks.enable()
                .setRunChecksFromRootView(true)
        }
    }
}
```

Every subclass that uses Espresso assertions will automatically run accessibility validation on each check. Failures surface in CI as test failures with descriptive messages about the specific WCAG violation.
