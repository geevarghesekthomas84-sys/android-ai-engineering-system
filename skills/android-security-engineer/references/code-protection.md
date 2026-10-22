# Code and App Protection

## R8 Obfuscation Configuration

R8 (the default code shrinker/optimizer since AGP 3.4) provides obfuscation that renames classes, methods, and fields to make reverse engineering harder.

### Enabling in build.gradle.kts

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### Security-Focused ProGuard/R8 Rules

```proguard
# Remove all logging in release
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

# Remove Timber logging
-assumenosideeffects class timber.log.Timber {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Obfuscate all classes except those needed for reflection/serialization
-repackageclasses ''
-allowaccessmodification

# Remove debug attributes
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable  # keep for crash reports

# Remove other debug info
-keepattributes !LocalVariableTable,!LocalVariableTypeTable
```

### Removing Debug Information

For maximum protection (at the cost of less readable crash reports):

```proguard
# Strip source file names entirely
-dontnote
-dontwarn

# Flatten package hierarchy
-flattenpackagehierarchy

# Use aggressive optimizations
-optimizationpasses 5
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
```

Upload the R8 mapping file to your crash reporting service (Firebase Crashlytics, Sentry) so stack traces remain readable in your dashboard while being obfuscated on-device.

## Tamper Detection

Verify that the APK has not been modified and repackaged:

```kotlin
object TamperDetector {

    fun isApkTampered(context: Context): Boolean {
        return !verifySignature(context) || !verifyInstaller(context)
    }

    private fun verifySignature(context: Context): Boolean {
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES
                )
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            val currentHash = signatures?.firstOrNull()?.let {
                val digest = MessageDigest.getInstance("SHA-256")
                Base64.encodeToString(digest.digest(it.toByteArray()), Base64.NO_WRAP)
            }

            // Compare against your known signing certificate hash
            return currentHash == EXPECTED_SIGNATURE_HASH
        } catch (e: Exception) {
            return false
        }
    }

    private fun verifyInstaller(context: Context): Boolean {
        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getInstallerPackageName(context.packageName)
        }
        return installer in TRUSTED_INSTALLERS
    }

    private const val EXPECTED_SIGNATURE_HASH = "your_base64_sha256_hash_here"
    private val TRUSTED_INSTALLERS = setOf(
        "com.android.vending",       // Google Play Store
        "com.google.android.feedback" // Google Play alternative
    )
}
```

## Debugger Detection

Detect when a debugger is attached (indicating dynamic analysis):

```kotlin
object DebugDetector {

    fun isBeingDebugged(): Boolean {
        return Debug.isDebuggerConnected() ||
               Debug.waitingForDebugger() ||
               isTracerAttached()
    }

    private fun isTracerAttached(): Boolean {
        return try {
            val tracerPid = File("/proc/self/status").readLines()
                .firstOrNull { it.startsWith("TracerPid:") }
                ?.substringAfter(":")
                ?.trim()
                ?.toIntOrNull()
            tracerPid != null && tracerPid > 0
        } catch (e: Exception) {
            false
        }
    }

    fun isDebuggable(context: Context): Boolean {
        return (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }
}
```

## Emulator Detection

Detect execution in an emulator environment:

```kotlin
object EmulatorDetector {

    fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.BOARD == "QC_Reference_Phone"
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.HOST.startsWith("Build")
                || Build.BRAND.startsWith("generic")
                || Build.DEVICE.startsWith("generic")
                || Build.PRODUCT == "sdk_google"
                || Build.PRODUCT.startsWith("sdk")
                || Build.PRODUCT.contains("_sdk")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu"))
    }
}
```

## Root Detection

See `references/secure-storage.md` for basic root detection. For stronger detection, use Play Integrity API.

## Play Integrity API (Successor to SafetyNet)

```kotlin
// build.gradle.kts
implementation("com.google.android.play:integrity:1.4.0")

// Request integrity verdict
import com.google.android.play.core.integrity.IntegrityManagerFactory

class PlayIntegrityChecker(private val context: Context) {

    suspend fun checkIntegrity(): IntegrityResult {
        val integrityManager = IntegrityManagerFactory.create(context)

        // Generate a nonce: combine a server-generated random value with a request hash
        val nonce = generateNonce()

        val integrityTokenRequest = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .build()

        return try {
            val response = integrityManager
                .requestIntegrityToken(integrityTokenRequest)
                .await()

            // IMPORTANT: Send the token to YOUR server for verification
            // Never verify the token on-device -- the device is untrusted
            val verdict = yourServer.verifyIntegrityToken(response.token())
            IntegrityResult.Success(verdict)
        } catch (e: Exception) {
            IntegrityResult.Error(e)
        }
    }
}
```

Server-side verification returns a verdict containing:
- **Device integrity**: `MEETS_DEVICE_INTEGRITY` (genuine device), `MEETS_BASIC_INTEGRITY`, or empty (failing).
- **App integrity**: `PLAY_RECOGNIZED` (installed from Play Store and unmodified).
- **Account details**: Licensed or unlicensed.

## Preventing Screenshots and Screen Recording

```kotlin
// In Activity.onCreate() or a base activity
window.setFlags(
    WindowManager.LayoutParams.FLAG_SECURE,
    WindowManager.LayoutParams.FLAG_SECURE
)
```

This prevents:
- Screenshots (screen capture returns a black image)
- Screen recording
- Display on non-secure displays (e.g., casting)
- Visibility in the Recent Apps / task switcher

Apply `FLAG_SECURE` to activities showing sensitive data: banking transactions, passwords, auth tokens, personal documents.

For Compose:

```kotlin
@Composable
fun SecureScreen(content: @Composable () -> Unit) {
    val activity = LocalContext.current as? Activity
    DisposableEffect(Unit) {
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        onDispose {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
    content()
}
```

## Clipboard Security

Prevent sensitive data from lingering in the clipboard:

```kotlin
// Clear clipboard after a timeout when copying sensitive data
fun copyWithAutoExpiry(context: Context, label: String, text: String, expiryMs: Long = 60_000) {
    val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        // API 33+: PersistableBundle with sensitivity flag
        val clipData = ClipData.newPlainText(label, text).apply {
            description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        }
        clipboardManager.setPrimaryClip(clipData)
    } else {
        clipboardManager.setPrimaryClip(ClipData.newPlainText(label, text))
    }

    // Auto-clear after timeout
    Handler(Looper.getMainLooper()).postDelayed({
        clipboardManager.setPrimaryClip(ClipData.newPlainText("", ""))
    }, expiryMs)
}
```

On API 33+, `EXTRA_IS_SENSITIVE` tells the system to hide the clipboard content in visual previews.

## Security Checks Decision Matrix

| Check | Purpose | Bypass Difficulty | Recommendation |
|-------|---------|-------------------|----------------|
| Signature verification | Detect repackaging | Medium | Always include |
| Installer verification | Detect sideloading | Low | Include for compliance |
| Debugger detection | Detect dynamic analysis | Medium | Include for sensitive apps |
| Emulator detection | Detect automated attacks | Medium | Include for anti-fraud |
| Root detection | Detect compromised devices | High (can be hidden) | Defense-in-depth only |
| Play Integrity API | Device and app attestation | High (server-verified) | Strongest client check |
| FLAG_SECURE | Prevent screen capture | Low (root bypass) | Always for sensitive screens |

All client-side checks can be bypassed by a sufficiently motivated attacker. Layer them and always validate critical security decisions server-side.
