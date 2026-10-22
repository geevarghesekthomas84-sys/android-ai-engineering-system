# Secure Data Storage

## Android Keystore

The Android Keystore system provides hardware-backed (on supported devices) cryptographic key storage. Keys stored in Keystore are not extractable -- cryptographic operations happen inside the secure hardware.

### Generating a Symmetric Key (AES-GCM)

```kotlin
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.KeyGenerator

fun generateAesKey(alias: String) {
    val keyGenerator = KeyGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_AES,
        "AndroidKeyStore"
    )
    val spec = KeyGenParameterSpec.Builder(
        alias,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
    )
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setKeySize(256)
        .setUserAuthenticationRequired(false) // set true for biometric-bound
        .build()

    keyGenerator.init(spec)
    keyGenerator.generateKey()
}
```

### Encrypting and Decrypting with Keystore Key

```kotlin
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec

fun encrypt(alias: String, plaintext: ByteArray): Pair<ByteArray, ByteArray> {
    val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    val key = keyStore.getKey(alias, null)

    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    cipher.init(Cipher.ENCRYPT_MODE, key)

    val iv = cipher.iv // store this alongside ciphertext
    val ciphertext = cipher.doFinal(plaintext)
    return Pair(iv, ciphertext)
}

fun decrypt(alias: String, iv: ByteArray, ciphertext: ByteArray): ByteArray {
    val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    val key = keyStore.getKey(alias, null)

    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    val spec = GCMParameterSpec(128, iv)
    cipher.init(Cipher.DECRYPT_MODE, key, spec)

    return cipher.doFinal(ciphertext)
}
```

### Biometric-Bound Keys

Keys that require biometric authentication before each use:

```kotlin
val spec = KeyGenParameterSpec.Builder(alias, purposes)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setKeySize(256)
    .setUserAuthenticationRequired(true)
    .setUserAuthenticationParameters(
        0, // timeout: 0 means every use requires auth
        KeyProperties.AUTH_BIOMETRIC_STRONG
    )
    .setInvalidatedByBiometricEnrollment(true) // invalidate if new biometric enrolled
    .build()
```

Use with `BiometricPrompt.CryptoObject` to unlock the key:

```kotlin
val cipher = Cipher.getInstance("AES/GCM/NoPadding")
cipher.init(Cipher.ENCRYPT_MODE, key)
val cryptoObject = BiometricPrompt.CryptoObject(cipher)

biometricPrompt.authenticate(promptInfo, cryptoObject)
// In callback: result.cryptoObject?.cipher?.doFinal(data)
```

## EncryptedSharedPreferences

Jetpack Security library provides transparent encryption for SharedPreferences:

```kotlin
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val encryptedPrefs = EncryptedSharedPreferences.create(
    context,
    "secure_prefs",
    masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)

// Use like normal SharedPreferences
encryptedPrefs.edit()
    .putString("auth_token", token)
    .apply()

val token = encryptedPrefs.getString("auth_token", null)
```

**Key points**: Keys are AES256-SIV for preference names (deterministic encryption so lookups work) and AES256-GCM for values. The master key is stored in Android Keystore. On API 23+ devices with hardware-backed Keystore, the master key never leaves secure hardware.

## EncryptedFile

For encrypting entire files:

```kotlin
import androidx.security.crypto.EncryptedFile
import java.io.File

val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val file = File(context.filesDir, "sensitive_data.enc")

val encryptedFile = EncryptedFile.Builder(
    context,
    file,
    masterKey,
    EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
).build()

// Write encrypted
encryptedFile.openFileOutput().use { output ->
    output.write(sensitiveData)
}

// Read decrypted
encryptedFile.openFileInput().use { input ->
    val data = input.readBytes()
}
```

## Encrypted DataStore

Wrap DataStore with encryption for type-safe encrypted key-value storage:

```kotlin
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey

// Create an encrypted DataStore by encrypting values before storing
// and decrypting after reading:
suspend fun storeEncrypted(dataStore: DataStore<Preferences>, key: String, value: String) {
    val (iv, ciphertext) = encrypt("datastore_key", value.toByteArray())
    val encoded = Base64.encodeToString(iv + ciphertext, Base64.NO_WRAP)
    val prefKey = stringPreferencesKey(key)
    dataStore.edit { prefs -> prefs[prefKey] = encoded }
}
```

