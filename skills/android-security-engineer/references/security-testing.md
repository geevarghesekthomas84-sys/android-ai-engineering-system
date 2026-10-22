# Security Testing

## SAST: Static Analysis

### Detekt Security Rules

Detekt is a Kotlin static analysis tool. Add security-focused rules:

```kotlin
// build.gradle.kts
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.7"
}

detekt {
    config.setFrom("$rootDir/config/detekt/detekt.yml")
    buildUponDefaultConfig = true
}
```

Custom security rules in `config/detekt/detekt.yml`:

```yaml
potential-bugs:
  active: true
  # Catches hardcoded credentials
  UnsafeCallOnNullableType:
    active: true

style:
  active: true
  # Catches println and System.out usage
  ForbiddenMethodCall:
    active: true
    methods:
      - reason: "Use Timber instead; Log calls may leak sensitive data"
        value: "android.util.Log.d"
      - reason: "Use Timber instead; Log calls may leak sensitive data"
        value: "android.util.Log.v"
      - reason: "Use Timber instead; Log calls may leak sensitive data"
        value: "android.util.Log.i"
      - reason: "Avoid println in production code"
        value: "kotlin.io.println"
      - reason: "Avoid System.out in production code"
        value: "java.lang.System.out.println"

  ForbiddenComment:
    active: true
    values:
      - reason: "Remove TODO before release"
        value: "TODO"
      - reason: "Remove FIXME before release"
        value: "FIXME"
      - reason: "Hardcoded credentials must be removed"
        value: "password"
      - reason: "Hardcoded secrets must be removed"
        value: "secret"
```

### Android Lint Security Checks

Built-in lint checks that catch security issues:

```kotlin
// build.gradle.kts
android {
    lint {
        enable += listOf(
            "HardcodedDebugMode",
            "AllowBackup",
            "ExportedContentProvider",
            "ExportedService",
            "ExportedReceiver",
            "ExportedActivity",
            "UnprotectedSMSBroadcastReceiver",
            "UnsafeProtectedBroadcastReceiver",
            "GrantAllUris",
            "WorldReadableFiles",
            "WorldWriteableFiles",
            "SetJavaScriptEnabled",
            "HardcodedText",
            "PackageManagerGetSignatures",
            "TrustAllX509TrustManager",
            "InsecureBaseConfiguration",
            "CleartextTrafficPermitted"
        )
        warningsAsErrors = true
        abortOnError = true
    }
}
```

### Dependency Scanning with OWASP Dependency-Check

```kotlin
// build.gradle.kts (root)
plugins {
    id("org.owasp.dependencycheck") version "10.0.4"
}

dependencyCheck {
    analyzers {
        assemblyEnabled = false // not needed for Android
    }
    failBuildOnCVSS = 7.0f // fail on high/critical CVEs
    formats = listOf("HTML", "JSON")
    outputDirectory = "$buildDir/reports/dependency-check"

    // Suppress known false positives
    suppressionFile = "$rootDir/config/dependency-check-suppressions.xml"
}
```

Run with: `./gradlew dependencyCheckAnalyze`

