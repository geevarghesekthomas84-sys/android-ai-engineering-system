# ADB & Device Management

## ADB Path Resolution

ADB may be available at multiple locations. Check in order:
1. `adb` (if in PATH)
2. `$env:ANDROID_HOME\platform-tools\adb.exe`
3. `${ANDROID_HOME}\platform-tools\adb.exe`
4. `${ANDROID_HOME}/platform-tools\adb.exe`

## Device Connection

### List Connected Devices
```powershell
adb devices -l
```
Output format: `<serial> <state> [usb:<port>] [product:<name>] [model:<name>]`

States: `device` (ready), `offline`, `unauthorized`, `no permissions`

### USB Debugging Setup (Physical Devices)
1. Enable Developer Options: Settings â†’ About Phone â†’ tap Build Number 7 times.
2. Enable USB Debugging in Developer Options.
3. Connect via USB. Accept the RSA key fingerprint dialog on the device.
4. Verify with `adb devices`.

### Wireless Debugging (Android 11+)
```powershell
# Pair first (one-time per device)
adb pair <device-ip>:<pairing-port>  # Enter pairing code from device

# Connect
adb connect <device-ip>:<port>

# Disconnect
adb disconnect <device-ip>:<port>
```

### Multiple Devices
```powershell
# Target a specific device
adb -s <serial> shell ...
adb -s emulator-5554 install app.apk

# Target the only USB device
adb -d shell ...

# Target the only emulator
adb -e shell ...
```

## App Management

### Install / Uninstall
```powershell
adb install -r app.apk              # Install (replace existing)
adb install -t app.apk              # Allow test APK
adb install-multiple base.apk split.apk  # Split APKs
adb uninstall com.example.app       # Uninstall
adb uninstall -k com.example.app    # Keep data
```

### App Launch and Control
```powershell
# Start activity
adb shell am start -n com.example.app/.MainActivity

# Start with intent extras
adb shell am start -n com.example.app/.MainActivity -e key value

# Force stop
adb shell am force-stop com.example.app

# Clear app data
adb shell pm clear com.example.app

# List packages
adb shell pm list packages                    # All
adb shell pm list packages -3                 # Third-party only
adb shell pm list packages | findstr example  # Filter (Windows)
```

### App Info
```powershell
adb shell dumpsys package com.example.app     # Full package info
adb shell dumpsys activity top                # Current foreground activity
adb shell dumpsys meminfo com.example.app     # Memory usage
```

## Logcat

### Basic Usage
```powershell
adb logcat                          # All logs (very verbose)
adb logcat -v time *:W              # Warnings and errors with timestamps
adb logcat -v time -s "MyApp"       # Filter by tag
adb logcat -v threadtime *:E        # Errors only with thread info
adb logcat --pid=<pid>              # Filter by process ID
adb logcat -c                       # Clear log buffer
```

### Useful Filters
```powershell
# App crashes
adb logcat -v time *:E | findstr "FATAL\|AndroidRuntime\|CRASH"

# Specific tag at debug level, suppress everything else
adb logcat MyTag:D *:S

# Write to file
adb logcat -v time -f /sdcard/log.txt
```

## File Transfer

```powershell
adb push local-file.txt /sdcard/Download/      # Local â†’ device
adb pull /sdcard/Download/file.txt ./           # Device â†’ local
adb shell ls /sdcard/                           # List files
```

## Device Info

```powershell
adb shell getprop ro.build.version.sdk          # API level
adb shell getprop ro.build.version.release       # Android version
adb shell getprop ro.product.model               # Device model
adb shell getprop ro.product.manufacturer        # Manufacturer
adb shell wm size                                # Screen resolution
adb shell wm density                             # Screen density
adb shell cat /proc/meminfo                      # Memory info
adb shell df -h                                  # Storage info
```

## Input Simulation

```powershell
adb shell input tap <x> <y>                      # Tap
adb shell input swipe <x1> <y1> <x2> <y2> <ms>  # Swipe
adb shell input text "Hello%sWorld"              # Type text (%s = space)
adb shell input keyevent 66                      # Enter
adb shell input keyevent 4                       # Back
adb shell input keyevent 3                       # Home
adb shell input keyevent 187                     # Recent apps
adb shell input keyevent 26                      # Power
adb shell input keyevent 24                      # Volume up
adb shell input keyevent 25                      # Volume down
```

## Screenshots and Screen Recording

```powershell
# Screenshot via ADB
adb exec-out screencap -p > screenshot.png

# Screen recording (max 180 seconds)
adb shell screenrecord /sdcard/recording.mp4
adb shell screenrecord --time-limit 30 /sdcard/recording.mp4
# Press Ctrl+C to stop, then pull the file
adb pull /sdcard/recording.mp4

# Prefer android screen capture for screenshots (better quality, annotations)
android screen capture -o screenshot.png
```

## Port Forwarding

```powershell
adb forward tcp:8080 tcp:8080        # Forward local 8080 to device 8080
adb forward --list                   # List all forwards
adb forward --remove tcp:8080        # Remove a forward
adb reverse tcp:8080 tcp:8080        # Device â†’ local (reverse)
```

## Troubleshooting ADB

| Problem | Solution |
|---------|----------|
| Device shows `unauthorized` | Revoke USB debugging authorizations on device, reconnect, accept dialog |
| Device not found | Restart ADB server: `adb kill-server; adb start-server` |
| Multiple devices error | Specify device: `adb -s <serial> ...` |
| Slow transfer | Use `--use-delta-install` via android CLI |
| Permission denied | Check USB debugging is enabled, try different USB port/cable |
