# Material 3 Compose Components Reference

## Scaffold & Layout

### Scaffold
The root layout container providing slots for top bar, bottom bar, FAB, and snackbar.

```kotlin
val snackbarHostState = remember { SnackbarHostState() }

Scaffold(
    topBar = { /* TopAppBar */ },
    bottomBar = { /* NavigationBar */ },
    floatingActionButton = { /* FAB */ },
    snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
    contentWindowInsets = ScaffoldDefaults.contentWindowInsets,
) { innerPadding ->
    Content(modifier = Modifier.padding(innerPadding))
}
```

## Top App Bars

### SmallTopAppBar
```kotlin
@OptIn(ExperimentalMaterial3Api::class)
TopAppBar(
    title = { Text("Page Title") },
    navigationIcon = {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Navigate back")
        }
    },
    actions = {
        IconButton(onClick = onSearch) {
            Icon(Icons.Default.Search, contentDescription = "Search")
        }
    },
    scrollBehavior = TopAppBarDefaults.pinnedScrollBehavior(),
)
```

### MediumTopAppBar
Expands title area on scroll. Use `exitUntilCollapsedScrollBehavior()`.

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
MediumTopAppBar(
    title = { Text("Medium Title") },
    scrollBehavior = scrollBehavior,
)
// Apply Modifier.nestedScroll(scrollBehavior.nestedScrollConnection) to scrollable content.
```

### LargeTopAppBar
Large headline that collapses on scroll.

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
LargeTopAppBar(
    title = { Text("Large Title") },
    scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(),
)
```

### CenterAlignedTopAppBar
```kotlin
@OptIn(ExperimentalMaterial3Api::class)
CenterAlignedTopAppBar(
    title = { Text("Centered") },
    navigationIcon = { IconButton(onClick = onMenu) { Icon(Icons.Default.Menu, "Menu") } },
)
```

## Navigation

### NavigationBar (Bottom)
```kotlin
NavigationBar {
    NavigationBarItem(
        selected = currentRoute == "home",
        onClick = { navigateTo("home") },
        icon = { Icon(Icons.Default.Home, contentDescription = "Home") },
        label = { Text("Home") },
    )
    NavigationBarItem(
        selected = currentRoute == "search",
        onClick = { navigateTo("search") },
        icon = { Icon(Icons.Default.Search, contentDescription = "Search") },
        label = { Text("Search") },
    )
    NavigationBarItem(
        selected = currentRoute == "profile",
        onClick = { navigateTo("profile") },
        icon = { Icon(Icons.Default.Person, contentDescription = "Profile") },
        label = { Text("Profile") },
    )
}
```

### NavigationRail (Side)
For medium and expanded screens (tablets, foldables).

```kotlin
NavigationRail(
    header = {
        FloatingActionButton(onClick = onCompose) {
            Icon(Icons.Default.Edit, contentDescription = "Compose")
        }
    },
) {
    NavigationRailItem(
        selected = currentRoute == "inbox",
        onClick = { navigateTo("inbox") },
        icon = { Icon(Icons.Default.Email, contentDescription = "Inbox") },
        label = { Text("Inbox") },
    )
}
```

### NavigationDrawer
```kotlin
val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)

ModalNavigationDrawer(
    drawerState = drawerState,
    drawerContent = {
        ModalDrawerSheet {
            Text("App Name", modifier = Modifier.padding(16.dp), style = MaterialTheme.typography.titleLarge)
            HorizontalDivider()
            NavigationDrawerItem(
                label = { Text("Home") },
                selected = currentRoute == "home",
                onClick = { navigateTo("home") },
                icon = { Icon(Icons.Default.Home, contentDescription = null) },
            )
        }
    },
) {
    Scaffold { /* content */ }
}
```

## Cards

### FilledCard
```kotlin
Card(
    modifier = Modifier.fillMaxWidth(),
    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHighest),
) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text("Filled Card Title", style = MaterialTheme.typography.titleMedium)
        Text("Supporting text", style = MaterialTheme.typography.bodyMedium)
    }
}
```

