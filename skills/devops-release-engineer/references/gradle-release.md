# Gradle Release Configuration

## Build Types

Configure debug, staging, and release build types in `app/build.gradle.kts`:

```kotlin
android {
    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            buildConfigField("String", "API_BASE_URL", "\"https://api-dev.example.com\"")
        }

        create("staging") {
            initWith(getByName("debug"))
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField("String", "API_BASE_URL", "\"https://api-staging.example.com\"")
            signingConfig = signingConfigs.getByName("release")
        }

        release {
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            buildConfigField("String", "API_BASE_URL", "\"https://api.example.com\"")
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

## Product Flavors

Use product flavors for multi-brand or environment-specific builds:

```kotlin
android {
    flavorDimensions += "environment"

    productFlavors {
        create("free") {
            dimension = "environment"
            applicationIdSuffix = ".free"
            buildConfigField("Boolean", "IS_PREMIUM", "false")
        }
        create("premium") {
            dimension = "environment"
            buildConfigField("Boolean", "IS_PREMIUM", "true")
        }
    }
}
```

## Signing Configuration

Read signing credentials from environment variables or a local properties file, never hardcode them:

```kotlin
android {
    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_FILE")
                ?: project.findProperty("RELEASE_KEYSTORE_FILE") as? String
            val ksPassword = System.getenv("KEYSTORE_PASSWORD")
                ?: project.findProperty("RELEASE_KEYSTORE_PASSWORD") as? String
            val ksAlias = System.getenv("KEY_ALIAS")
                ?: project.findProperty("RELEASE_KEY_ALIAS") as? String
            val ksAliasPassword = System.getenv("KEY_PASSWORD")
                ?: project.findProperty("RELEASE_KEY_PASSWORD") as? String

            if (keystorePath != null && ksPassword != null && ksAlias != null && ksAliasPassword != null) {
                storeFile = file(keystorePath)
                storePassword = ksPassword
                keyAlias = ksAlias
                keyPassword = ksAliasPassword
            }
        }
    }
}
```

## R8 Configuration

### proguard-rules.pro

```proguard
# Keep application entry points
-keep class com.example.app.** { *; }

# Retrofit / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Gson / Kotlinx Serialization
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Room database
-keep class * extends androidx.room.RoomDatabase
-keepclassmembers class * {
    @androidx.room.* <methods>;
}

# Preserve line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
```

### Consumer Rules (for library modules)

Place `consumer-rules.pro` in library modules so consuming apps automatically include the rules:

```proguard
# Exposed API classes that must not be obfuscated
-keep public class com.example.library.api.** { *; }
```

## Resource Shrinking

Resource shrinking removes unused resources after code shrinking. Enable it alongside `isMinifyEnabled`:

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
}
```

To keep specific resources, create `res/raw/keep.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@layout/used_by_reflection,@drawable/icon_*"
    tools:discard="@layout/unused_layout"
    tools:shrinkMode="strict" />
```

## APK Splits

Split APKs by ABI to reduce download size when not using AAB:

```kotlin
android {
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            isUniversalApk = true
        }
    }
}
```

## App Bundle (AAB) Generation

AAB is the preferred format for Play Console. Build with:

```bash
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

Validate the bundle with bundletool:

```bash
java -jar bundletool.jar validate --bundle=app-release.aab
```

Generate APKs from AAB for local testing:

```bash
java -jar bundletool.jar build-apks \
    --bundle=app-release.aab \
    --output=app.apks \
    --ks=keystore.jks \
    --ks-pass=pass:keystorePassword \
    --ks-key-alias=keyAlias \
    --key-pass=pass:keyPassword
```

## Version Management

### Automated versionCode with date-based strategy

```kotlin
// In app/build.gradle.kts
val versionMajor = 2
val versionMinor = 4
val versionPatch = 1

android {
    defaultConfig {
        // Date-based: YMMDDHHC format for guaranteed uniqueness
        val dateCode = java.time.LocalDateTime.now().let {
            it.year % 100 * 10_000_000 +
            it.monthValue * 100_000 +
            it.dayOfMonth * 1_000 +
            (System.getenv("BUILD_NUMBER")?.toIntOrNull() ?: 0)
        }
        versionCode = dateCode
        versionName = "$versionMajor.$versionMinor.$versionPatch"
    }
}
```

### Sequential versionCode from CI build number

```kotlin
android {
    defaultConfig {
        versionCode = (System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull() ?: 1)
        versionName = "$versionMajor.$versionMinor.$versionPatch"
    }
}
```

## Build Cache

Enable Gradle build cache in `gradle.properties`:

```properties
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC
```

For CI, use a remote build cache or configure local cache in the workflow:

```properties
# CI-specific gradle.properties
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.parallel=true
org.gradle.daemon=false
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m
```

## Build Performance Tips

1. **Use configuration cache** to skip configuration phase on repeat builds
2. **Avoid dynamic versions** (`implementation("lib:+")`) as they disable caching
3. **Use `buildSrc` or version catalogs** for dependency management
4. **Split large modules** so incremental builds skip unchanged code
5. **Disable unused build features**: if not using data binding, do not enable it
6. **Profile builds** with `./gradlew assembleRelease --scan` to identify bottlenecks
