# Lab Architecture and Environment Setup

> **DISCLAIMER**: This document describes infrastructure for building intentionally vulnerable applications for authorized security education only. All labs must run in isolated environments with synthetic data. Never deploy lab applications or infrastructure to production networks.

## Isolated Emulator Configuration

Every security lab runs inside an Android emulator with strict isolation. Use the following AVD configuration as the baseline:

```bash
# Create a dedicated lab emulator (no Google Play — reduces attack surface confusion)
avdmanager create avd \
  --name "security-lab" \
  --package "system-images;android-34;default;x86_64" \
  --device "pixel_6" \
  --force

# Launch with network isolation and writable system
emulator -avd security-lab \
  -no-snapshot \
  -writable-system \
  -no-boot-anim \
  -gpu swiftshader_indirect \
  -netdelay none \
  -netspeed full
```

For network interception labs, route emulator traffic through a local proxy:

```bash
# Launch emulator with proxy for mitmproxy/Burp labs
emulator -avd security-lab \
  -http-proxy http://127.0.0.1:8080 \
  -no-snapshot
```

### Emulator Hardening for Labs

Configure the emulator to prevent accidental leakage:

```ini
# ~/.android/avd/security-lab.avd/config.ini additions
hw.gps=no
hw.sensors.proximity=no
hw.camera.back=none
hw.camera.front=none
```

Disable real network access when the lab does not require it:

```bash
# Block emulator from reaching the internet (iptables on the host)
# Linux/macOS:
iptables -A OUTPUT -m owner --uid-owner $(id -u) -d 10.0.2.0/24 -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner $(id -u) -j DROP

# Windows — use Windows Firewall rules to restrict emulator.exe outbound
```

## Network Isolation

### Local-Only Backend Server

For labs that require a backend (authentication, API testing), run a local server that binds only to `127.0.0.1`:

```kotlin
// lab-config/local-server/build.gradle.kts
plugins {
    application
    kotlin("jvm")
}

dependencies {
    implementation("io.ktor:ktor-server-netty:2.3.12")
    implementation("io.ktor:ktor-server-content-negotiation:2.3.12")
    implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.12")
}

application {
    mainClass.set("lab.server.MainKt")
}
```

```kotlin
// lab-config/local-server/src/main/kotlin/lab/server/Main.kt
// SECURITY LAB: Intentionally insecure server for educational purposes
package lab.server

import io.ktor.server.engine.*
import io.ktor.server.netty.*

fun main() {
    embeddedServer(Netty, port = 8443, host = "127.0.0.1") {
        configureRouting()  // Lab-specific routes
    }.start(wait = true)
}
```

The emulator reaches the host at `10.0.2.2`, so the app uses `http://10.0.2.2:8443` as the base URL.

### Docker-Based Backend for Server-Side Labs

For more complex labs (SSRF, API misconfiguration), use Docker Compose with an isolated network:

```yaml
# lab-config/docker-compose.yml
version: "3.9"
services:
  lab-api:
    build: ./lab-api
    ports:
      - "127.0.0.1:8443:8443"
    networks:
      - lab-internal
    environment:
      - LAB_MODE=vulnerable    # Switch to "secure" for remediation variant
      - DATABASE_URL=sqlite:///data/lab.db

  lab-db:
    image: postgres:16-alpine
    networks:
      - lab-internal
    environment:
      - POSTGRES_DB=labdata
      - POSTGRES_USER=labuser
      - POSTGRES_PASSWORD=labpass_not_real

networks:
  lab-internal:
    internal: true   # No external internet access
```

## Synthetic Data Generation

Never use real data. Generate lab data with a dedicated seed:

```kotlin
// lab-config/src/main/kotlin/lab/data/SyntheticDataGenerator.kt
// SECURITY LAB: Generates fake data for lab exercises
package lab.data

object SyntheticDataGenerator {

    private val firstNames = listOf("Alice", "Bob", "Charlie", "Diana", "Eve", "Frank")
    private val lastNames = listOf("Testuser", "Labaccount", "Demoperson", "Fakeprofile")
    private val domains = listOf("example.com", "test.invalid", "lab.local")

    fun generateUser(index: Int): LabUser = LabUser(
        id = index,
        name = "${firstNames[index % firstNames.size]} ${lastNames[index % lastNames.size]}",
        email = "user${index}@${domains[index % domains.size]}",
        // Intentionally weak for the vulnerable variant
        password = "password${index}",
        creditCard = "4111111111111111",  // Standard test card number
        ssn = "000-00-${String.format("%04d", index)}"  // Fake SSN range
    )

    fun generateUsers(count: Int): List<LabUser> =
        (1..count).map { generateUser(it) }
}

data class LabUser(
    val id: Int,
    val name: String,
    val email: String,
    val password: String,
    val creditCard: String,
    val ssn: String
)
```

