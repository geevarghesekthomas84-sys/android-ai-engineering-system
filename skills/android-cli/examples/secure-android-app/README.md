# Secure Android App — Reference Project

Security-hardened Android application scaffold following OWASP MASVS guidelines.

## Security Features Included

1. **Network Security Configuration** — HTTPS only, certificate pinning ready
2. **Encrypted Storage** — EncryptedSharedPreferences for tokens/secrets
3. **Backup Disabled** — Prevents data extraction via backup
4. **No Exported Components** — Only the launcher activity is exported
5. **ProGuard/R8** — Code obfuscation enabled for release builds
6. **No Cleartext Traffic** — HTTP connections blocked
7. **Proper Permission Model** — Only required permissions, runtime requests

## Key Security Files

### res/xml/network_security_config.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    <debug-overrides>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>
</network-security-config>
```

### res/xml/data_extraction_rules.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root" />
        <exclude domain="database" />
        <exclude domain="sharedpref" />
    </cloud-backup>
    <device-transfer>
        <exclude domain="database" />
        <exclude domain="sharedpref" />
    </device-transfer>
</data-extraction-rules>
```

### Secure Token Storage
```kotlin
class SecureTokenManager(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context,
        "secure_tokens",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveAccessToken(token: String) {
        prefs.edit().putString("access_token", token).apply()
    }

    fun getAccessToken(): String? = prefs.getString("access_token", null)

    fun clearAll() { prefs.edit().clear().apply() }
}
```

### AndroidManifest.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:name=".SecureApplication"
        android:allowBackup="false"
        android:fullBackupContent="false"
        android:dataExtractionRules="@xml/data_extraction_rules"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:networkSecurityConfig="@xml/network_security_config"
        android:supportsRtl="true"
        android:theme="@style/Theme.SecureApp"
        android:usesCleartextTraffic="false">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- All other components are NOT exported -->
    </application>
</manifest>
```

### Release Build Configuration
```kotlin
// app/build.gradle.kts
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

### Dependencies
```kotlin
// Security-specific dependencies
implementation("androidx.security:security-crypto:1.1.0-alpha06")
implementation("androidx.biometric:biometric:1.2.0-alpha05")
```

## Security Checklist

- [ ] All network calls use HTTPS
- [ ] network_security_config.xml restricts cleartext traffic
- [ ] Tokens stored in EncryptedSharedPreferences
- [ ] No secrets in source code or BuildConfig
- [ ] allowBackup="false" and dataExtractionRules set
- [ ] Only launcher activity exported
- [ ] ProGuard/R8 enabled for release
- [ ] No sensitive data in logcat (release builds)
- [ ] Runtime permissions requested before use
- [ ] Deep links validated before processing
- [ ] WebViews (if any) have file access disabled
- [ ] Dependencies checked for known vulnerabilities
