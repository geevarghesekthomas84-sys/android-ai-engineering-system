# APK Size Reduction

## R8: Minification, Obfuscation, and Tree Shaking

R8 is the default code shrinker in AGP. It performs three operations:

1. **Tree shaking** -- removes unreachable code and classes
2. **Minification** -- shortens class, method, and field names
3. **Optimization** -- inlines methods, removes dead branches, merges classes

### Enabling R8

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

### Common ProGuard/R8 Rules

```proguard
# Keep data classes used with serialization (Kotlinx Serialization)
-keepclassmembers @kotlinx.serialization.Serializable class * {
    *;
}

# Keep Retrofit interfaces
-keep,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}

# Keep Compose stability metadata (needed for skippability)
-keep class * {
    @androidx.compose.runtime.Stable *;
    @androidx.compose.runtime.Immutable *;
}

# Keep Room entities
-keep @androidx.room.Entity class * { *; }
```

### R8 Full Mode

AGP 9.x enables R8 full mode by default. Full mode applies more aggressive optimizations:

```kotlin
// Explicit in gradle.properties (default in AGP 9.0+)
android.enableR8.fullMode=true
```

Full mode may remove classes accessed only via reflection. Add keep rules for reflection targets.

## Resource Shrinking

Resource shrinking removes unused resources after code shrinking. It requires `isMinifyEnabled = true`.

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
}
```

### Keeping Specific Resources

If resource shrinking removes resources loaded dynamically (e.g., `getIdentifier()`), create `res/raw/keep.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@layout/l_used_via_reflection,@drawable/ic_dynamic_*"
    tools:shrinkMode="safe" />
```

## Per-Density APK Splits

Generate separate APKs for each screen density so users download only the resources they need:

```kotlin
android {
    splits {
        density {
            isEnable = true
            // Include these densities
            include("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
            // Exclude ldpi and tvdpi
            compatibleScreens("small", "normal", "large", "xlarge")
        }
    }
}
```

Note: If using App Bundle (AAB), Google Play handles density splitting automatically. Per-density APK splits are only needed for direct APK distribution.

## App Bundle (AAB) vs APK

An Android App Bundle lets Google Play generate optimized APKs per device configuration:

| Feature | APK | AAB |
|---|---|---|
| Density resources | All included | Per-device |
| ABI libraries | All included | Per-device |
| Language resources | All included | Per-device |
| Typical size reduction | Baseline | 15-30% smaller downloads |

Always publish AAB to Google Play. Use APKs only for sideloading or alternative stores.

```kotlin
// Generate AAB
// ./gradlew :app:bundleRelease
// Output: app/build/outputs/bundle/release/app-release.aab
```

Test locally with `bundletool`:

```bash
java -jar bundletool.jar build-apks \
    --bundle=app-release.aab \
    --output=app.apks \
    --connected-device

java -jar bundletool.jar install-apks --apks=app.apks
```

## Removing Unused Dependencies

Audit dependencies regularly. Each library adds code and resources.

### Finding Unused Dependencies

Use the Dependency Analysis Gradle Plugin:

```kotlin
// settings.gradle.kts
plugins {
    id("com.autonomousapps.dependency-analysis") version "2.7.0"
}
```

```bash
./gradlew buildHealth
# Reports unused dependencies, used-but-undeclared transitive dependencies,
# and dependencies that should be api vs implementation
```

### Common Size Offenders

- **Material Icons Extended** (`material-icons-extended`): Adds ~24MB uncompressed. Import only the icons you use from `material-icons-core` or copy individual icon files.
- **Guava**: Large library often pulled transitively. Replace with Kotlin stdlib equivalents.
- **Unused Play Services modules**: Each module adds size. Only include what you use.

```kotlin
// BAD: pulls in all Material icons
implementation("androidx.compose.material:material-icons-extended")

// GOOD: use only core icons, or copy specific extended icons into your project
implementation("androidx.compose.material:material-icons-core")
```

## APK Analyzer

Android Studio's APK Analyzer shows exactly what consumes space.

**Android Studio > Build > Analyze APK** or drag an APK/AAB into the editor.

Key areas to check:

- `classes*.dex` -- code size. Compare with R8-enabled build.
- `res/` -- resource files by type and density. Look for large PNGs.
- `lib/` -- native libraries by ABI. Remove unused ABIs.
- `assets/` -- bundled files. Compress or lazy-download large assets.

Compare two APKs to see the size impact of a change:

1. Open the first APK in Analyzer
2. Click **Compare with previous APK** in the top right
3. Select the second APK

## Vector Drawables vs Rasters

Vector drawables (`VectorDrawable` / Compose `ImageVector`) scale to any density from a single file. A vector icon is typically 1-3KB vs 5-20KB per density for PNGs.

```kotlin
// Compose: use vector icons
Icon(
    imageVector = Icons.Default.Search,
    contentDescription = "Search"
)

// For custom vectors, place SVG in res/drawable as XML vector:
// res/drawable/ic_custom.xml (converted from SVG via Android Studio)
```

Use vectors for icons and simple illustrations. Use rasters (WebP) for photos and complex images.

## WebP Format

WebP provides 25-35% smaller files than PNG with lossless compression, and 25-34% smaller than JPEG with lossy compression.

Convert existing images in Android Studio:

1. Right-click image files in `res/drawable`
2. Select **Convert to WebP**
3. Choose lossy or lossless, set quality

Or use the command line:

```bash
cwebp -q 80 input.png -o output.webp
```

Minimum API requirement: WebP lossy is supported from API 14, WebP lossless and transparency from API 18. For `minSdk >= 18`, convert all PNGs to WebP.

## Debug vs Release Size Comparison

Debug builds are significantly larger because they include:

- Debug symbols and metadata
- No R8 shrinking or obfuscation
- No resource shrinking
- Logging and debugging libraries (`debugImplementation`)

Always measure APK size on **release** builds:

```bash
# Build release APK
./gradlew :app:assembleRelease

# Check file size
# Windows:
# (Get-Item app\build\outputs\apk\release\app-release.apk).Length / 1MB

# Or use APK Analyzer for detailed breakdown
```

Track release APK size in CI to catch regressions:

```kotlin
// In a CI script, after assembleRelease
val apk = File("app/build/outputs/apk/release/app-release.apk")
val sizeMB = apk.length().toDouble() / (1024 * 1024)
check(sizeMB < 15.0) { "APK size $sizeMB MB exceeds 15 MB limit" }
```
