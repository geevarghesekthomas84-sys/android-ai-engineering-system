# Premium Screen Design Recipes

## Login / Register Screen

Material 3 authentication flow with email and password, social sign-in options, and branded header.

**Components**: Scaffold, Column, Text, OutlinedTextField, Button, TextButton, HorizontalDivider, OutlinedButton with icon.

```kotlin
@Composable
fun LoginScreen(
    onLogin: (email: String, password: String) -> Unit,
    onRegister: () -> Unit,
    onForgotPassword: () -> Unit,
    onGoogleSignIn: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var passwordVisible by rememberSaveable { mutableStateOf(false) }

    Scaffold(modifier = modifier) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(modifier = Modifier.height(80.dp))

            // App logo / branding area
            Icon(
                imageVector = Icons.Default.Lock,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text("Welcome Back", style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                "Sign in to your account",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(40.dp))

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email") },
                leadingIcon = { Icon(Icons.Default.Email, contentDescription = null) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(16.dp))

            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
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
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(8.dp))

            TextButton(onClick = onForgotPassword, modifier = Modifier.align(Alignment.End)) {
                Text("Forgot password?")
            }
            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = { onLogin(email, password) },
                modifier = Modifier.fillMaxWidth().height(50.dp),
                enabled = email.isNotBlank() && password.isNotBlank(),
            ) {
                Text("Sign In")
            }
            Spacer(modifier = Modifier.height(24.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                HorizontalDivider(modifier = Modifier.weight(1f))
                Text("OR", modifier = Modifier.padding(horizontal = 16.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                HorizontalDivider(modifier = Modifier.weight(1f))
            }
            Spacer(modifier = Modifier.height(24.dp))

            OutlinedButton(
                onClick = onGoogleSignIn,
                modifier = Modifier.fillMaxWidth().height(50.dp),
            ) {
                Text("Continue with Google")
            }
            Spacer(modifier = Modifier.height(32.dp))

            Row {
                Text("Don't have an account? ", style = MaterialTheme.typography.bodyMedium)
                TextButton(onClick = onRegister, contentPadding = PaddingValues(0.dp)) {
                    Text("Sign Up")
                }
            }
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}
```

## Dashboard Screen

Stats cards in a grid, quick actions, and recent activity list.

