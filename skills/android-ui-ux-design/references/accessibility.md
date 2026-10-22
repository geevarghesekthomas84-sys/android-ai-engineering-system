# Accessibility in Compose

## Content Descriptions

Every meaningful image, icon, and visual element needs a `contentDescription` for screen readers.

```kotlin
// Informative icon: describe what it represents
Icon(Icons.Default.Favorite, contentDescription = "Favorited")

// Decorative icon: set null to hide from screen readers
Icon(Icons.Default.ChevronRight, contentDescription = null)

// Image with description
Image(
    painter = painterResource(R.drawable.product_photo),
    contentDescription = "Blue running shoes, side view",
)
```

## Modifier.semantics

Add semantic information that assistive technologies use.

```kotlin
// Heading for screen structure
Text(
    text = "Account Settings",
    style = MaterialTheme.typography.headlineMedium,
    modifier = Modifier.semantics { heading() },
)

// State description for custom components
Box(
    modifier = Modifier.semantics {
        stateDescription = if (isExpanded) "Expanded" else "Collapsed"
        role = Role.Button
        contentDescription = "Details section"
    },
)

// Custom action
Row(
    modifier = Modifier.semantics {
        customActions = listOf(
            CustomAccessibilityAction("Delete item") {
                onDelete()
                true
            },
            CustomAccessibilityAction("Archive item") {
                onArchive()
                true
            },
        )
    },
) {
    // content
}
```

## mergeDescendants

Merge child semantics into a single focusable unit. Use for list items and interactive cards where children should not be individually focusable.

```kotlin
Row(
    modifier = Modifier
        .clickable { onClick() }
        .semantics(mergeDescendants = true) { },
) {
    Icon(Icons.Default.Email, contentDescription = null)
    Column {
        Text("New message from Alex")
        Text("Hey, are you free tomorrow?")
    }
}
// TalkBack reads: "New message from Alex. Hey, are you free tomorrow?"
```

## clearAndSetSemantics

Replace all child semantics with a single description. Use when the default merging produces confusing output.

```kotlin
Row(
    modifier = Modifier
        .clickable { onToggle() }
        .clearAndSetSemantics {
            contentDescription = "Dark mode"
            stateDescription = if (isDarkMode) "On" else "Off"
            role = Role.Switch
        },
) {
    Text("Dark Mode")
    Spacer(modifier = Modifier.weight(1f))
    Switch(checked = isDarkMode, onCheckedChange = null)
}
// TalkBack reads: "Dark mode, On, Switch, double tap to toggle"
```

## Live Regions

Announce dynamic content changes to screen readers without user focus.

```kotlin
// Polite: waits for current speech to finish
Text(
    text = "3 new notifications",
    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
)

// Assertive: interrupts current speech (use sparingly)
Text(
    text = errorMessage,
    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
    color = MaterialTheme.colorScheme.error,
)
```

## Touch Target Sizing

Material 3 enforces 48dp minimum touch targets. Compose handles this for standard components. For custom components, ensure minimum size.

```kotlin
// Bad: icon too small for touch
IconButton(onClick = onAction) { // IconButton already ensures 48dp touch target
    Icon(Icons.Default.Close, contentDescription = "Close", modifier = Modifier.size(24.dp))
}

// Custom clickable with minimum touch target
Box(
    modifier = Modifier
        .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
        .clickable(
            onClick = onAction,
            role = Role.Button,
            onClickLabel = "Dismiss notification",
        ),
    contentAlignment = Alignment.Center,
) {
    Icon(Icons.Default.Close, contentDescription = null, modifier = Modifier.size(16.dp))
}
```

## Contrast Ratios

WCAG 2.1 minimum contrast requirements:

| Text Type | Minimum Ratio | Notes |
|---|---|---|
| Normal text (< 18sp) | 4.5:1 | Body, labels, captions |
| Large text (>= 18sp or >= 14sp bold) | 3:1 | Headlines, titles |
| UI components & graphics | 3:1 | Icons, borders, focus indicators |

Material 3 color roles are designed to meet these ratios when used correctly:
- `onPrimary` on `primary`: meets 4.5:1
- `onSurface` on `surface`: meets 4.5:1
- `onSurfaceVariant` on `surface`: meets 4.5:1

Never use `primary` on `primaryContainer` or other non-paired roles without checking contrast.

```kotlin
// Correct pairings
Text(
    text = "Button label",
    color = MaterialTheme.colorScheme.onPrimary, // on primary surface
)
Text(
    text = "Card text",
    color = MaterialTheme.colorScheme.onSurface, // on surface
)
```

## Accessible Forms

```kotlin
@Composable
fun AccessibleForm() {
    var email by remember { mutableStateOf("") }
    var emailError by remember { mutableStateOf<String?>(null) }

    Column {
        Text(
            text = "Sign In",
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.semantics { heading() },
        )
        Spacer(modifier = Modifier.height(24.dp))
        OutlinedTextField(
            value = email,
            onValueChange = {
                email = it
                emailError = null
            },
            label = { Text("Email address") },
            isError = emailError != null,
            supportingText = emailError?.let { { Text(it) } },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
// TextField automatically announces: label, current text, error state, and supporting text
```

## Traversal Order

Control the order screen readers traverse elements.

```kotlin
Column(modifier = Modifier.semantics { traversalIndex = 0f }) {
    // Read first
}
Column(modifier = Modifier.semantics { traversalIndex = 1f }) {
    // Read second
}
```

## Testing Accessibility

### With TalkBack
1. Enable TalkBack in Settings > Accessibility > TalkBack.
2. Swipe right to move to the next element. Verify every interactive element is reachable.
3. Verify all elements have meaningful descriptions.
4. Verify state changes are announced.

### With Accessibility Scanner
1. Install Accessibility Scanner from Play Store.
2. Run it on each screen.
3. Fix flagged issues: low contrast, small touch targets, missing labels.

### In Tests

```kotlin
@Test
fun loginButton_hasCorrectSemantics() {
    composeTestRule.setContent { LoginScreen() }

    composeTestRule
        .onNodeWithText("Sign In")
        .assertIsEnabled()
        .assertHasClickAction()

    composeTestRule
        .onNodeWithContentDescription("Email address")
        .assertExists()

    // Verify heading semantics
    composeTestRule
        .onNode(hasText("Sign In") and isHeading())
        .assertExists()
}
```

## Checklist

- [ ] All images and icons have appropriate `contentDescription` (informative) or `null` (decorative)
- [ ] Interactive elements have 48dp minimum touch targets
- [ ] Color contrast meets WCAG 4.5:1 for normal text, 3:1 for large text
- [ ] Screen headings use `semantics { heading() }` for structure
- [ ] Form fields have labels (via `label` parameter in TextField)
- [ ] Error states are announced via `isError` and `supportingText`
- [ ] Dynamic updates use `liveRegion` when relevant
- [ ] Complex custom components use `clearAndSetSemantics` for clean screen reader output
- [ ] List items use `mergeDescendants` for atomic reading
- [ ] Tested with TalkBack enabled on a real device or emulator
