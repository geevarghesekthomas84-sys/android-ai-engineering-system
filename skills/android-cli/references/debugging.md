# Android Debugging

## Logcat

### Basic Filtering
```powershell
# Errors only
adb logcat *:E

# Specific tag at verbose level, silence others
adb logcat MyTag:V *:S

# Multiple tags
adb logcat MyTag:D AnotherTag:I *:S

# With timestamps and thread info
adb logcat -v threadtime MyTag:D *:S

# Write to file while displaying
adb logcat -v time 2>&1 | Tee-Object -FilePath logcat.txt
```

### Filtering by App
```powershell
# Get app PID first
$pid = adb shell pidof com.example.app
adb logcat --pid=$pid

# Or filter by package name in log output
adb logcat | findstr "com.example.app"
```

### Log Levels
| Level | Flag | Use |
|-------|------|-----|
| Verbose | V | Detailed development logs |
| Debug | D | Debug information |
| Info | I | General operational info |
| Warn | W | Potential issues |
| Error | E | Errors that affect functionality |
| Fatal/Assert | F/A | Fatal errors, crashes |

### Crash Analysis
```powershell
# Find crash stack traces
adb logcat *:E | findstr "FATAL\|Exception\|Error\|Caused by"

# Get the last crash
adb logcat -b crash -d
```

## UI Debugging

### Layout Inspector via Android CLI
```powershell
# Dump UI tree
android layout -p

# Full tree including hidden elements
android layout --full -p

# Save to file
android layout -p -o layout.json

# Flat list (easier to search)
android layout --flat -p
```

### Visual Inspection
```powershell
# Screenshot
android screen capture -o screen.png

# Annotated screenshot (numbered bounding boxes)
android screen capture --annotate -o annotated.png

# Resolve annotation labels to coordinates
android screen resolve --screenshot annotated.png --string "#5"
```

### Android Studio Layout Inspector
When Android Studio is running:
```powershell
android studio analyze-file <layout-file>
android studio render-compose-preview <composable-file>
```

## Build Error Diagnosis

### Common Gradle Errors

**Dependency conflict:**
```powershell
.\gradlew app:dependencies --configuration releaseRuntimeClasspath
```

**Compilation errors — get full output:**
```powershell
.\gradlew assembleDebug --stacktrace 2>&1 | Out-String
```

**Configuration cache issues:**
```powershell
.\gradlew assembleDebug --no-configuration-cache
```

**Clean rebuild:**
```powershell
.\gradlew clean assembleDebug
```

### Kotlin Compiler Errors
- Read the full error message — it includes file path and line number.
- Common causes: missing imports, type mismatches, nullable access without safety.
- For Compose errors: ensure `@Composable` annotations are correct, check
  `Modifier` parameter placement.

### Hilt Errors
- Missing `@HiltAndroidApp` on Application class.
- Missing `@AndroidEntryPoint` on Activity/Fragment.
- Missing `@Inject constructor` on classes Hilt should create.
- Module not installed in correct component (`@InstallIn`).

## Network Debugging

### OkHttp Logging Interceptor
```kotlin
// Already in debug builds via NetworkModule
val client = OkHttpClient.Builder()
    .addInterceptor(HttpLoggingInterceptor().apply {
        level = if (BuildConfig.DEBUG)
            HttpLoggingInterceptor.Level.BODY
        else
            HttpLoggingInterceptor.Level.NONE
    })
    .build()
```

### Charles Proxy / HTTP Toolkit
```powershell
# Set proxy on emulator
adb shell settings put global http_proxy <host-ip>:8888

# Clear proxy
adb shell settings put global http_proxy :0
```

### Check Network Connectivity
```powershell
adb shell ping -c 3 google.com
adb shell curl -I https://api.example.com/health
```

## Memory and Performance

### Memory Info
```powershell
adb shell dumpsys meminfo com.example.app
```

### StrictMode (add to Application.onCreate for debug)
```kotlin
if (BuildConfig.DEBUG) {
    StrictMode.setThreadPolicy(
        StrictMode.ThreadPolicy.Builder()
            .detectAll()
            .penaltyLog()
            .build()
    )
    StrictMode.setVmPolicy(
        StrictMode.VmPolicy.Builder()
            .detectAll()
            .penaltyLog()
            .build()
    )
}
```

### ANR Detection
```powershell
# Check for ANR traces
adb shell cat /data/anr/traces.txt
# Or
adb bugreport bugreport.zip
```

## Database Inspection

### Room Database via ADB
```powershell
# Find the database file
adb shell run-as com.example.app ls databases/

# Copy database to local machine
adb exec-out run-as com.example.app cat databases/app.db > app.db
# Open with SQLite browser or sqlite3

# Use App Inspection in Android Studio for live DB viewing
```

## Compose-Specific Debugging

### Recomposition Tracking
```kotlin
// In debug builds, wrap composables to log recompositions
@Composable
fun DebugRecomposition(tag: String, content: @Composable () -> Unit) {
    if (BuildConfig.DEBUG) {
        val count = remember { mutableIntStateOf(0) }
        SideEffect { count.intValue++; Log.d("Recompose", "$tag: ${count.intValue}") }
    }
    content()
}
```

### Layout Inspector for Compose
Use Android Studio's Layout Inspector — it shows the Compose tree, recomposition
counts, and state values for Compose UIs.

## Debugging Workflow

1. **Reproduce the issue** — get exact steps.
2. **Check logcat** for errors and stack traces.
3. **Inspect UI** with `android layout` or `android screen capture`.
4. **Check state** — add logging at key state changes.
5. **Isolate** — narrow down to the specific component/function.
6. **Fix and verify** — rebuild and confirm the fix.
7. **Never assume** — always verify with actual output.