**Components**: Scaffold, LargeTopAppBar, LazyVerticalGrid, ElevatedCard, ListItem, HorizontalDivider.

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(stats: List<StatItem>, recentItems: List<ActivityItem>, modifier: Modifier = Modifier) {
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()

    Scaffold(
        topBar = {
            LargeTopAppBar(
                title = { Text("Dashboard") },
                actions = {
                    IconButton(onClick = { /* notifications */ }) {
                        BadgedBox(badge = { Badge { Text("5") } }) {
                            Icon(Icons.Default.Notifications, contentDescription = "Notifications")
                        }
                    }
                },
                scrollBehavior = scrollBehavior,
            )
        },
        modifier = modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
    ) { innerPadding ->
        LazyColumn(
            contentPadding = innerPadding,
            modifier = Modifier.fillMaxSize(),
        ) {
            // Stats grid
            item {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    contentPadding = PaddingValues(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.height(220.dp), // sized to fit 2 rows
                ) {
                    items(stats) { stat ->
                        StatCard(stat = stat)
                    }
                }
            }

            // Section header
            item {
                Text(
                    "Recent Activity",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }

            // Recent activity list
            items(recentItems) { item ->
                ListItem(
                    headlineContent = { Text(item.title) },
                    supportingContent = { Text(item.subtitle) },
                    leadingContent = {
                        FilledTonalIconButton(onClick = {}) {
                            Icon(item.icon, contentDescription = null)
                        }
                    },
                    trailingContent = { Text(item.time, style = MaterialTheme.typography.labelSmall) },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
            }
        }
    }
}

@Composable
fun StatCard(stat: StatItem, modifier: Modifier = Modifier) {
    ElevatedCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Icon(stat.icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(24.dp))
            Spacer(modifier = Modifier.height(12.dp))
            Text(stat.value, style = MaterialTheme.typography.headlineSmall)
            Text(stat.label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

data class StatItem(val label: String, val value: String, val icon: ImageVector)
data class ActivityItem(val title: String, val subtitle: String, val time: String, val icon: ImageVector)
```

## E-commerce Product List / Detail

Product grid with images, prices, and ratings. Detail view with image, description, and add-to-cart.

**Components**: LazyVerticalGrid, ElevatedCard, AsyncImage, TopAppBar, Button, OutlinedButton.

```kotlin
@Composable
fun ProductGrid(products: List<Product>, onProductClick: (Product) -> Unit, modifier: Modifier = Modifier) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 160.dp),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = modifier,
    ) {
        items(products, key = { it.id }) { product ->
            ElevatedCard(
                onClick = { onProductClick(product) },
            ) {
                Column {
                    AsyncImage(
                        model = product.imageUrl,
                        contentDescription = product.name,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxWidth().aspectRatio(1f),
                    )
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text(product.name, style = MaterialTheme.typography.titleSmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("$${product.price}", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFFFFC107))
                            Text(" ${product.rating}", style = MaterialTheme.typography.bodySmall)
                            Text(" (${product.reviewCount})", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        }
    }
}
```

## Finance Overview

Balance display, quick action row, transaction list with categorized icons.

**Components**: Card, LazyColumn, ListItem, FilledTonalButton, HorizontalDivider.

```kotlin
@Composable
fun FinanceOverview(balance: String, transactions: List<Transaction>, modifier: Modifier = Modifier) {
    LazyColumn(modifier = modifier.fillMaxSize()) {
        // Balance card
        item {
            Card(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
            ) {
                Column(modifier = Modifier.padding(24.dp)) {
                    Text("Total Balance", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f))
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(balance, style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.onPrimaryContainer)
                }
            }
        }

        // Quick actions
        item {
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                QuickAction(icon = Icons.Default.ArrowUpward, label = "Send", modifier = Modifier.weight(1f), onClick = {})
                QuickAction(icon = Icons.Default.ArrowDownward, label = "Receive", modifier = Modifier.weight(1f), onClick = {})
                QuickAction(icon = Icons.Default.SwapHoriz, label = "Transfer", modifier = Modifier.weight(1f), onClick = {})
                QuickAction(icon = Icons.Default.MoreHoriz, label = "More", modifier = Modifier.weight(1f), onClick = {})
            }
        }

        item {
            Text("Transactions", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(start = 16.dp, top = 24.dp, bottom = 8.dp))
        }

        items(transactions) { tx ->
            ListItem(
                headlineContent = { Text(tx.title) },
                supportingContent = { Text(tx.date) },
                leadingContent = {
                    FilledTonalIconButton(onClick = {}) { Icon(tx.icon, contentDescription = null) }
                },
                trailingContent = {
                    Text(
                        tx.amount,
                        color = if (tx.isIncome) Color(0xFF2E7D32) else MaterialTheme.colorScheme.onSurface,
                        style = MaterialTheme.typography.titleSmall,
                    )
                },
            )
        }
    }
}

@Composable
private fun QuickAction(icon: ImageVector, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        FilledTonalIconButton(onClick = onClick) { Icon(icon, contentDescription = label) }
        Spacer(modifier = Modifier.height(4.dp))
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}

data class Transaction(val title: String, val date: String, val amount: String, val isIncome: Boolean, val icon: ImageVector)
```

## Cybersecurity Dashboard

Threat level indicator, scan status, device health, recent alerts.

**Components**: Card, LinearProgressIndicator, ListItem, Badge, ElevatedCard.

```kotlin
@Composable
fun SecurityDashboard(
    threatLevel: ThreatLevel,
    scanProgress: Float?,
    deviceHealth: List<DeviceHealth>,
    alerts: List<SecurityAlert>,
    onScan: () -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(modifier = modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        // Threat level card
        item {
            val containerColor = when (threatLevel) {
                ThreatLevel.SAFE -> Color(0xFF2E7D32)
                ThreatLevel.WARNING -> Color(0xFFF57F17)
                ThreatLevel.CRITICAL -> MaterialTheme.colorScheme.error
            }
            Card(colors = CardDefaults.cardColors(containerColor = containerColor)) {
                Column(modifier = Modifier.padding(24.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        when (threatLevel) {
                            ThreatLevel.SAFE -> Icons.Default.Shield
                            ThreatLevel.WARNING -> Icons.Default.Warning
                            ThreatLevel.CRITICAL -> Icons.Default.Error
                        },
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = Color.White,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(threatLevel.name, style = MaterialTheme.typography.headlineSmall, color = Color.White)
                    Text("System Status", style = MaterialTheme.typography.bodyMedium, color = Color.White.copy(alpha = 0.8f))
                }
            }
        }

        // Scan button / progress
        item {
            ElevatedCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Security Scan", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(12.dp))
                    if (scanProgress != null) {
                        LinearProgressIndicator(progress = { scanProgress }, modifier = Modifier.fillMaxWidth())
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("${(scanProgress * 100).toInt()}% complete", style = MaterialTheme.typography.bodySmall)
                    } else {
                        Button(onClick = onScan, modifier = Modifier.fillMaxWidth()) { Text("Run Full Scan") }
                    }
                }
            }
        }

        // Device health
        item { Text("Device Health", style = MaterialTheme.typography.titleMedium) }
        items(deviceHealth) { health ->
            ListItem(
                headlineContent = { Text(health.name) },
                supportingContent = { Text(health.status) },
                leadingContent = { Icon(health.icon, contentDescription = null, tint = if (health.isHealthy) Color(0xFF2E7D32) else MaterialTheme.colorScheme.error) },
                trailingContent = {
                    if (health.isHealthy) Icon(Icons.Default.CheckCircle, contentDescription = "Healthy", tint = Color(0xFF2E7D32))
                    else Icon(Icons.Default.Warning, contentDescription = "Issue detected", tint = MaterialTheme.colorScheme.error)
                },
            )
        }

        // Recent alerts
        item { Text("Recent Alerts", style = MaterialTheme.typography.titleMedium) }
        items(alerts) { alert ->
            OutlinedCard(modifier = Modifier.fillMaxWidth()) {
                ListItem(
                    headlineContent = { Text(alert.title) },
                    supportingContent = { Text(alert.description) },
                    overlineContent = { Text(alert.timestamp) },
                    leadingContent = {
                        Badge(containerColor = if (alert.isCritical) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.tertiary) {
                            Text(if (alert.isCritical) "!" else "i")
                        }
                    },
                )
            }
        }
    }
}

enum class ThreatLevel { SAFE, WARNING, CRITICAL }
data class DeviceHealth(val name: String, val status: String, val isHealthy: Boolean, val icon: ImageVector)
data class SecurityAlert(val title: String, val description: String, val timestamp: String, val isCritical: Boolean)
```

## Settings Screen

Categorized preference groups with switches, navigation items, and section headers.

**Components**: Scaffold, TopAppBar, LazyColumn, ListItem, Switch, Icon, HorizontalDivider, Text.

```kotlin
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onBack: () -> Unit, modifier: Modifier = Modifier) {
    var darkMode by rememberSaveable { mutableStateOf(false) }
    var notifications by rememberSaveable { mutableStateOf(true) }
    var biometric by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Navigate back")
                    }
                },
            )
        },
        modifier = modifier,
    ) { innerPadding ->
        LazyColumn(contentPadding = innerPadding) {
            // Account section
            item { SettingsSectionHeader("Account") }
            item {
                ListItem(
                    headlineContent = { Text("Profile") },
                    supportingContent = { Text("Name, email, photo") },
                    leadingContent = { Icon(Icons.Default.Person, contentDescription = null) },
                    trailingContent = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null) },
                    modifier = Modifier.clickable { /* navigate */ },
                )
            }
            item {
                ListItem(
                    headlineContent = { Text("Security") },
                    supportingContent = { Text("Password, two-factor auth") },
                    leadingContent = { Icon(Icons.Default.Security, contentDescription = null) },
                    trailingContent = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null) },
                    modifier = Modifier.clickable { /* navigate */ },
                )
            }

            // Preferences section
            item { SettingsSectionHeader("Preferences") }
            item {
                ListItem(
                    headlineContent = { Text("Dark Mode") },
                    supportingContent = { Text("Use dark theme") },
                    leadingContent = { Icon(Icons.Default.DarkMode, contentDescription = null) },
                    trailingContent = { Switch(checked = darkMode, onCheckedChange = { darkMode = it }) },
                )
            }
            item {
                ListItem(
                    headlineContent = { Text("Notifications") },
                    supportingContent = { Text("Push and email alerts") },
                    leadingContent = { Icon(Icons.Default.Notifications, contentDescription = null) },
                    trailingContent = { Switch(checked = notifications, onCheckedChange = { notifications = it }) },
                )
            }
            item {
                ListItem(
                    headlineContent = { Text("Biometric Login") },
                    supportingContent = { Text("Use fingerprint or face") },
                    leadingContent = { Icon(Icons.Default.Fingerprint, contentDescription = null) },
                    trailingContent = { Switch(checked = biometric, onCheckedChange = { biometric = it }) },
                )
            }

            // About section
            item { SettingsSectionHeader("About") }
            item {
                ListItem(
                    headlineContent = { Text("App Version") },
                    supportingContent = { Text("1.0.0 (Build 42)") },
                    leadingContent = { Icon(Icons.Default.Info, contentDescription = null) },
                )
            }
            item {
                ListItem(
                    headlineContent = { Text("Privacy Policy") },
                    leadingContent = { Icon(Icons.Default.Policy, contentDescription = null) },
                    trailingContent = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null) },
                    modifier = Modifier.clickable { /* open browser */ },
                )
            }
        }
    }
}

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, top = 24.dp, bottom = 8.dp),
    )
}
```
