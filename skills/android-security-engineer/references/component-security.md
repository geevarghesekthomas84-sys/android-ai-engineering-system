# Android Component Security

## Exported Components

Since Android 12 (API 31), every component with an intent filter must explicitly declare `android:exported`. Components without intent filters default to `exported="false"`.

### Principle of Least Exposure

```xml
<!-- WRONG: Activity with intent filter implicitly exported -->
<activity android:name=".DeepLinkActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="myapp" android:host="open" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
    </intent-filter>
</activity>

<!-- CORRECT: Explicitly exported with validation logic in the activity -->
<activity
    android:name=".DeepLinkActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" android:host="example.com" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
    </intent-filter>
</activity>

<!-- Internal-only activity: never exported -->
<activity
    android:name=".AdminDashboardActivity"
    android:exported="false" />
```

## Intent Validation

Always validate incoming intents in exported components:

```kotlin
class DeepLinkActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val intent = intent ?: run { finish(); return }
        val data = intent.data ?: run { finish(); return }

        // Validate scheme and host
        if (data.scheme != "https" || data.host != "example.com") {
            finish()
            return
        }

        // Validate path and parameters
        val path = data.path ?: run { finish(); return }
        when {
            path.startsWith("/product/") -> {
                val productId = data.lastPathSegment
                    ?.takeIf { it.matches(Regex("^[a-zA-Z0-9]{1,32}$")) }
                    ?: run { finish(); return }
                navigateToProduct(productId)
            }
            path == "/settings" -> navigateToSettings()
            else -> { finish(); return }
        }
    }
}
```

### Validating Intent Extras

```kotlin
fun processIntent(intent: Intent) {
    // Type-safe extra retrieval with defaults
    val userId = intent.getStringExtra("user_id")
        ?.takeIf { it.matches(Regex("^[0-9]{1,10}$")) }
        ?: return

    val amount = intent.getDoubleExtra("amount", -1.0)
        .takeIf { it in 0.01..10_000.00 }
        ?: return

    // Never use extras directly in SQL, file paths, or commands
    // Always parameterize queries and validate paths
}
```

## Custom Permissions

Protect sensitive components with signature-level permissions:

```xml
<!-- Define in your manifest -->
<permission
    android:name="com.example.app.ADMIN_ACCESS"
    android:protectionLevel="signature" />

<!-- Require it on the component -->
<service
    android:name=".AdminService"
    android:exported="true"
    android:permission="com.example.app.ADMIN_ACCESS" />

<receiver
    android:name=".InternalBroadcastReceiver"
    android:exported="true"
    android:permission="com.example.app.ADMIN_ACCESS" />
```

`signature` protection level means only apps signed with the same certificate can access the component. This is the strongest permission for inter-app communication within your own app family.

### Checking Caller Identity at Runtime

```kotlin
fun verifyCallerPermission(context: Context): Boolean {
    val callingUid = Binder.getCallingUid()
    val callingPackages = context.packageManager.getPackagesForUid(callingUid)

    return callingPackages?.any { packageName ->
        // Verify the caller's signing certificate
        val callerInfo = context.packageManager.getPackageInfo(
            packageName,
            PackageManager.GET_SIGNING_CERTIFICATES
        )
        val callerSignatures = callerInfo.signingInfo?.apkContentsSigners
        val mySignatures = context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_SIGNING_CERTIFICATES
        ).signingInfo?.apkContentsSigners

        callerSignatures?.any { callerSig ->
            mySignatures?.any { mySig -> callerSig == mySig } == true
        } == true
    } == true
}
```

## Content Provider Security

### Restricting Access

```xml
<provider
    android:name=".data.UserContentProvider"
    android:authorities="com.example.app.provider"
    android:exported="false"
    android:grantUriPermissions="false" />

<!-- If the provider MUST be exported (rare): -->
<provider
    android:name=".data.SharedContentProvider"
    android:authorities="com.example.app.shared"
    android:exported="true"
    android:permission="com.example.app.READ_DATA"
    android:readPermission="com.example.app.READ_DATA"
    android:writePermission="com.example.app.WRITE_DATA"
    android:grantUriPermissions="true">
    <grant-uri-permission android:pathPrefix="/public/" />
    <path-permission
        android:pathPrefix="/admin/"
        android:permission="com.example.app.ADMIN_ACCESS" />
</provider>
```

### Preventing SQL Injection in Content Providers

