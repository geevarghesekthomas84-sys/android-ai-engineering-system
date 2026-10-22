# Push Notifications, Analytics & Crashlytics

## Firebase Cloud Messaging (FCM)

### Setup

1. Add `google-services.json` to `app/` directory (downloaded from Firebase Console)
2. Add dependency: `implementation("com.google.firebase:firebase-messaging-ktx")`

### FirebaseMessagingService

```kotlin
class MyFirebaseMessagingService : FirebaseMessagingService() {

    // Called when a new token is generated
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Send token to your server
        CoroutineScope(Dispatchers.IO).launch {
            saveTokenToServer(token)
        }
    }

    // Called when a message is received
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Data message (always delivered, even in background)
        val data = message.data
        if (data.isNotEmpty()) {
            handleDataMessage(data)
        }

        // Notification message (auto-displayed in background, delivered here in foreground)
        message.notification?.let { notification ->
            showNotification(
                title = notification.title ?: "Notification",
                body = notification.body ?: "",
                data = data
            )
        }
    }

    private fun handleDataMessage(data: Map<String, String>) {
        when (data["type"]) {
            "chat" -> showChatNotification(data)
            "order_update" -> showOrderNotification(data)
            else -> showNotification(
                title = data["title"] ?: "Update",
                body = data["body"] ?: "",
                data = data
            )
        }
    }

    private fun showNotification(title: String, body: String, data: Map<String, String>) {
        val channelId = data["channel"] ?: "default"

        // Deep link intent
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            data.forEach { (key, value) -> putExtra(key, value) }
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private suspend fun saveTokenToServer(token: String) {
        val userId = Firebase.auth.currentUser?.uid ?: return
        Firebase.firestore.collection("users").document(userId)
            .update("fcmToken", token)
    }
}
```

### AndroidManifest.xml

```xml
<service
    android:name=".MyFirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>

<!-- Default notification channel and icon -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="default" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_notification" />
```

### Notification Channels (Android 8+)

```kotlin
class NotificationHelper(private val context: Context) {

    fun createChannels() {
        val channels = listOf(
            NotificationChannel("default", "General", NotificationManager.IMPORTANCE_DEFAULT),
            NotificationChannel("chat", "Chat Messages", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                enableLights(true)
            },
            NotificationChannel("orders", "Order Updates", NotificationManager.IMPORTANCE_DEFAULT),
            NotificationChannel("promo", "Promotions", NotificationManager.IMPORTANCE_LOW)
        )

        val manager = context.getSystemService(NotificationManager::class.java)
        channels.forEach { manager.createNotificationChannel(it) }
    }
}
```

### Topic Subscriptions

```kotlin
// Subscribe to topics
Firebase.messaging.subscribeToTopic("news").await()
Firebase.messaging.subscribeToTopic("deals").await()

// Unsubscribe
Firebase.messaging.unsubscribeFromTopic("promo").await()

// Get current token
val token = Firebase.messaging.token.await()
```

### Send from Cloud Functions

```typescript
import * as admin from "firebase-admin";

// Send to specific device
export const sendToDevice = onCall(async (request) => {
    const { targetToken, title, body, data } = request.data;

    await admin.messaging().send({
        token: targetToken,
        notification: { title, body },
        data: data || {},
        android: {
            priority: "high",
            notification: {
                channelId: "chat",
                clickAction: "OPEN_CHAT",
            },
        },
    });
});

// Send to topic
export const sendToTopic = onCall(async (request) => {
    const { topic, title, body } = request.data;

    await admin.messaging().send({
        topic,
        notification: { title, body },
        android: { priority: "high" },
    });
});

// Send to multiple devices
export const sendMulticast = onCall(async (request) => {
    const { tokens, title, body } = request.data;

    const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
    });

    // Handle failures
    response.responses.forEach((resp, idx) => {
        if (!resp.success) {
            console.error(`Failed to send to ${tokens[idx]}:`, resp.error);
        }
    });
});
```

### Handling Notification Taps (Deep Links)

```kotlin
// In your NavHost or MainActivity
@Composable
fun HandleDeepLink(navController: NavController) {
    val context = LocalContext.current
    val activity = context as? Activity

    LaunchedEffect(Unit) {
        val intent = activity?.intent
        val postId = intent?.getStringExtra("postId")
        val chatId = intent?.getStringExtra("chatId")

        when {
            postId != null -> navController.navigate("post/$postId")
            chatId != null -> navController.navigate("chat/$chatId")
        }
    }
}
```

## Firebase Analytics

### Event Logging

