# Production Monitoring

## Crashlytics Setup

### Dependencies

```kotlin
// build.gradle.kts (project)
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.3" apply false
}

// app/build.gradle.kts
plugins {
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-crashlytics-ktx")
    implementation("com.google.firebase:firebase-analytics-ktx")
}
```

### Initialization and Configuration

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Disable Crashlytics in debug builds
        FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(!BuildConfig.DEBUG)
    }
}
```

### Custom Keys

Attach key-value pairs to crash reports for additional context:

```kotlin
FirebaseCrashlytics.getInstance().apply {
    setCustomKey("user_tier", "premium")
    setCustomKey("screen", "checkout")
    setCustomKey("cart_item_count", 3)
    setCustomKey("api_version", "v2")
    setUserId("user-12345")  // Set user ID for tracking
}
```

### Breadcrumbs (Custom Logs)

Leave breadcrumbs leading up to a crash:

```kotlin
FirebaseCrashlytics.getInstance().log("User tapped checkout button")
FirebaseCrashlytics.getInstance().log("Payment method: credit_card")
FirebaseCrashlytics.getInstance().log("Initiating payment request to /api/v2/payments")
```

### Non-Fatal Error Logging

Record handled exceptions that do not crash the app:

```kotlin
try {
    val result = apiService.fetchUserProfile()
    processProfile(result)
} catch (e: HttpException) {
    FirebaseCrashlytics.getInstance().apply {
        setCustomKey("http_status", e.code())
        setCustomKey("endpoint", "/api/v2/profile")
        recordException(e)
    }
    showErrorToUser("Could not load profile")
}
```

### Deobfuscation with Mapping File

The Crashlytics Gradle plugin automatically uploads mapping files during release builds. Verify with:

```bash
# The plugin uploads mapping.txt after assembleRelease or bundleRelease
./gradlew assembleRelease  # mapping.txt uploaded automatically

# Verify mapping file exists
ls -la app/build/outputs/mapping/release/mapping.txt
```

For CI builds, ensure the `google-services.json` is present and the Crashlytics plugin is applied. The mapping file upload happens as a post-build task.

To manually upload a mapping file:

```bash
firebase crashlytics:mappingfile:upload \
    --app=1:123456789:android:abcdef \
    --resource-file=app/build/outputs/mapping/release/mapping.txt
```

## Firebase Performance Monitoring

### Setup

```kotlin
dependencies {
    implementation("com.google.firebase:firebase-perf-ktx")
}

// app/build.gradle.kts
plugins {
    id("com.google.firebase.firebase-perf") version "1.4.2"
}
```

### Custom Traces

```kotlin
val trace = Firebase.performance.newTrace("checkout_flow")
trace.start()
trace.putAttribute("payment_method", "credit_card")
trace.incrementMetric("items_purchased", cartItems.size.toLong())

// After operation completes
trace.stop()
```

### HTTP Metrics

Firebase Performance automatically monitors HTTP/S requests made via OkHttp. For custom network monitoring:

```kotlin
val metric = Firebase.performance.newHttpMetric(
    "https://api.example.com/orders",
    FirebasePerformance.HttpMethod.POST
)
metric.setRequestPayloadSize(requestBody.contentLength())
metric.start()

val response = httpClient.execute(request)

metric.setHttpResponseCode(response.code)
metric.setResponsePayloadSize(response.body?.contentLength() ?: 0)
metric.stop()
```

## Sentry (Alternative to Crashlytics)

### Setup

```kotlin
dependencies {
    implementation("io.sentry:sentry-android:7.19.0")
}
```

```xml
<!-- AndroidManifest.xml -->
<meta-data
    android:name="io.sentry.dsn"
    android:value="https://examplePublicKey@o0.ingest.sentry.io/0" />
<meta-data
    android:name="io.sentry.traces.sample-rate"
    android:value="0.2" />