### ElevatedCard
```kotlin
ElevatedCard(
    modifier = Modifier.fillMaxWidth(),
    elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp),
) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text("Elevated Card", style = MaterialTheme.typography.titleMedium)
    }
}
```

### OutlinedCard
```kotlin
OutlinedCard(modifier = Modifier.fillMaxWidth()) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text("Outlined Card", style = MaterialTheme.typography.titleMedium)
    }
}
```

## Buttons

```kotlin
// Filled button (highest emphasis)
Button(onClick = onConfirm) { Text("Confirm") }

// Filled tonal (medium emphasis)
FilledTonalButton(onClick = onSave) { Text("Save") }

// Outlined (medium-low emphasis)
OutlinedButton(onClick = onCancel) { Text("Cancel") }

// Text button (low emphasis)
TextButton(onClick = onSkip) { Text("Skip") }

// Elevated
ElevatedButton(onClick = onAction) { Text("Action") }

// Icon button
IconButton(onClick = onFavorite) {
    Icon(Icons.Default.FavoriteBorder, contentDescription = "Add to favorites")
}

// Filled icon button
FilledIconButton(onClick = onAdd) {
    Icon(Icons.Default.Add, contentDescription = "Add item")
}
```

## Floating Action Buttons

```kotlin
// Standard FAB
FloatingActionButton(onClick = onAdd) {
    Icon(Icons.Default.Add, contentDescription = "Add")
}

// Small FAB
SmallFloatingActionButton(onClick = onAdd) {
    Icon(Icons.Default.Add, contentDescription = "Add")
}

// Large FAB
LargeFloatingActionButton(onClick = onAdd) {
    Icon(Icons.Default.Add, contentDescription = "Add")
}

// Extended FAB
ExtendedFloatingActionButton(
    onClick = onCompose,
    icon = { Icon(Icons.Default.Edit, contentDescription = null) },
    text = { Text("Compose") },
)
```

## Text Fields

```kotlin
var text by remember { mutableStateOf("") }

// Filled text field
TextField(
    value = text,
    onValueChange = { text = it },
    label = { Text("Email") },
    leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
    supportingText = { Text("Enter your email address") },
    isError = !isValidEmail(text),
    singleLine = true,
    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
)

// Outlined text field
OutlinedTextField(
    value = text,
    onValueChange = { text = it },
    label = { Text("Password") },
    leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null) },
    trailingIcon = {
        IconButton(onClick = { passwordVisible = !passwordVisible }) {
            Icon(
                if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                contentDescription = if (passwordVisible) "Hide password" else "Show password",
            )
        }
    },
    visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
    singleLine = true,
)
```

## Selection Controls

```kotlin
// Switch
var checked by remember { mutableStateOf(false) }
Switch(checked = checked, onCheckedChange = { checked = it })

// Checkbox
var checked by remember { mutableStateOf(false) }
Checkbox(checked = checked, onCheckedChange = { checked = it })

// RadioButton (in a group)
val options = listOf("Option A", "Option B", "Option C")
var selected by remember { mutableStateOf(options[0]) }
options.forEach { option ->
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .selectable(selected = selected == option, onClick = { selected = option })
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        RadioButton(selected = selected == option, onClick = null)
        Text(option, modifier = Modifier.padding(start = 8.dp))
    }
}

// Slider
var sliderValue by remember { mutableFloatStateOf(0.5f) }
Slider(value = sliderValue, onValueChange = { sliderValue = it })
```

## Dialogs

```kotlin
AlertDialog(
    onDismissRequest = onDismiss,
    icon = { Icon(Icons.Default.Warning, contentDescription = null) },
    title = { Text("Confirm Delete") },
    text = { Text("This action cannot be undone. Are you sure?") },
    confirmButton = {
        TextButton(onClick = onConfirm) { Text("Delete") }
    },
    dismissButton = {
        TextButton(onClick = onDismiss) { Text("Cancel") }
    },
)
```

## Bottom Sheet

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
val sheetState = rememberModalBottomSheetState()

