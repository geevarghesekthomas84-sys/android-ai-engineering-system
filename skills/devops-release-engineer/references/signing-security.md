# Signing Security

## Keystore Creation

Generate a new release keystore with keytool:

```bash
keytool -genkeypair \
    -alias release-key \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -keystore release-keystore.jks \
    -storepass <store-password> \
    -keypass <key-password> \
    -dname "CN=Your Name, OU=Your Unit, O=Your Org, L=City, ST=State, C=US"
```

For Play App Signing upload keys, Google recommends RSA 2048-bit with 25+ years validity.

## Protecting the Keystore

### Never commit the keystore to version control

Add to `.gitignore`:

```gitignore
# Signing
*.jks
*.keystore
keystore.properties
local.properties
signing/
```

### Store credentials in a properties file outside the repo

Create `keystore.properties` (excluded from git):

```properties
RELEASE_KEYSTORE_FILE=../signing/release-keystore.jks
RELEASE_KEYSTORE_PASSWORD=your-store-password
RELEASE_KEY_ALIAS=release-key
RELEASE_KEY_PASSWORD=your-key-password
```

Load in `app/build.gradle.kts`:

```kotlin
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["RELEASE_KEYSTORE_FILE"] as? String ?: "/dev/null")
            storePassword = keystoreProperties["RELEASE_KEYSTORE_PASSWORD"] as? String ?: ""
            keyAlias = keystoreProperties["RELEASE_KEY_ALIAS"] as? String ?: ""
            keyPassword = keystoreProperties["RELEASE_KEY_PASSWORD"] as? String ?: ""
        }
    }
}
```

## Environment-Based Signing for CI

In CI environments, decode the keystore from a base64-encoded secret:

```yaml
# GitHub Actions step
- name: Decode keystore
  run: |
    echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 --decode > app/release-keystore.jks
  env:
    KEYSTORE_FILE: app/release-keystore.jks
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
    KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
```

Encode the keystore for storage as a secret:

```bash
base64 -w 0 release-keystore.jks > keystore-base64.txt
# Copy content of keystore-base64.txt into GitHub Secret RELEASE_KEYSTORE_BASE64
```

## Google Play App Signing

### Enrollment

Google Play App Signing lets Google manage the app signing key while you hold an upload key. Benefits:

- Google securely stores the signing key in HSMs
- If you lose your upload key, Google can reset it (the signing key stays the same)
- Enables automatic optimizations like APK signature scheme v3 and key rotation

### Upload Key vs Signing Key

| Aspect | Upload Key | Signing Key |
|--------|-----------|-------------|
| Who holds it | You (developer) | Google |
| Used for | Signing AAB before upload | Signing APKs delivered to users |
| Rotation | Request reset via Play Console | Managed by Google, supports v3 rotation |
| Loss impact | Request new upload key from Google | Cannot be replaced (app identity) |

### Enrolling an existing app

1. Go to Play Console > App > Setup > App signing
2. Export and upload your existing signing key
3. Google stores it and generates a new upload key for you
4. From now on, sign with the upload key; Google re-signs with the app signing key

### Generating a new upload key after reset

```bash
keytool -genkeypair \
    -alias upload-key \
    -keyalg RSA \
    -keysize 2048 \
    -validity 9125 \
    -keystore upload-keystore.jks
```

Export the certificate for registration with Play Console:

```bash
keytool -export \
    -alias upload-key \
    -keystore upload-keystore.jks \
    -rfc \
    -file upload-certificate.pem
```

## Key Rotation

Android supports key rotation via APK Signature Scheme v3. This allows changing the signing key while maintaining trust with the original key through a proof-of-rotation chain.

```bash
# Create a lineage file linking old key to new key
apksigner rotate \
    --out lineage.bin \
    --old-signer --ks old-keystore.jks --ks-key-alias old-key \
    --new-signer --ks new-keystore.jks --ks-key-alias new-key

# Sign with the new key and include the lineage
apksigner sign \
    --ks new-keystore.jks \
    --ks-key-alias new-key \
    --lineage lineage.bin \
    --out app-rotated.apk \
    app-unsigned.apk
```

## Signing Report

Verify the signing configuration with Gradle's signingReport task:

```bash
./gradlew signingReport
```

Output shows the SHA-1 and SHA-256 fingerprints for each variant. Use these to:

- Register with Google APIs (Maps, OAuth)
- Configure Firebase
- Verify the correct key is used in CI

## Verifying APK Signature

### Using apksigner

```bash
# Verify the APK is signed and the signature is valid
apksigner verify --verbose --print-certs app-release.apk
```

Expected output for a valid signature:

```
Verifies
Verified using v1 scheme (JAR signing): true
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): true
```

### Using jarsigner (legacy, v1 only)

```bash
jarsigner -verify -verbose -certs app-release.apk
```

### Verifying AAB signature

```bash
jarsigner -verify app-release.aab
```

## CI/CD Secrets Management

### GitHub Actions Secrets

Store these as repository or organization secrets:

| Secret Name | Value |
|------------|-------|
| `RELEASE_KEYSTORE_BASE64` | Base64-encoded keystore file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias name |
| `KEY_PASSWORD` | Key password |

### Security best practices for CI signing

1. **Use environment-level secrets** for production signing, restricted to the `production` environment with required reviewers
2. **Limit secret access** to specific branches (e.g., only `main` and `release/*` can access production signing secrets)
3. **Rotate upload keys periodically** (annually or after team member departure)
4. **Audit secret access** via GitHub audit log
5. **Never log secrets** -- ensure build scripts do not echo passwords or key content
6. **Use short-lived credentials** where possible (e.g., service account keys with expiration for Play Console API)

### Storing keystore in a vault (advanced)

For teams needing centralized secret management:

```bash
# Fetch from HashiCorp Vault in CI
export KEYSTORE_PASSWORD=$(vault kv get -field=password secret/android/keystore)
vault kv get -field=keystore_b64 secret/android/keystore | base64 -d > release-keystore.jks
```

Or use Google Cloud Secret Manager:

```bash
gcloud secrets versions access latest --secret="android-keystore" | base64 -d > release-keystore.jks
gcloud secrets versions access latest --secret="keystore-password"
```