Suppression file for false positives (`config/dependency-check-suppressions.xml`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
    <suppress>
        <notes>False positive: not using the affected module</notes>
        <cve>CVE-YYYY-XXXXX</cve>
    </suppress>
</suppressions>
```

## DAST: Dynamic Analysis

### Frida Basics

Frida is a dynamic instrumentation toolkit for runtime analysis and testing. Use it only in authorized testing environments.

Common security testing tasks with Frida:

```javascript
// Bypass SSL pinning (for testing your own app)
Java.perform(function() {
    var TrustManagerImpl = Java.use("com.android.org.conscrypt.TrustManagerImpl");
    TrustManagerImpl.verifyChain.implementation = function() {
        return arguments[0]; // Return the original chain untouched
    };
});

// Monitor SharedPreferences writes (detect plaintext storage)
Java.perform(function() {
    var SharedPreferencesEditor = Java.use("android.app.SharedPreferencesImpl$EditorImpl");
    SharedPreferencesEditor.putString.implementation = function(key, value) {
        console.log("[SharedPrefs] putString: " + key + " = " + value);
        return this.putString(key, value);
    };
});

// Monitor Keystore operations (verify encryption is used)
Java.perform(function() {
    var KeyStore = Java.use("java.security.KeyStore");
    KeyStore.getInstance.overload("java.lang.String").implementation = function(type) {
        console.log("[KeyStore] getInstance: " + type);
        return this.getInstance(type);
    };
});
```

### Intercepting Traffic with mitmproxy

Setup for testing your own app:

1. Install mitmproxy: `pip install mitmproxy`
2. Start proxy: `mitmproxy --listen-port 8080`
3. Configure Android device/emulator to use proxy (Wi-Fi settings > Manual proxy)
4. Install mitmproxy CA: navigate to `mitm.it` on the device browser
5. For API 24+, your app needs `<debug-overrides>` in network security config to trust user CAs

Useful mitmproxy scripts for security testing:

```python
# save as test_auth.py, run with: mitmproxy -s test_auth.py
from mitmproxy import http

def request(flow: http.HTTPFlow):
    # Log all Authorization headers
    auth = flow.request.headers.get("Authorization", "")
    if auth:
        print(f"[AUTH] {flow.request.method} {flow.request.url}")
        print(f"  Token: {auth[:50]}...")

    # Check for sensitive data in URLs
    sensitive_params = ["token", "password", "secret", "key", "api_key"]
    for param in sensitive_params:
        if param in flow.request.url.lower():
            print(f"[SENSITIVE] Parameter in URL: {flow.request.url}")

    # Check for cleartext HTTP
    if flow.request.scheme == "http":
        print(f"[CLEARTEXT] {flow.request.url}")
```

## Security-Focused Unit Tests

### Testing Encryption

```kotlin
class EncryptionTest {

    @Test
    fun `encrypted data is not plaintext`() {
        val keyAlias = "test_key"
        generateAesKey(keyAlias)

        val plaintext = "sensitive_password_123"
        val (iv, ciphertext) = encrypt(keyAlias, plaintext.toByteArray())

        // Ciphertext should not contain the plaintext
        val ciphertextString = String(ciphertext, Charsets.ISO_8859_1)
        assertFalse(ciphertextString.contains(plaintext))

        // Decryption should recover the original
        val decrypted = decrypt(keyAlias, iv, ciphertext)
        assertEquals(plaintext, String(decrypted))
    }

    @Test
    fun `different encryptions produce different ciphertexts`() {
        val keyAlias = "test_key"
        generateAesKey(keyAlias)

        val plaintext = "same_input".toByteArray()
        val (iv1, ct1) = encrypt(keyAlias, plaintext)
        val (iv2, ct2) = encrypt(keyAlias, plaintext)

        // GCM with random IV should produce different ciphertexts
        assertFalse(iv1.contentEquals(iv2))
        assertFalse(ct1.contentEquals(ct2))
    }
}
```

### Testing Auth Flows

```kotlin
class AuthFlowTest {

    @Test
    fun `expired token triggers refresh`() = runTest {
        val tokenManager = FakeTokenManager(
            accessToken = "expired_token",
            refreshToken = "valid_refresh"
        )
        val authService = FakeAuthService(
            refreshResult = TokenPair("new_access", "new_refresh")
        )
        val interceptor = TokenRefreshInterceptor(tokenManager, authService)

        // Simulate 401 response
        val chain = FakeChain(responseCode = 401)
        interceptor.intercept(chain)

        assertEquals("new_access", tokenManager.getAccessToken())
        assertEquals("new_refresh", tokenManager.getRefreshToken())
    }

    @Test
    fun `invalid refresh token clears session`() = runTest {
        val tokenManager = FakeTokenManager(
            accessToken = "expired",
            refreshToken = "invalid_refresh"
        )
        val authService = FakeAuthService(
            refreshResult = null // refresh fails
        )

        assertThrows<AuthenticationException> {
            val interceptor = TokenRefreshInterceptor(tokenManager, authService)
            interceptor.intercept(FakeChain(responseCode = 401))
        }
    }
}
```

### Testing Input Validation

```kotlin
class InputValidationTest {

    @Test
    fun `deep link rejects invalid schemes`() {
        val result = safeParseDeepLink(
            Intent().apply { data = Uri.parse("http://example.com/product/123") }
        )
        assertEquals(DeepLinkResult.Invalid, result)
    }

    @Test
    fun `deep link rejects path traversal`() {
        val result = safeParseDeepLink(
            Intent().apply { data = Uri.parse("https://example.com/../../../etc/passwd") }
        )
        // Path segments should be sanitized, no dots or slashes remain
        if (result is DeepLinkResult.Valid) {
            result.segments.forEach { segment ->
                assertFalse(segment.contains("."))
                assertFalse(segment.contains("/"))
            }
        }
    }

    @Test
    fun `intent extras reject SQL injection`() {
        val maliciousId = "1; DROP TABLE users;--"
        assertFalse(maliciousId.matches(Regex("^[0-9]{1,10}$")))
    }

    @Test
    fun `content provider uses parameterized queries`() {
        // Verify that the provider's query method uses selection args
        val provider = SecureContentProvider()
        // Pass SQL injection attempt as URI parameter
        val uri = Uri.parse("content://com.example.app.provider/users/1' OR '1'='1")
        val cursor = provider.query(uri, null, null, null, null)
        // Should return 0 or 1 rows, not all rows
        assertNotNull(cursor)
        assertTrue(cursor.count <= 1)
    }
}
```

## Penetration Testing Checklist (OWASP MASTG)

Based on OWASP Mobile Application Security Testing Guide test cases:

### Storage (MASVS-STORAGE)
- [ ] Check SharedPreferences for plaintext sensitive data
- [ ] Check SQLite databases for unencrypted PII/credentials
- [ ] Check log output (logcat) for sensitive data leakage
- [ ] Check clipboard for sensitive data after copy operations
- [ ] Check backup files for sensitive data (adb backup)
- [ ] Check external storage for sensitive data
- [ ] Check keyboard cache and autocomplete for sensitive input fields
- [ ] Verify screenshot protection on sensitive screens (FLAG_SECURE)

### Crypto (MASVS-CRYPTO)
- [ ] Verify no hardcoded cryptographic keys in source/resources
- [ ] Verify strong algorithms (AES-256, RSA-2048+, SHA-256+)
- [ ] Verify random IVs/nonces for each encryption
- [ ] Verify Keystore is used for key storage
- [ ] Check for deprecated algorithms (DES, 3DES, RC4, MD5)

### Auth (MASVS-AUTH)
- [ ] Test login with invalid credentials (error messages, lockout)
- [ ] Test session token expiration and renewal
- [ ] Test logout completeness (token revocation, local cleanup)
- [ ] Test biometric authentication bypass attempts
- [ ] Verify tokens are not in URL parameters

### Network (MASVS-NETWORK)
- [ ] Verify TLS on all endpoints (no cleartext HTTP)
- [ ] Test certificate pinning enforcement
- [ ] Check for sensitive data in URLs/headers visible to proxies
- [ ] Test API responses for excessive data exposure
- [ ] Verify certificate validation (no custom TrustManagers accepting all)

### Platform (MASVS-PLATFORM)
- [ ] Test all exported components with malicious intents
- [ ] Test deep links with unexpected parameters
- [ ] Check WebView JavaScript bridge for sensitive method exposure
- [ ] Test content providers for SQL injection
- [ ] Verify custom permissions are properly enforced

### Resilience (MASVS-RESILIENCE)
- [ ] Attempt to run on rooted device / emulator (if detection claimed)
- [ ] Attempt to attach debugger
- [ ] Attempt to repackage and run the app
- [ ] Test Play Integrity API response handling

## CI/CD Security Gates

```yaml
# .github/workflows/security.yml
name: Security Checks

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Run detekt
        run: ./gradlew detekt

      - name: Run lint security checks
        run: ./gradlew lintRelease

      - name: Dependency vulnerability scan
        run: ./gradlew dependencyCheckAnalyze

      - name: Run security unit tests
        run: ./gradlew testReleaseUnitTest --tests "*Security*" --tests "*Encryption*" --tests "*Auth*"

      - name: Check for secrets in code
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          extra_args: --only-verified

      - name: Upload security reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-reports
          path: |
            build/reports/detekt/
            build/reports/lint-results-release.*
            build/reports/dependency-check/
```

## Vulnerability Disclosure Template

```markdown
## Vulnerability Report

**Title**: [Brief description]
**Severity**: [Critical / High / Medium / Low]
**CVSS Score**: [0.0 - 10.0] (use https://www.first.org/cvss/calculator/3.1)

### Summary
[One paragraph describing the vulnerability and its impact]

### Affected Component
- **App version**: [e.g., 2.3.1]
- **Android version tested**: [e.g., Android 14, API 34]
- **Component**: [e.g., DeepLinkActivity, UserContentProvider]
- **MASVS category**: [e.g., MASVS-PLATFORM]

### Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens -- the vulnerability]

### Impact
[Describe what an attacker could achieve: data theft, account takeover, etc.]

### Proof of Concept
[Code, commands, or screenshots demonstrating the issue]

### Recommended Fix
[Specific technical remediation steps]

### References
- [OWASP MASTG test case ID]
- [CWE ID]
- [Related CVEs if applicable]
```