```

### Structured error context

```kotlin
Sentry.configureScope { scope ->
    scope.setTag("payment_provider", "stripe")
    scope.setExtra("cart_total", cartTotal.toString())
    scope.user = User().apply { id = userId }
}

Sentry.captureException(exception) { scope ->
    scope.setContexts("order", mapOf("orderId" to orderId, "amount" to amount))
}
```

## Structured Logging

### Backend structured logging (NestJS)

```typescript
import { Logger } from '@nestjs/common';

const logger = new Logger('PaymentService');

logger.log({
  message: 'Payment processed',
  orderId: order.id,
  amount: order.total,
  currency: order.currency,
  provider: 'stripe',
  duration_ms: endTime - startTime,
});
```

### Log format for containers (JSON)

```json
{
  "timestamp": "2025-01-15T10:30:00.000Z",
  "level": "info",
  "service": "payment-service",
  "message": "Payment processed",
  "orderId": "ord_abc123",
  "amount": 4999,
  "duration_ms": 342,
  "trace_id": "abc123def456"
}
```

## Error Alerting

### Crashlytics alerts

Configure in Firebase Console > Crashlytics > Alerts:

- **New fatal issue**: Alert when a new crash cluster appears
- **Regressed issue**: Alert when a previously closed crash reappears
- **Trending issue**: Alert when crash velocity increases
- **Velocity alert**: Alert when a single issue affects X% of sessions in Y hours

### Custom alerting with Cloud Functions

```typescript
import { onNewFatalIssuePublished } from 'firebase-functions/v2/alerts/crashlytics';

export const notifyCrashlytics = onNewFatalIssuePublished(async (event) => {
  const issue = event.data;
  await sendSlackMessage({
    channel: '#app-crashes',
    text: `New crash: ${issue.title}\nAffected: ${issue.appVersion}\nLink: ${issue.issueLink}`,
  });
});
```

## SLI/SLO Basics

### Service Level Indicators (SLIs)

| SLI | Measurement | Source |
|-----|-------------|--------|
| Crash-free rate | % of sessions without crashes | Crashlytics |
| ANR-free rate | % of sessions without ANRs | Play Console vitals |
| API latency p95 | 95th percentile response time | Performance Monitoring |
| API error rate | % of requests returning 5xx | Server logs |
| App startup time | Cold start p95 | Performance Monitoring |

### Service Level Objectives (SLOs)

| Service | SLI | SLO Target | Window |
|---------|-----|-----------|--------|
| Android app | Crash-free sessions | >= 99.5% | 7-day rolling |
| Android app | ANR-free sessions | >= 99.8% | 7-day rolling |
| Backend API | Availability | >= 99.9% | 30-day rolling |
| Backend API | Latency p95 | < 500ms | 30-day rolling |
| Backend API | Error rate | < 0.1% | 24-hour rolling |

## Incident Response Checklist

When a production incident is detected:

1. **Detect**: Alert fires (Crashlytics velocity, error rate spike, SLO breach)
2. **Triage**: Determine severity (P0: total outage, P1: major feature broken, P2: degraded, P3: minor)
3. **Communicate**: Post in #incidents channel with severity, impact, and investigating owner
4. **Investigate**: Check Crashlytics for new crash clusters, check server logs for errors, check recent deployments
5. **Mitigate**: Apply immediate fix (rollback, feature flag toggle, server restart, hotfix)
6. **Verify**: Confirm crash rate / error rate returns to normal
7. **Resolve**: Close incident, update status page
8. **Follow up**: Schedule post-mortem within 48 hours

## Rollback Decision Tree

```
Is the crash-free rate below 99%?
  YES -> Immediate rollback, no discussion needed
  NO  -> Is it below the 99.5% SLO?
    YES -> Is the issue isolated to one device/OS version?
      YES -> Investigate, prepare hotfix, monitor for 2 hours
      NO  -> Rollback and investigate
    NO  -> Monitor, investigate, fix in next release
```
