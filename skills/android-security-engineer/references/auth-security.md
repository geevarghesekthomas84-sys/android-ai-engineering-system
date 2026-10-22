# Authentication Security

## Secure Token Storage

Auth tokens must be stored in encrypted storage backed by Android Keystore. Never store tokens in plain SharedPreferences, databases, or files.

### Keystore-Backed Token Storage

```kotlin
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class SecureTokenManager(private val context: Context) {

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val securePrefs = EncryptedSharedPreferences.create(
        context,
        "auth_tokens",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun storeTokens(accessToken: String, refreshToken: String) {
        securePrefs.edit()
            .putString("access_token", accessToken)
            .putString("refresh_token", refreshToken)
            .putLong("token_stored_at", System.currentTimeMillis())
            .apply()
    }

    fun getAccessToken(): String? = securePrefs.getString("access_token", null)

    fun getRefreshToken(): String? = securePrefs.getString("refresh_token", null)

    fun clearTokens() {
        securePrefs.edit().clear().apply()
    }

    fun isTokenExpired(maxAgeMs: Long): Boolean {
        val storedAt = securePrefs.getLong("token_stored_at", 0)
        return System.currentTimeMillis() - storedAt > maxAgeMs
    }
}
```

## Biometric Authentication

### BiometricPrompt with CryptoObject

For high-security operations, combine biometric authentication with a Keystore cryptographic operation. The CryptoObject ensures the biometric result is tied to a real key operation, not just a UI confirmation.

```kotlin
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties

class BiometricAuthManager(private val activity: FragmentActivity) {

    private val keyAlias = "biometric_auth_key"

    fun generateBiometricKey() {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        keyGenerator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                .setInvalidatedByBiometricEnrollment(true)
                .build()
        )
        keyGenerator.generateKey()
    }

    fun authenticate(
        onSuccess: (BiometricPrompt.AuthenticationResult) -> Unit,
        onError: (Int, CharSequence) -> Unit
    ) {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val key = keyStore.getKey(keyAlias, null)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val cryptoObject = BiometricPrompt.CryptoObject(cipher)

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Authenticate")
            .setSubtitle("Verify your identity to continue")
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        val biometricPrompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    onSuccess(result)
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onError(errorCode, errString)
                }
            }
        )

        biometricPrompt.authenticate(promptInfo, cryptoObject)
    }

    fun canAuthenticate(): Boolean {
        val biometricManager = BiometricManager.from(activity)
        return biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        ) == BiometricManager.BIOMETRIC_SUCCESS
    }
}
```

### Checking Biometric Availability

Always check biometric capability before offering it:

```kotlin
when (BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG)) {
    BIOMETRIC_SUCCESS -> // Biometric available and enrolled
    BIOMETRIC_ERROR_NO_HARDWARE -> // No biometric hardware
    BIOMETRIC_ERROR_HW_UNAVAILABLE -> // Hardware unavailable
    BIOMETRIC_ERROR_NONE_ENROLLED -> // No biometrics enrolled, prompt user
    BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> // Security patch needed
}
```

## Secure Session Management

### Token Refresh Flow

```kotlin
class TokenRefreshInterceptor(
    private val tokenManager: SecureTokenManager,
    private val authService: AuthService
) : Interceptor {

    private val lock = Mutex()

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val accessToken = tokenManager.getAccessToken()

        val response = chain.proceed(
            request.newBuilder()
                .header("Authorization", "Bearer $accessToken")
                .build()
        )

        if (response.code == 401) {
            response.close()
            return runBlocking {
                lock.withLock {
                    // Check if another thread already refreshed
                    val currentToken = tokenManager.getAccessToken()
                    if (currentToken != accessToken) {
                        // Already refreshed, retry with new token
                        chain.proceed(
                            request.newBuilder()
                                .header("Authorization", "Bearer $currentToken")
                                .build()
                        )
                    } else {
                        // Perform refresh
                        val refreshToken = tokenManager.getRefreshToken()
                            ?: throw AuthenticationException("No refresh token")
                        val newTokens = authService.refreshToken(refreshToken)
                        tokenManager.storeTokens(newTokens.accessToken, newTokens.refreshToken)
                        chain.proceed(
                            request.newBuilder()
                                .header("Authorization", "Bearer ${newTokens.accessToken}")
                                .build()
                        )
                    }
                }
            }
        }

        return response
    }
}
```

### Preventing Token Leakage

- Never log tokens: `Log.d("Auth", "Token: $token")` is a critical vulnerability.
- Never include tokens in URL query parameters. Proxies, server logs, and browser history record URLs.
- Strip tokens from crash reports and analytics.
- Clear tokens from memory when no longer needed (set references to null).
- Use `FLAG_SECURE` on screens displaying tokens or sensitive auth data.
- Set `android:excludeFromRecents="true"` on sensitive activities.

## Multi-Factor Authentication