ModalBottomSheet(
    onDismissRequest = onDismiss,
    sheetState = sheetState,
) {
    Column(modifier = Modifier.padding(16.dp)) {
        Text("Choose an option", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(16.dp))
        ListItem(
            headlineContent = { Text("Camera") },
            leadingContent = { Icon(Icons.Default.CameraAlt, contentDescription = null) },
            modifier = Modifier.clickable { onCamera() },
        )
        ListItem(
            headlineContent = { Text("Gallery") },
            leadingContent = { Icon(Icons.Default.PhotoLibrary, contentDescription = null) },
            modifier = Modifier.clickable { onGallery() },
        )
        Spacer(modifier = Modifier.height(32.dp))
    }
}
```

## Chips

```kotlin
// Filter chip
var selected by remember { mutableStateOf(false) }
FilterChip(
    selected = selected,
    onClick = { selected = !selected },
    label = { Text("Filter") },
    leadingIcon = if (selected) {{ Icon(Icons.Default.Done, contentDescription = null, modifier = Modifier.size(FilterChipDefaults.IconSize)) }} else null,
)

// Assist chip
AssistChip(
    onClick = onAction,
    label = { Text("Assist") },
    leadingIcon = { Icon(Icons.Default.Event, contentDescription = null, modifier = Modifier.size(AssistChipDefaults.IconSize)) },
)

// Input chip
InputChip(
    selected = true,
    onClick = onRemove,
    label = { Text("Tag") },
    trailingIcon = { Icon(Icons.Default.Close, contentDescription = "Remove tag", modifier = Modifier.size(InputChipDefaults.IconSize)) },
)

// Suggestion chip
SuggestionChip(onClick = onSuggest, label = { Text("Suggestion") })
```

## Badge

```kotlin
BadgedBox(badge = { Badge { Text("3") } }) {
    Icon(Icons.Default.Notifications, contentDescription = "Notifications")
}
```

## Search Bar

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
var query by rememberSaveable { mutableStateOf("") }
var expanded by rememberSaveable { mutableStateOf(false) }

SearchBar(
    inputField = {
        SearchBarDefaults.InputField(
            query = query,
            onQueryChange = { query = it },
            onSearch = { expanded = false },
            expanded = expanded,
            onExpandedChange = { expanded = it },
            placeholder = { Text("Search") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            trailingIcon = if (query.isNotEmpty()) {{
                IconButton(onClick = { query = "" }) {
                    Icon(Icons.Default.Close, contentDescription = "Clear search")
                }
            }} else null,
        )
    },
    expanded = expanded,
    onExpandedChange = { expanded = it },
) {
    // Search suggestions content
}
```

## Date Picker

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
val datePickerState = rememberDatePickerState()

DatePickerDialog(
    onDismissRequest = onDismiss,
    confirmButton = {
        TextButton(onClick = { onDateSelected(datePickerState.selectedDateMillis) }) {
            Text("OK")
        }
    },
    dismissButton = {
        TextButton(onClick = onDismiss) { Text("Cancel") }
    },
) {
    DatePicker(state = datePickerState)
}
```

## Time Picker

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
val timePickerState = rememberTimePickerState(initialHour = 12, initialMinute = 0)

AlertDialog(
    onDismissRequest = onDismiss,
    confirmButton = {
        TextButton(onClick = { onTimeSelected(timePickerState.hour, timePickerState.minute) }) {
            Text("OK")
        }
    },
    dismissButton = {
        TextButton(onClick = onDismiss) { Text("Cancel") }
    },
    text = { TimePicker(state = timePickerState) },
)
```

## Snackbar

```kotlin
val snackbarHostState = remember { SnackbarHostState() }
val scope = rememberCoroutineScope()

// Show snackbar
scope.launch {
    val result = snackbarHostState.showSnackbar(
        message = "Item deleted",
        actionLabel = "Undo",
        duration = SnackbarDuration.Short,
    )
    if (result == SnackbarResult.ActionPerformed) {
        undoDelete()
    }
}
```

## ListItem

```kotlin
ListItem(
    headlineContent = { Text("Title") },
    supportingContent = { Text("Supporting text") },
    leadingContent = {
        Icon(Icons.Default.Person, contentDescription = null)
    },
    trailingContent = {
        Switch(checked = enabled, onCheckedChange = { enabled = it })
    },
)
```
