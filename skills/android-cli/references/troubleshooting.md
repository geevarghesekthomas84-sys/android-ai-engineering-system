# Android Troubleshooting Guide

## Gradle Build Errors

### "SDK location not found"
```
Cause: ANDROID_HOME or sdk.dir not set.
Fix: Create/update local.properties in project root:
```
```properties
sdk.dir=${ANDROID_HOME}
```
Or set environment variable:
```powershell
$env:ANDROID_HOME = "${ANDROID_HOME}"
```

### "Failed to find Build Tools revision X.Y.Z"
```powershell
# Install the required build tools
android sdk install "build-tools;36.1.0"
# Or via sdkmanager
& "${ANDROID_HOME}\cmdline-tools\latest\bin\sdkmanager.bat" "build-tools;36.1.0"
```

### "Unsupported class file major version 65" (Java version mismatch)
```
Cause: Project requires a different JDK version than installed.
Fix: Set JAVA_HOME to the correct JDK, or configure in gradle.properties:
```
```properties
org.gradle.java.home=C:\\Program Files\\Java\\jdk-17
```

### "Could not resolve all files for configuration"
```powershell
# Clear Gradle caches
.\gradlew clean
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches\modules-2\files-2.1" -ErrorAction SilentlyContinue
.\gradlew assembleDebug --refresh-dependencies
```

### "Execution failed for task ':app:kspDebugKotlin'" (KSP/Hilt errors)
- Check that `@HiltAndroidApp` is on the Application class.
- Verify all `@Inject constructor` annotations are correct.
- Ensure `@Module` classes have `@InstallIn(...)`.
- Check KSP version matches Kotlin version.

### "Duplicate class" errors
```powershell
# Find the conflict
.\gradlew app:dependencies --configuration releaseRuntimeClasspath | findstr "duplicate-class-name"
# Exclude the transitive dependency
```
```kotlin
implementation("com.example:library:1.0") {
    exclude(group = "com.conflict", module = "module")
}
```

### Out of Memory during build
```properties
# gradle.properties â€” increase heap
org.gradle.jvmargs=-Xmx4096m -Dfile.encoding=UTF-8
```

### Configuration Cache problems
```powershell
.\gradlew assembleDebug --no-configuration-cache
# Or clean the cache
Remove-Item -Recurse -Force ".gradle\configuration-cache" -ErrorAction SilentlyContinue
```

## Kotlin Compilation Errors

### "Unresolved reference"
- Missing import statement.
- Dependency not added to `build.gradle.kts`.
- Wrong source set (test code referencing main code or vice versa).

### "Type mismatch: inferred type is X but Y was expected"
- Check nullability: `String` vs `String?`.
- Check generic types: `List<User>` vs `List<UserEntity>`.
- Ensure mapper functions return the correct type.

### "@Composable invocations can only happen from the context of a @Composable function"
- The calling function is missing `@Composable` annotation.
- You're trying to call a Composable from a lambda that isn't marked composable.

### "None of the following functions can be called with the arguments supplied"
- Check parameter types match exactly.
- Check for overloaded functions â€” you may be calling the wrong one.
- Common with Modifier chains: ensure correct receiver type.

## Compose Errors

### "IllegalStateException: ViewTreeLifecycleOwner not found"
```kotlin
// setContent must be called from ComponentActivity
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { /* ... */ }
    }
}
```

### "java.lang.IllegalStateException: LifecycleOwner is not ready"
- Avoid calling `hiltViewModel()` outside a composable that's inside a
  `NavHost` or `@AndroidEntryPoint` Activity.

### Preview Not Rendering
- Add `@Preview` annotation.
- Ensure the composable has default parameter values or create a wrapper.
- Check that preview functions don't depend on ViewModels or Hilt injection.
```kotlin
@Preview(showBackground = true)
@Composable
fun UserCardPreview() {
    AppTheme {
        UserCard(user = User("1", "Alice", "alice@example.com"), onClick = {})
    }
}
```

## Device / ADB Errors

### "error: device unauthorized"
1. On the device: Settings â†’ Developer Options â†’ Revoke USB debugging authorizations.
2. Disconnect and reconnect USB.
3. Accept the RSA key dialog that appears.

### "error: more than one device/emulator"
```powershell
adb devices  # Find the serial
adb -s <serial> install app.apk
```

### "INSTALL_FAILED_UPDATE_INCOMPATIBLE"
```powershell
adb uninstall com.example.app
adb install app.apk
```
The existing app was signed with a different key.

### "INSTALL_FAILED_INSUFFICIENT_STORAGE"
```powershell
# Clear device storage
adb shell pm clear com.example.app
# Or free space
adb shell rm -rf /sdcard/Download/*
```

### Device Not Detected
1. Check USB cable (use a data cable, not charge-only).
2. Try a different USB port.
3. Install device manufacturer USB drivers.
4. Restart ADB:
```powershell
adb kill-server
adb start-server
adb devices
```

### Emulator Won't Start
```powershell
# Check acceleration
& "${ANDROID_HOME}\emulator\emulator.exe" -accel-check

# Try with software rendering
& "${ANDROID_HOME}\emulator\emulator.exe" -avd <name> -gpu swiftshader_indirect

# Wipe emulator data
& "${ANDROID_HOME}\emulator\emulator.exe" -avd <name> -wipe-data
```

## Runtime Errors

### "NetworkOnMainThreadException"
All network calls must be on a background thread/coroutine:
```kotlin
viewModelScope.launch(Dispatchers.IO) {
    val result = api.fetchData()
    // ...
}
```

### "android.os.FileUriExposedException"
Use `FileProvider` instead of `file://` URIs:
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

### "SecurityException: Permission Denial"
- Check that the required permission is in AndroidManifest.xml.
- For dangerous permissions (camera, location, etc.), request at runtime:
```kotlin
val launcher = rememberLauncherForActivityResult(
    ActivityResultContracts.RequestPermission()
) { granted -> if (granted) { /* proceed */ } }
launcher.launch(Manifest.permission.CAMERA)
```

## Environment Setup Issues

### JAVA_HOME Not Set
```powershell
# Find Java installation
Get-ChildItem "C:\Program Files\Java" -Directory
Get-ChildItem "C:\Program Files\Common Files\Oracle\Java\javapath" -File

# Set for current session
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"

# Verify
java -version
```

### Android CLI Not in PATH
```powershell
# Reinstall
$installCmd = "$env:TEMP\android-cli-install.cmd"
Invoke-WebRequest -Uri "https://dl.google.com/android/cli/latest/windows_x86_64/install.cmd" -OutFile $installCmd
& cmd.exe /c $installCmd
# Restart terminal after installation
```

### Gradle Wrapper Missing
```powershell
# If gradlew.bat is missing from a project, generate it:
# (Requires Gradle installed or use the android create command for new projects)
android create empty-activity --name="Temp" --output=./temp-project
# Copy gradlew, gradlew.bat, and gradle/ directory from temp to your project
```

## Debugging Approach

1. **Read the full error message** â€” don't skim. The answer is usually there.
2. **Check the build output** â€” `.\gradlew assembleDebug --stacktrace`
3. **Check logcat** â€” `adb logcat *:E` for runtime crashes.
4. **Search Android docs** â€” `android docs search "error message keywords"`
5. **Check dependency tree** â€” `.\gradlew app:dependencies`
6. **Clean and rebuild** â€” `.\gradlew clean assembleDebug`
7. **Invalidate caches** â€” Delete `.gradle/` and `build/` directories.
8. **Check environment** â€” Run `check-environment.ps1` script.