```kotlin
class SecureContentProvider : ContentProvider() {

    override fun query(
        uri: Uri,
        projection: Array<String>?,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?
    ): Cursor? {
        // NEVER concatenate user input into SQL
        // WRONG: db.rawQuery("SELECT * FROM users WHERE id = $userId", null)

        // Validate projection columns against allowlist
        val validColumns = setOf("id", "name", "email")
        val safeProjection = projection?.filter { it in validColumns }?.toTypedArray()
            ?: arrayOf("id", "name")

        // Validate sort order
        val safeSortOrder = sortOrder?.takeIf { it.matches(Regex("^[a-zA-Z_]+ (ASC|DESC)$")) }

        // Use parameterized queries
        return db.query(
            "users",
            safeProjection,
            "id = ?",
            arrayOf(uri.lastPathSegment),
            null, null,
            safeSortOrder
        )
    }
}
```

## Deep Link Validation

### Android App Links (Verified HTTPS Deep Links)

App Links use HTTPS and digital asset links for verification, preventing other apps from claiming your URLs:

```xml
<activity android:name=".DeepLinkActivity" android:exported="true">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="example.com" />
    </intent-filter>
</activity>
```

Host the Digital Asset Links file at `https://example.com/.well-known/assetlinks.json`:

```json
[{
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
        "namespace": "android_app",
        "package_name": "com.example.app",
        "sha256_cert_fingerprints": [
            "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
        ]
    }
}]
```

### Handling Malformed URIs

```kotlin
fun safeParseDeepLink(intent: Intent): DeepLinkResult {
    val uri = intent.data ?: return DeepLinkResult.Invalid

    return try {
        // Validate scheme
        if (uri.scheme !in listOf("https")) return DeepLinkResult.Invalid

        // Validate host
        if (uri.host != "example.com") return DeepLinkResult.Invalid

        // Sanitize path segments (prevent path traversal)
        val segments = uri.pathSegments.map { segment ->
            segment.replace(Regex("[^a-zA-Z0-9_-]"), "")
        }

        // Validate and extract parameters
        DeepLinkResult.Valid(segments, uri.queryParameterNames.associateWith {
            uri.getQueryParameter(it)?.take(256) ?: "" // limit length
        })
    } catch (e: Exception) {
        DeepLinkResult.Invalid
    }
}
```

## WebView Security

### Safe WebView Configuration

```kotlin
fun configureSecureWebView(webView: WebView) {
    webView.settings.apply {
        // Only enable JavaScript if absolutely required
        javaScriptEnabled = false // default; set true only if needed

        // Disable file access
        allowFileAccess = false
        allowFileAccessFromFileURLs = false
        allowUniversalAccessFromFileURLs = false
        allowContentAccess = false

        // Disable other risky features
        setSupportZoom(true)
        builtInZoomControls = true
        displayZoomControls = false

        // Enable safe browsing
        safeBrowsingEnabled = true

        // Disable caching for sensitive content
        cacheMode = WebSettings.LOAD_NO_CACHE
    }

    // Restrict navigation to trusted domains
    webView.webViewClient = object : WebViewClient() {
        private val trustedDomains = setOf("example.com", "cdn.example.com")

        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            val host = request.url.host ?: return true // block null hosts
            return host !in trustedDomains // return true to block, false to allow
        }

        override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
            handler.cancel() // NEVER call handler.proceed() in production
        }
    }
}
```

### JavaScript Interface Risks

```kotlin
// DANGEROUS: Exposes a method to all JavaScript on the page
// On API < 17, ALL public methods are accessible
@JavascriptInterface
fun sensitiveMethod(data: String) { /* ... */ }

// SAFER: Validate origin and sanitize input
class SafeJsInterface(private val context: Context) {
    @JavascriptInterface
    fun processData(jsonData: String) {
        // Validate and parse JSON safely
        val data = try {
            JSONObject(jsonData)
        } catch (e: JSONException) {
            return
        }

        // Validate each field before use
        val action = data.optString("action")
            .takeIf { it in listOf("share", "copy") }
            ?: return
    }
}
```

Only add `@JavascriptInterface` methods when JavaScript interaction is unavoidable. Validate all data received from JavaScript as untrusted input.

## FileProvider for Secure File Sharing

Instead of exposing file:// URIs (blocked since API 24), use FileProvider:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

`res/xml/file_paths.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <!-- Only expose specific subdirectories, not the entire files dir -->
    <files-path name="shared_images" path="shared/images/" />
    <cache-path name="shared_cache" path="shared/" />
</paths>
```

```kotlin
fun shareFile(context: Context, file: File) {
    val uri = FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file
    )

    val shareIntent = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(shareIntent, "Share"))
}
```

Grant only `FLAG_GRANT_READ_URI_PERMISSION` (not write) unless writing is required. The permission is automatically revoked when the receiving activity's task ends.