```kotlin
sealed class MfaChallenge {
    data class Totp(val secret: String) : MfaChallenge()
    data class SmsFallback(val phoneHint: String) : MfaChallenge()
    data class PushNotification(val deviceId: String) : MfaChallenge()
}

class MfaManager(
    private val authService: AuthService,
    private val biometricAuth: BiometricAuthManager
) {

    suspend fun completeMfa(
        sessionToken: String,
        challenge: MfaChallenge,
        userInput: String
    ): AuthResult {
        // Step 1: Verify the MFA code server-side
        val mfaResult = authService.verifyMfa(sessionToken, userInput)

        if (!mfaResult.success) {
            if (mfaResult.remainingAttempts <= 0) {
                throw AccountLockedException(mfaResult.lockoutDuration)
            }
            throw InvalidMfaCodeException(mfaResult.remainingAttempts)
        }

        // Step 2: Optionally require local biometric before storing tokens
        // This adds device-local assurance on top of server-verified MFA
        return mfaResult
    }
}
```

## Brute-Force Protection

Implement client-side rate limiting as defense-in-depth (server-side is authoritative):

```kotlin
class LoginRateLimiter {
    private var failedAttempts = 0
    private var lockoutUntil: Long = 0

    fun recordFailedAttempt() {
        failedAttempts++
        if (failedAttempts >= MAX_ATTEMPTS) {
            val backoffMs = INITIAL_LOCKOUT_MS * (1 shl (failedAttempts - MAX_ATTEMPTS)
                .coerceAtMost(MAX_BACKOFF_EXPONENT))
            lockoutUntil = System.currentTimeMillis() + backoffMs
        }
    }

    fun canAttemptLogin(): LoginStatus {
        val now = System.currentTimeMillis()
        if (lockoutUntil > now) {
            return LoginStatus.LockedOut((lockoutUntil - now) / 1000)
        }
        return LoginStatus.Allowed
    }

    fun recordSuccess() {
        failedAttempts = 0
        lockoutUntil = 0
    }

    companion object {
        const val MAX_ATTEMPTS = 5
        const val INITIAL_LOCKOUT_MS = 30_000L // 30 seconds
        const val MAX_BACKOFF_EXPONENT = 5 // max ~16 minutes
    }

    sealed class LoginStatus {
        data object Allowed : LoginStatus()
        data class LockedOut(val remainingSeconds: Long) : LoginStatus()
    }
}
```

## OAuth 2.0 PKCE for Mobile

Use Authorization Code flow with PKCE (Proof Key for Code Exchange) for mobile OAuth. Never use the Implicit flow.

```kotlin
import android.net.Uri
import java.security.MessageDigest
import java.security.SecureRandom
import android.util.Base64

class OAuthPkceManager {

    fun generateCodeVerifier(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    fun generateCodeChallenge(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(verifier.toByteArray(Charsets.US_ASCII))
        return Base64.encodeToString(hash, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    fun buildAuthorizationUrl(
        authEndpoint: String,
        clientId: String,
        redirectUri: String,
        codeChallenge: String,
        scopes: List<String>,
        state: String
    ): Uri {
        return Uri.parse(authEndpoint).buildUpon()
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("client_id", clientId)
            .appendQueryParameter("redirect_uri", redirectUri)
            .appendQueryParameter("code_challenge", codeChallenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .appendQueryParameter("scope", scopes.joinToString(" "))
            .appendQueryParameter("state", state) // CSRF protection
            .build()
    }

    suspend fun exchangeCodeForTokens(
        tokenEndpoint: String,
        code: String,
        codeVerifier: String,
        clientId: String,
        redirectUri: String
    ): TokenResponse {
        // POST to token endpoint with:
        // grant_type=authorization_code
        // code=<authorization_code>
        // redirect_uri=<redirect_uri>
        // client_id=<client_id>
        // code_verifier=<code_verifier>
        // The code_verifier proves possession of the original challenge
        TODO("Implement with your HTTP client")
    }
}
```

Use `net.openid:appauth` library for a production-ready implementation that handles browser custom tabs, token storage, and refresh automatically.

## Logout: Token Revocation and Local Cleanup

A secure logout must revoke server-side tokens and clear all local state:

```kotlin
class LogoutManager(
    private val authService: AuthService,
    private val tokenManager: SecureTokenManager,
    private val database: AppDatabase,
    private val context: Context
) {

    suspend fun logout() {
        // 1. Revoke tokens server-side (best effort)
        try {
            val refreshToken = tokenManager.getRefreshToken()
            if (refreshToken != null) {
                authService.revokeToken(refreshToken)
            }
        } catch (e: Exception) {
            // Log but don't block logout on revocation failure
            // Server should expire token eventually
        }

        // 2. Clear all local tokens
        tokenManager.clearTokens()

        // 3. Clear sensitive cached data
        database.clearAllTables()

        // 4. Clear WebView data (cookies, cache, storage)
        CookieManager.getInstance().removeAllCookies(null)
        WebStorage.getInstance().deleteAllData()

        // 5. Clear app cache
        context.cacheDir.deleteRecursively()

        // 6. Navigate to login screen and clear back stack
    }
}
```

Key logout considerations:
- Always attempt server-side token revocation before clearing local state.
- Clear all encrypted storage, databases, and caches containing user data.
- Remove WebView cookies and local storage (especially for OAuth sessions).
- Clear the activity back stack so pressing Back does not return to authenticated screens.
- If using push notifications, unregister the device token from the server.
- Invalidate any biometric-bound Keystore keys associated with the session.
