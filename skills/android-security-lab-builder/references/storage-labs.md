# Storage Vulnerability Labs

> **DISCLAIMER**: All code in this document contains INTENTIONAL vulnerabilities for security education in isolated environments only. Never use vulnerable patterns in production. All data shown is synthetic.

## Lab 1: Plaintext SharedPreferences Credentials

**Learning Objective**: Understand why storing credentials in plaintext SharedPreferences is dangerous and how to use EncryptedSharedPreferences as the remediation.

**OWASP Mobile**: M9 — Insecure Data Storage

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — plaintext credential storage
// VULNERABILITY: CWE-312 — Cleartext storage of sensitive information

class PlaintextPrefsRepository(context: Context) {

    private val prefs = context.getSharedPreferences("user_creds", Context.MODE_PRIVATE)

    // VULNERABILITY: Credentials stored as plaintext in XML file on disk
    fun saveLogin(username: String, password: String, authToken: String) {
        prefs.edit()
            .putString("username", username)
            .putString("password", password)           // VULNERABILITY: plaintext password
            .putString("auth_token", authToken)         // VULNERABILITY: plaintext token
            .putString("credit_card", "4111111111111111") // VULNERABILITY: plaintext PII
            .apply()
    }

    fun getPassword(): String? = prefs.getString("password", null)
}
```

### Exploitation Steps

```bash
# 1. Install the vulnerable lab APK on the emulator
adb install app-vulnerable-debug.apk

# 2. Log in with test credentials (user1@test.invalid / password1)

# 3. Extract SharedPreferences via adb backup
adb backup -f backup.ab -noapk com.securitylab.storage.vulnerable.lab

# 4. Convert the backup to a tar archive
java -jar abe.jar unpack backup.ab backup.tar

# 5. Extract and read the preferences file
tar xf backup.tar
cat apps/com.securitylab.storage.vulnerable.lab/sp/user_creds.xml
# Output shows plaintext: <string name="password">password1</string>

# Alternative on rooted emulator:
adb shell run-as com.securitylab.storage.vulnerable.lab \
    cat /data/data/com.securitylab.storage.vulnerable.lab/shared_prefs/user_creds.xml
```

### Remediation

```kotlin
// FIX: Use EncryptedSharedPreferences with Android Keystore
// Dependency: androidx.security:security-crypto:1.1.0-alpha06

class SecurePrefsRepository(context: Context) {