```kotlin
class AnalyticsHelper {
    private val analytics = Firebase.analytics

    // Predefined events
    fun logScreenView(screenName: String, screenClass: String) {
        analytics.logEvent(FirebaseAnalytics.Event.SCREEN_VIEW) {
            param(FirebaseAnalytics.Param.SCREEN_NAME, screenName)
            param(FirebaseAnalytics.Param.SCREEN_CLASS, screenClass)
        }
    }

    fun logPurchase(itemId: String, itemName: String, price: Double, currency: String = "USD") {
        analytics.logEvent(FirebaseAnalytics.Event.PURCHASE) {
            param(FirebaseAnalytics.Param.ITEM_ID, itemId)
            param(FirebaseAnalytics.Param.ITEM_NAME, itemName)
            param(FirebaseAnalytics.Param.VALUE, price)
            param(FirebaseAnalytics.Param.CURRENCY, currency)
        }
    }

    fun logSearch(searchTerm: String) {
        analytics.logEvent(FirebaseAnalytics.Event.SEARCH) {
            param(FirebaseAnalytics.Param.SEARCH_TERM, searchTerm)
        }
    }

    fun logSignUp(method: String) {
        analytics.logEvent(FirebaseAnalytics.Event.SIGN_UP) {
            param(FirebaseAnalytics.Param.METHOD, method)
        }
    }

    // Custom events
    fun logFeatureUsed(featureName: String, details: Map<String, String> = emptyMap()) {
        analytics.logEvent("feature_used") {
            param("feature_name", featureName)
            details.forEach { (key, value) -> param(key, value) }
        }
    }

    fun logButtonClick(buttonName: String, screen: String) {
        analytics.logEvent("button_click") {
            param("button_name", buttonName)
            param("screen", screen)
        }
    }

    // User properties
    fun setUserProperty(name: String, value: String) {
        analytics.setUserProperty(name, value)
    }

    fun setUserTier(tier: String) {
        analytics.setUserProperty("subscription_tier", tier)
    }

    // User ID for cross-device tracking
    fun setUserId(userId: String?) {
        analytics.setUserId(userId)
    }

    // Enable/disable analytics (GDPR compliance)
    fun setAnalyticsEnabled(enabled: Boolean) {
        analytics.setAnalyticsCollectionEnabled(enabled)
    }
}
```

### Debug View

```bash
# Enable debug mode on device (see events in real-time in Firebase Console)
adb shell setprop debug.firebase.analytics.app com.yourapp.package

# Disable debug mode
adb shell setprop debug.firebase.analytics.app .none.
```

### BigQuery Export

Enable in Firebase Console > Project Settings > Integrations > BigQuery. Events are exported daily. Use SQL to analyze:

```sql
SELECT event_name, COUNT(*) as count
FROM `project.analytics_123456789.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20260101' AND '20261231'
GROUP BY event_name
ORDER BY count DESC
```

## Firebase Crashlytics

### Setup

```kotlin
// build.gradle.kts (app)
plugins {
    id("com.google.firebase.crashlytics")
}

dependencies {
    implementation("com.google.firebase:firebase-crashlytics-ktx")
}
```

### Custom Keys and Logging

```kotlin
class CrashlyticsHelper {
    private val crashlytics = Firebase.crashlytics

    // Set custom keys for crash context
    fun setUserContext(userId: String, email: String) {
        crashlytics.setUserId(userId)
        crashlytics.setCustomKey("email", email)
    }

    fun setScreen(screenName: String) {
        crashlytics.setCustomKey("current_screen", screenName)
    }

    // Log breadcrumbs (appear in crash reports)
    fun log(message: String) {
        crashlytics.log(message)
    }

    // Non-fatal error reporting
    fun recordException(throwable: Throwable, context: Map<String, String> = emptyMap()) {
        context.forEach { (key, value) ->
            crashlytics.setCustomKey(key, value)
        }
        crashlytics.recordException(throwable)
    }

    // Enable/disable collection (GDPR)
    fun setCrashlyticsEnabled(enabled: Boolean) {
        crashlytics.setCrashlyticsCollectionEnabled(enabled)
    }
}

// Usage in repository/viewmodel
try {
    val result = apiService.fetchData()
} catch (e: Exception) {
    CrashlyticsHelper().recordException(e, mapOf(
        "endpoint" to "/api/data",
        "retry_count" to retryCount.toString()
    ))
    // Handle error for user
}
```

### Compose Integration for Screen Tracking

```kotlin
@Composable
fun TrackScreen(screenName: String) {
    val analytics = remember { AnalyticsHelper() }
    val crashlytics = remember { CrashlyticsHelper() }

    DisposableEffect(screenName) {
        analytics.logScreenView(screenName, screenName)
        crashlytics.setScreen(screenName)
        onDispose { }
    }
}

// Usage
@Composable
fun HomeScreen() {
    TrackScreen("HomeScreen")
    // Screen content
}
```
