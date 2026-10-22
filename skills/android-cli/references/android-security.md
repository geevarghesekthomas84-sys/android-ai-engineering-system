# Android Security Engineering

Based on OWASP Mobile Application Security Verification Standard (MASVS) and
Mobile Application Security Testing Guide (MASTG).

## Secure Development Practices

### AndroidManifest.xml Security

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Request only necessary permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- Avoid: WRITE_EXTERNAL_STORAGE, READ_PHONE_STATE unless truly needed -->

    <application
        android:allowBackup="false"
        android:fullBackupContent="false"
        android:dataExtractionRules="@xml/data_extraction_rules"
        android:networkSecurityConfig="@xml/network_security_config"
        android:usesCleartextTraffic="false">

        <!-- Do NOT export activities/services/receivers unless necessary -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <!-- exported=true ONLY for launcher activities or intent-filter receivers -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Internal components must be exported=false -->
        <service
            android:name=".service.SyncService"
            android:exported="false" />

        <receiver
            android:name=".receiver.NotificationReceiver"
            android:exported="false" />

        <!-- Content providers with proper permissions -->
        <provider
            android:name=".data.AppContentProvider"
            android:authorities="${applicationId}.provider"
            android:exported="false"
            android:grantUriPermissions="true" />
    </application>
</manifest>
```

### Permission Analysis Checklist
- List all `<uses-permission>` declarations.
- Justify each permission — remove any not strictly needed.
- Use runtime permission requests for dangerous permissions.
- Check for implicit permission grants via exported components.
- Verify `android:exported` is explicitly set for all components (required API 31+).

### Network Security Configuration

`res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Production: HTTPS only, system trust store -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- Debug only: allow user-installed CAs for proxy debugging -->
    <debug-overrides>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>

    <!-- Certificate pinning for critical domains -->
    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2027-01-01">
            <pin digest="SHA-256">base64EncodedSHA256PinHere=</pin>
            <!-- Always include a backup pin -->
            <pin digest="SHA-256">backupBase64EncodedSHA256PinHere=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

### Data Extraction Rules (Android 12+)

`res/xml/data_extraction_rules.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root" />
        <exclude domain="database" />
        <exclude domain="sharedpref" path="secret_prefs.xml" />
    </cloud-backup>
    <device-transfer>
        <exclude domain="database" />
    </device-transfer>
</data-extraction-rules>
```

## Secure Storage

### Android Keystore
```kotlin
object KeystoreHelper {
    private const val KEY_ALIAS = "app_encryption_key"

    fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        keyStore.getEntry(KEY_ALIAS, null)?.let {
            return (it as KeyStore.SecretKeyEntry).secretKey
        }
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
        )
        keyGenerator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(false)
                .build()
        )
        return keyGenerator.generateKey()
    }
}
```

### EncryptedSharedPreferences
```kotlin
val encryptedPrefs = EncryptedSharedPreferences.create(
    context,
    "secret_prefs",
    MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build(),
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)
```

Dependency: `implementation("androidx.security:security-crypto:1.1.0-alpha06")`

### Secure Token Storage
```kotlin
class TokenManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context, "auth_tokens", masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveToken(token: String) { prefs.edit().putString("access_token", token).apply() }
    fun getToken(): String? = prefs.getString("access_token", null)
    fun clearTokens() { prefs.edit().clear().apply() }
}
```

Never store tokens in:
- Plain SharedPreferences
- SQLite without encryption
- External storage
- BuildConfig fields
- Hardcoded strings

## Authentication and Session Security

- Use OAuth 2.0 / OIDC with PKCE for mobile auth flows.
- Store tokens in EncryptedSharedPreferences or Keystore-backed storage.
- Implement token refresh logic — don't store long-lived access tokens.
- Clear tokens on logout.
- Use biometric authentication for sensitive operations:
  ```kotlin
  val biometricPrompt = BiometricPrompt(activity, executor, callback)
  biometricPrompt.authenticate(promptInfo)
  ```