    // FIX: MasterKey wraps an AES-256 key in the Android Keystore
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    // FIX: EncryptedSharedPreferences encrypts both keys and values
    private val prefs = EncryptedSharedPreferences.create(
        context,
        "secure_user_creds",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveLogin(username: String, password: String, authToken: String) {
        prefs.edit()
            .putString("username", username)
            .putString("password_hash", hashPassword(password)) // FIX: store hash, not plaintext
            .putString("auth_token", authToken)                 // FIX: encrypted at rest
            .apply()
    }

    // FIX: Use bcrypt or Argon2 for password hashing
    private fun hashPassword(password: String): String {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val spec = PBEKeySpec(password.toCharArray(), salt, 120_000, 256)
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val hash = factory.generateSecret(spec).encoded
        return Base64.encodeToString(salt + hash, Base64.NO_WRAP)
    }
}
```

---

## Lab 2: Unencrypted SQLite Database

**Learning Objective**: Demonstrate extraction of sensitive data from unencrypted Room/SQLite databases and remediate with SQLCipher.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — unencrypted database
// VULNERABILITY: CWE-311 — Missing encryption of sensitive data

@Entity(tableName = "medical_records")
data class MedicalRecord(
    @PrimaryKey val id: Int,
    val patientName: String,         // VULNERABILITY: PII in plaintext DB
    val diagnosis: String,           // VULNERABILITY: sensitive health data
    val ssn: String,                 // VULNERABILITY: plaintext SSN
    val prescriptions: String
)

@Database(entities = [MedicalRecord::class], version = 1)
abstract class LabDatabase : RoomDatabase() {
    abstract fun medicalDao(): MedicalDao

    companion object {
        fun create(context: Context): LabDatabase =
            // VULNERABILITY: No encryption — database file is plaintext SQLite
            Room.databaseBuilder(context, LabDatabase::class.java, "patient_records.db")
                .build()
    }
}
```

### Exploitation Steps

```bash
# Pull the database from the emulator (rooted or debuggable)
adb shell run-as com.securitylab.storage.vulnerable.lab \
    cp /data/data/com.securitylab.storage.vulnerable.lab/databases/patient_records.db /sdcard/
adb pull /sdcard/patient_records.db

# Open with sqlite3 and dump contents
sqlite3 patient_records.db "SELECT patientName, ssn, diagnosis FROM medical_records;"
# Output: Alice Testuser|000-00-0001|Test Condition Alpha
```

### Remediation

```kotlin
// FIX: Use SQLCipher for encrypted Room database
// Dependency: net.zetetic:android-database-sqlcipher:4.5.6
//             androidx.sqlite:sqlite-ktx:2.4.0

fun createEncrypted(context: Context): LabDatabase {
    // FIX: Derive passphrase from Keystore-backed key
    val passphrase = getOrCreateDatabaseKey(context)
    val factory = SupportFactory(SQLiteDatabase.getBytes(passphrase.toCharArray()))

    return Room.databaseBuilder(context, LabDatabase::class.java, "patient_records_enc.db")
        .openHelperFactory(factory)  // FIX: SQLCipher encryption
        .build()
}
```

---

## Lab 3: World-Readable Files

**Learning Objective**: Show how `MODE_WORLD_READABLE` (deprecated) and misconfigured file permissions expose data to other apps.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — world-readable files
// VULNERABILITY: CWE-732 — Incorrect permission assignment

class InsecureFileStorage(private val context: Context) {

    @Suppress("DEPRECATION")
    fun saveApiKey(key: String) {
        // VULNERABILITY: MODE_WORLD_READABLE allows any app to read this file
        val fos = context.openFileOutput("api_config.txt", Context.MODE_WORLD_READABLE)
        fos.write("API_KEY=$key\nAPI_SECRET=fake_secret_12345".toByteArray())
        fos.close()
    }

