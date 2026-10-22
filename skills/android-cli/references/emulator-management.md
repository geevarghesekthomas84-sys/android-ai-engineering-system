# Android Emulator Management

## Using Android CLI

### Create an Emulator
```powershell
android emulator create
```
Interactive â€” prompts for device profile, system image, and name.

### List Emulators
```powershell
android emulator list
```

### Start an Emulator
```powershell
android emulator start <name>
```
Blocks until the emulator is fully booted and ready.

### Stop an Emulator
```powershell
android emulator stop <name>
```

### Delete an Emulator
```powershell
android emulator remove <name>
```

## Using SDK Tools Directly

When the `android` CLI is not available, use the SDK tools:

### avdmanager
```powershell
$avdmanager = "${ANDROID_HOME}\cmdline-tools\latest\bin\avdmanager.bat"

# List available device definitions
& $avdmanager list device

# List existing AVDs
& $avdmanager list avd

# Create an AVD
& $avdmanager create avd -n "Pixel_8_API_36" -k "system-images;android-36.1;google_apis_playstore;x86_64" -d "pixel_8"

# Delete an AVD
& $avdmanager delete avd -n "Pixel_8_API_36"
```

### emulator
```powershell
$emulator = "${ANDROID_HOME}\emulator\emulator.exe"

# List available AVDs
& $emulator -list-avds

# Start emulator
& $emulator -avd "Pixel_8_API_36"

# Start headless (no GUI window â€” useful for CI)
& $emulator -avd "Pixel_8_API_36" -no-window -no-audio

# Start with custom memory
& $emulator -avd "Pixel_8_API_36" -memory 4096

# Wipe data on start
& $emulator -avd "Pixel_8_API_36" -wipe-data
```

## System Image Management

### Install System Images
```powershell
android sdk install "system-images;android-36.1;google_apis_playstore;x86_64"
```

Or via sdkmanager:
```powershell
$sdkmanager = "${ANDROID_HOME}\cmdline-tools\latest\bin\sdkmanager.bat"
& $sdkmanager "system-images;android-36.1;google_apis_playstore;x86_64"
```

### List Available Images
```powershell
android sdk list --all | findstr "system-images"
```

## Common Emulator Configurations

| Use Case | Device | System Image | Notes |
|----------|--------|-------------|-------|
| Modern phone testing | pixel_8 | android-36.1/google_apis_playstore/x86_64 | Play Store included |
| Tablet testing | pixel_tablet | android-35/google_apis/x86_64 | Large screen |
| Low-end device | pixel_4a | android-30/google_apis/x86_64 | Lower API for compat |
| Wear OS | wearos_large_round | android-34/android-wear/x86_64 | Watch testing |

## Waiting for Boot

After starting an emulator, wait for it to be ready:
```powershell
# Wait for device to come online
adb wait-for-device

# Wait for boot to complete
adb shell "while [[ `getprop sys.boot_completed` != '1' ]]; do sleep 1; done"
```

The `android emulator start` command handles this automatically.

## Emulator Performance Tips

1. **Use x86_64 images** for best performance on Intel/AMD hosts.
2. **Enable hardware acceleration**: Intel HAXM or Windows Hypervisor Platform.
3. **Allocate sufficient RAM**: At least 2GB for the emulator.
4. **Use snapshots**: Quick boot saves and restores emulator state.
5. **Cold boot only when needed**: `& $emulator -avd <name> -no-snapshot-load`
6. **Headless mode for CI**: `-no-window -no-audio -no-boot-anim`

## Hardware Acceleration Check

```powershell
$emulator = "${ANDROID_HOME}\emulator\emulator.exe"
& $emulator -accel-check
```

Ensure Windows Hypervisor Platform is enabled:
- Settings â†’ Apps â†’ Optional Features â†’ More Windows Features
- Enable "Windows Hypervisor Platform"
- Reboot

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Emulator won't start | Check `& $emulator -accel-check` for acceleration issues |
| Very slow | Enable WHPX/HAXM, use x86_64 images, allocate more RAM |
| Black screen | Try `-gpu swiftshader_indirect` or `-gpu host` |
| No network | Check host firewall, try `-dns-server 8.8.8.8` |
| Crashes on start | Wipe data: `& $emulator -avd <name> -wipe-data` |
| Out of storage | Increase disk size in AVD config or create new AVD |