## WebView Security

```kotlin
webView.settings.apply {
    javaScriptEnabled = true // Only if needed
    allowFileAccess = false
    allowContentAccess = false
    domStorageEnabled = true
    mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
}

// Validate URLs loaded in WebView
webView.webViewClient = object : WebViewClient() {
    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
        val url = request?.url?.toString() ?: return false
        return !url.startsWith("https://trusted-domain.com")
    }
}

// Never add JavaScript interfaces with @JavascriptInterface in release builds
// unless absolutely necessary and thoroughly validated
```

## Deep Link and Intent Validation

```kotlin
// Validate incoming deep links
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    intent?.data?.let { uri ->
        if (uri.scheme == "https" && uri.host == "example.com") {
            handleDeepLink(uri)
        } else {
            Log.w("Security", "Rejected deep link: $uri")
        }
    }
}

// Validate intent extras before use
fun handleIntent(intent: Intent) {
    val userId = intent.getStringExtra("user_id")
    if (userId != null && userId.matches(Regex("^[a-zA-Z0-9-]+$"))) {
        loadUser(userId)
    }
}
```

## Security Review Checklist

### Static Analysis
```powershell
# Android Lint security checks
.\gradlew lint

# Review specific security rules
.\gradlew lint --check "SecurityDetector,HardcodedDebugMode,HardcodedText"
```

### Manual Review Points
1. **Exported components**: Every `android:exported="true"` has proper intent validation.
2. **Permissions**: No unnecessary permissions; dangerous permissions use runtime requests.
3. **Data storage**: No plaintext secrets, tokens, or PII in SharedPreferences or files.
4. **Network**: All connections use HTTPS; network security config exists.
5. **Logging**: No sensitive data in logcat (especially in release builds).
6. **WebViews**: JavaScript disabled unless needed; file access disabled.
7. **Backup**: `allowBackup="false"` or restricted backup rules.
8. **Debug**: `android:debuggable` is false in release builds (Gradle handles this).
9. **Dependencies**: No known vulnerabilities (check with `.\gradlew dependencyCheckAnalyze`).
10. **ProGuard/R8**: Code obfuscation enabled for release builds.

### Dependency Vulnerability Scanning
Add the OWASP dependency-check plugin:
```kotlin
// build.gradle.kts (project)
plugins {
    id("org.owasp.dependencycheck") version "11.1.1" apply false
}

// build.gradle.kts (app)
plugins {
    id("org.owasp.dependencycheck")
}
```

Run: `.\gradlew dependencyCheckAnalyze`

## Authorized Security Testing

For security testing on your own applications with proper authorization:

### Static Analysis
- Review decompiled APK with `apktool` and `jadx` (authorized apps only).
- Check for hardcoded secrets, API keys, debug certificates.
- Analyze intent filters for exposed attack surface.

### Dynamic Testing (Authorized Devices Only)
```powershell
# Check for debuggable flag
adb shell run-as com.example.app ls  # Succeeds only if debuggable

# Check exported components
adb shell dumpsys package com.example.app | findstr "exported=true"

# Test deep links
adb shell am start -a android.intent.action.VIEW -d "https://example.com/test"
```

### Reporting
Document findings with:
- Vulnerability description and OWASP MASVS reference.
- Steps to reproduce.
- Impact assessment.
- Remediation recommendation.
- Evidence (screenshots, logs).

## Rules
- Never weaken security configuration to resolve development issues.
- Never disable TLS validation, even in debug builds (use debug-overrides instead).
- Never store secrets in source code, BuildConfig, or string resources.
- Never export components without proper input validation.
- Never use `MODE_WORLD_READABLE` or `MODE_WORLD_WRITABLE`.
- Always use parameterized queries (Room handles this for SQL).
- Always validate and sanitize all external input.