    fun saveToExternalStorage(data: String) {
        // VULNERABILITY: External storage is world-readable on older Android versions
        val file = File(context.getExternalFilesDir(null), "session_tokens.txt")
        file.writeText(data)
    }
}
```

### Exploitation Steps

```bash
# Another app (or adb) can read the world-readable file:
adb shell cat /data/data/com.securitylab.storage.vulnerable.lab/files/api_config.txt
# Output: API_KEY=lab_test_key_00000   API_SECRET=fake_secret_12345

# External storage files:
adb shell cat /sdcard/Android/data/com.securitylab.storage.vulnerable.lab/files/session_tokens.txt
```

### Remediation

```kotlin
// FIX: Use MODE_PRIVATE and internal storage only
class SecureFileStorage(private val context: Context) {
    fun saveApiKey(key: String) {
        // FIX: MODE_PRIVATE — accessible only to this app
        context.openFileOutput("api_config.txt", Context.MODE_PRIVATE).use { fos ->
            // FIX: Encrypt the key before writing
            val encrypted = encryptWithKeystore(key)
            fos.write(encrypted)
        }
    }
}
```

---

## Lab 4: Insecure Backup Configuration

**Learning Objective**: Demonstrate data extraction through `adb backup` when `allowBackup` is enabled without proper backup rules.

### Vulnerable Implementation

```xml
<!-- SECURITY LAB: INTENTIONAL vulnerability — insecure backup -->
<!-- VULNERABILITY: CWE-530 — Exposure of backup file to unauthorized user -->
<application
    android:allowBackup="true"
    android:testOnly="true"
    android:label="Security Lab - Storage">
    <!-- No android:fullBackupContent rules — everything is backed up -->
</application>
```

### Exploitation Steps

```bash
adb backup -f lab_backup.ab -apk com.securitylab.storage.vulnerable.lab
# User confirms on device (or auto-confirmed on testOnly apps)
java -jar abe.jar unpack lab_backup.ab lab_backup.tar
tar xf lab_backup.tar
# Now browse: apps/com.securitylab.storage.vulnerable.lab/
#   sp/user_creds.xml, db/patient_records.db, f/api_config.txt
```

### Remediation

```xml
<!-- FIX: Disable backup or specify strict backup rules -->
<application android:allowBackup="false">
    <!-- Or, for Android 12+, use granular rules: -->
    <!-- android:dataExtractionRules="@xml/data_extraction_rules" -->
</application>
```

```xml
<!-- res/xml/data_extraction_rules.xml -->
<!-- FIX: Exclude sensitive files from all backup mechanisms -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="user_creds.xml"/>
        <exclude domain="database" path="patient_records.db"/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="user_creds.xml"/>
    </device-transfer>
</data-extraction-rules>
```

---

## Lab 5: Logcat Data Exposure

**Learning Objective**: Show how sensitive data logged to Logcat can be read by other apps (pre-Android 11) or via adb.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — sensitive data in logs
// VULNERABILITY: CWE-532 — Insertion of sensitive information into log file

class AuthManager {
    fun login(username: String, password: String): Boolean {
        // VULNERABILITY: Password logged in plaintext
        Log.d("AuthManager", "Login attempt: user=$username, pass=$password")

        val token = authenticate(username, password)
        // VULNERABILITY: Auth token logged
        Log.i("AuthManager", "Auth token received: $token")

        return token != null
    }
}
```

### Exploitation Steps

```bash
# Monitor logcat for sensitive data
adb logcat -s AuthManager:* | grep -E "(pass=|token)"
# Output: D/AuthManager: Login attempt: user=user1@test.invalid, pass=password1
# Output: I/AuthManager: Auth token received: eyJhbGciOiJIUzI1...
```

### Remediation

```kotlin
// FIX: Never log sensitive data; use BuildConfig to strip debug logs from release
class AuthManager {
    fun login(username: String, password: String): Boolean {
        // FIX: Log only non-sensitive event identifiers
        if (BuildConfig.DEBUG) {
            Log.d("AuthManager", "Login attempt for user ID: ${username.hashCode()}")
        }
        val token = authenticate(username, password)
        // FIX: Never log tokens, passwords, PII, or session identifiers
        return token != null
    }
}
```

---

## Lab 6: Clipboard Exposure

**Learning Objective**: Demonstrate how sensitive data placed on the clipboard is accessible to other apps.

### Vulnerable Implementation

```kotlin
// SECURITY LAB: INTENTIONAL vulnerability — clipboard exposure
// VULNERABILITY: CWE-200 — Exposure of sensitive information

fun copyPasswordToClipboard(context: Context, password: String) {
    // VULNERABILITY: Password placed on clipboard, visible to other apps
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val clip = ClipData.newPlainText("password", password)
    clipboard.setPrimaryClip(clip)
    // VULNERABILITY: Clipboard content persists after app is backgrounded
}
```

### Exploitation Steps

```bash
# Read clipboard content via adb
adb shell service call clipboard 2 s16 com.securitylab.storage.vulnerable.lab
# Or use a malicious app in the lab that monitors ClipboardManager.OnPrimaryClipChangedListener
```

### Remediation

```kotlin
// FIX: Use ClipDescription.EXTRA_IS_SENSITIVE (Android 13+) and auto-clear
fun copyPasswordSecurely(context: Context, password: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val clip = ClipData.newPlainText("", password).apply {
        // FIX: Mark as sensitive so the system hides it from visual previews
        description.extras = PersistableBundle().apply {
            putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
        }
    }
    clipboard.setPrimaryClip(clip)

    // FIX: Auto-clear clipboard after a timeout
    Handler(Looper.getMainLooper()).postDelayed({
        clipboard.clearPrimaryClip()
    }, 30_000L)
}
```