## Avoiding Plaintext Storage

Common violations and their fixes:

| Violation | Fix |
|-----------|-----|
| Tokens in plain SharedPreferences | Use EncryptedSharedPreferences |
| Passwords in SQLite | Use SQLCipher or store only hashes server-side |
| API keys in strings.xml | Inject via `buildConfigField` from `local.properties` |
| Secrets in BuildConfig | Use encrypted storage at runtime; BuildConfig is in the APK |
| PII in logcat | Remove all `Log.d`/`Log.v` with sensitive data; use Timber with a release tree that strips logs |
| Data in URL query parameters | Use POST body or request headers |

## SQLCipher for Encrypted Databases

```kotlin
// build.gradle.kts
implementation("net.zetetic:sqlcipher-android:4.6.1")
implementation("androidx.sqlite:sqlite-ktx:2.4.0")

// Usage with Room
val passphrase = getOrCreateDatabasePassphrase() // stored in Keystore
val factory = SupportOpenHelperFactory(SQLiteDatabase.getBytes(passphrase.toCharArray()))

val db = Room.databaseBuilder(context, AppDatabase::class.java, "secure.db")
    .openHelperFactory(factory)
    .build()
```

Store the database passphrase in Android Keystore. Generate it once, encrypt it with a Keystore key, and store the encrypted passphrase in EncryptedSharedPreferences.

## Secure Temporary Files

```kotlin
// Create temp files in app-private cache directory
val tempFile = File.createTempFile("upload_", ".tmp", context.cacheDir)
try {
    // Use the file
    tempFile.outputStream().use { it.write(data) }
    // Process...
} finally {
    // Always delete when done
    tempFile.delete()
}
```

Never create temporary files on external storage. Always delete temporary files containing sensitive data in a `finally` block.

## Root Detection Considerations

On rooted devices, app sandboxing is compromised. Consider:

```kotlin
fun isDeviceCompromised(): Boolean {
    val indicators = listOf(
        // Common su binary locations
        "/system/bin/su", "/system/xbin/su", "/sbin/su",
        "/system/app/Superuser.apk",
        // Magisk indicators
        "/sbin/.magisk", "/data/adb/magisk",
    )
    val suBinaryExists = indicators.any { File(it).exists() }
    val testSu = try {
        Runtime.getRuntime().exec("su")
        true
    } catch (e: Exception) {
        false
    }
    return suBinaryExists || testSu
}
```

**Important**: Root detection is a defense-in-depth measure, not a security boundary. Determined attackers can bypass it. Use it to raise the bar, not as a sole protection. Combine with Play Integrity API for stronger device attestation.

## Backup Security

### Disabling Backup for Sensitive Data

In `AndroidManifest.xml`:

```xml
<application
    android:allowBackup="true"
    android:fullBackupContent="@xml/backup_rules"
    android:dataExtractionRules="@xml/data_extraction_rules">
```

`res/xml/backup_rules.xml` (API 23-30):
```xml
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <exclude domain="sharedpref" path="secure_prefs.xml" />
    <exclude domain="database" path="secure.db" />
    <exclude domain="file" path="sensitive/" />
    <exclude domain="root" path="tokens/" />
</full-backup-content>
```

`res/xml/data_extraction_rules.xml` (API 31+):
```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="secure_prefs.xml" />
        <exclude domain="database" path="secure.db" />
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="secure_prefs.xml" />
        <exclude domain="database" path="secure.db" />
    </device-transfer>
</data-extraction-rules>
```

For apps handling highly sensitive data (banking, health), consider `android:allowBackup="false"` entirely. For most apps, use selective exclusions to balance user convenience with security.

## Storage Decision Matrix

| Data Type | Storage Method | Keystore Binding | Biometric Gate |
|-----------|---------------|------------------|----------------|
| Auth tokens | EncryptedSharedPreferences | Yes (via MasterKey) | Optional |
| Encryption keys | Android Keystore directly | Yes | Recommended |
| User PII | EncryptedFile or SQLCipher | Yes | No |
| Session cookies | EncryptedSharedPreferences | Yes | No |
| Payment data | Do not store locally | N/A | N/A |
| Passwords | Do not store; use tokens | N/A | N/A |
| Biometric credentials | Keystore biometric-bound key | Yes | Required |
| Cache data | Internal cache dir | No | No |
| Temporary files | Internal cache, delete after use | No | No |