## Lab Project Structure

Each lab uses Android product flavors to separate the vulnerable and secure implementations:

```kotlin
// build.gradle.kts (app module)
android {
    namespace = "com.securitylab.storage"  // Adjust per lab topic
    compileSdk = 36

    defaultConfig {
        applicationId = "com.securitylab.storage.vulnerable.lab"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "1.0-lab"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    flavorDimensions += "security"
    productFlavors {
        create("vulnerable") {
            dimension = "security"
            applicationIdSuffix = ".vulnerable"
            buildConfigField("boolean", "IS_VULNERABLE", "true")
        }
        create("secure") {
            dimension = "security"
            applicationIdSuffix = ".secure"
            buildConfigField("boolean", "IS_VULNERABLE", "false")
        }
    }

    // Prevent accidental release builds
    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = null  // No release signing
        }
    }
}
```

Source sets:
- `src/main/` — Shared UI, navigation, models, warning banner
- `src/vulnerable/` — Code with intentional vulnerabilities
- `src/secure/` — Remediated code demonstrating the fix

## Safety Markers in Code

Every file with intentional vulnerabilities must use these comment conventions:

```kotlin
// SECURITY LAB: This file contains INTENTIONAL vulnerabilities for educational purposes.
// DO NOT use this code in production applications.

class InsecureStorageRepository {

    // VULNERABILITY: CWE-312 — Cleartext storage of sensitive information
    // Credentials are stored in plaintext SharedPreferences, readable by any
    // process with root access or via adb backup.
    fun saveCredentials(username: String, password: String) {
        prefs.edit()
            .putString("username", username)
            .putString("password", password)  // VULNERABILITY: plaintext password
            .apply()
    }

    // FIX: Use EncryptedSharedPreferences backed by Android Keystore
    // fun saveCredentials(username: String, password: String) {
    //     encryptedPrefs.edit()
    //         .putString("username", username)
    //         .putString("password", hashPassword(password))
    //         .apply()
    // }
}
```

## Automated Lab Validation

Each lab includes instrumentation tests that verify both the vulnerability and the fix:

```kotlin
// src/androidTest/kotlin/lab/validation/StorageLabValidation.kt
@RunWith(AndroidJUnit4::class)
class StorageLabValidation {

    @Test
    fun vulnerableVariant_credentialsStoredInPlaintext() {
        // Only runs against the "vulnerable" flavor
        assumeTrue(BuildConfig.IS_VULNERABLE)

        val repo = InsecureStorageRepository(context)
        repo.saveCredentials("testuser", "s3cretP@ss")

        // Verify the vulnerability: read SharedPreferences XML directly
        val prefsFile = File(context.dataDir, "shared_prefs/user_prefs.xml")
        val content = prefsFile.readText()
        assertThat(content).contains("s3cretP@ss")  // Plaintext password present
    }

    @Test
    fun secureVariant_credentialsEncrypted() {
        // Only runs against the "secure" flavor
        assumeFalse(BuildConfig.IS_VULNERABLE)

        val repo = SecureStorageRepository(context)
        repo.saveCredentials("testuser", "s3cretP@ss")

        val prefsFile = File(context.dataDir, "shared_prefs/secure_user_prefs.xml")
        val content = prefsFile.readText()
        assertThat(content).doesNotContain("s3cretP@ss")  // Password is encrypted
    }
}
```

## Lab Reset Scripts

Provide a reset script that returns the lab to its initial state:

```bash
#!/usr/bin/env bash
# lab-config/reset-lab.sh
# Resets the security lab to its initial state

set -euo pipefail

PACKAGE="com.securitylab.storage.vulnerable.lab"

echo "[*] Clearing app data..."
adb shell pm clear "$PACKAGE"

echo "[*] Reinstalling lab APK..."
adb install -r "./app/build/outputs/apk/vulnerable/debug/app-vulnerable-debug.apk"

echo "[*] Seeding synthetic data..."
adb shell am start -n "$PACKAGE/.LabSetupActivity" \
    --es seed_mode "default"

echo "[*] Lab reset complete."
echo "[!] REMINDER: This app is intentionally vulnerable. Use only in isolated environments."
```

## Warning Banner (Shared UI)

Every lab app displays a persistent warning:

```kotlin
// src/main/kotlin/lab/ui/WarningBanner.kt
@Composable
fun LabWarningBanner() {
    Surface(
        color = MaterialTheme.colorScheme.errorContainer,
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = "SECURITY LAB — INTENTIONALLY VULNERABLE — DO NOT USE IN PRODUCTION",
            color = MaterialTheme.colorScheme.onErrorContainer,
            style = MaterialTheme.typography.labelMedium,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(4.dp)
        )
    }
}
```

Place `LabWarningBanner()` at the top of every screen's Scaffold.
