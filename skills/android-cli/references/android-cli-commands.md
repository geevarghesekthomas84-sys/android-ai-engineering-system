# Android CLI Command Reference

Complete reference for Google Android CLI v1.0.16625370+.

## Global Options

```
android [-Vhv] [--sdk=PARAM] [COMMAND]
  -h, --help       Show help
  --sdk=PARAM      Path to the Android SDK
  -v, --verbose    Enable verbose output
  -V, --version    Print version
```

## Commands

### auth — Authentication

```
android auth login      # Log in to Google services
android auth logout     # Log out
android auth status     # Print current account
```

### create — Project Creation

```
android create <template> [OPTIONS]
  --name=PARAM            App name (e.g., "My App")
  --namespace=PARAM       Package namespace (e.g., com.example.app)
  --application-id=PARAM  App ID (e.g., com.example.myapp)
  --min-sdk=PARAM         Minimum SDK version
  -o, --output=PARAM      Output directory (default: .)
  --force                 Overwrite existing files
  --list                  List all available templates
```

Common templates:
- `empty-activity` — Blank Compose activity
- Use `android create --list` to see all available templates

### describe — Project Analysis

```
android describe [--project_dir=PARAM]
```

Outputs JSON metadata about project structure, build targets, and APK paths.

### device — Physical Device Management

```
android device remote list       # List remote devices
android device remote reserve    # Reserve a remote device
android device remote connect    # Connect to reserved device
```

### docs — Documentation Search

```
android docs search "query"      # Search Android Knowledge Base
android docs fetch "kb://url"    # Fetch a specific article
```

Always use this to look up current API information.

### emulator — AVD Management

```
android emulator create          # Create a new AVD (interactive)
android emulator list            # List available AVDs
android emulator start <name>    # Start an AVD (blocks until ready)
android emulator stop <name>     # Stop a running AVD
android emulator remove <name>   # Delete an AVD
```

### info — Environment Information

```
android info                     # Print all environment info
android info <field>             # Print specific field
```

### init — Environment Setup

```
android init                     # Initialize CLI environment
```

### input — Device Interaction

```
android input tap <selector>                    # Tap a UI element
android input text <selector> --text="text"     # Type text into element
android input scroll <selector> --direction=up  # Scroll a container
android input swipe <selector> --direction=left # Swipe on element
android input key <keycode>                     # Press a key
```

Selectors match UI elements by text, resource-id, or content-desc.

### install — APK Installation

```
android install --apks=path/to/app.apk [OPTIONS]
  --device=PARAM           Target device serial
  --install-options=PARAM  Extra pm install flags (e.g., -g, -d)
  --use-delta-install      Fast incremental install (default: true)
```

### layout — UI Tree Inspection

```
android layout [OPTIONS]
  --device=PARAM   Target device
  --flat           Flat list instead of tree
  --full           Include non-interactive/hidden elements
  --no-idle        Don't wait for layout idle
  -o, --output     Write to file
  -p, --pretty     Pretty-print JSON
```

Returns JSON with element properties: `text`, `resource-id`, `content-desc`,
`interactions`, `state`, `bounds`, `center`, `off-screen`, `hidden`.

### run — Deploy and Launch

```
android run [OPTIONS]
  --apks=PARAM             APK paths (comma-separated)
  --activity=PARAM         Activity to launch
  --debug                  Debug mode
  --device=PARAM           Target device
  --type=PARAM             Component type (ACTIVITY, WATCH_FACE, etc.)
  --use-delta-install      Fast incremental install
```

### screen — Screen Capture and Inspection

```
android screen capture -o <file.png>              # Screenshot
android screen capture --annotate -o <file.png>   # Annotated screenshot
android screen resolve --screenshot <path> --string "#3"  # Get coordinates
```

### sdk — SDK Package Management

```
android sdk install <package>[@<version>] ...    # Install packages
android sdk update [<package>]                   # Update packages
android sdk remove <package>                     # Remove a package
android sdk list --all                           # List all packages
```

Package format: `platforms/android-35`, `build-tools;36.0.0`, `system-images;android-35;google_apis;x86_64`

### skills — Skill Management

```
android skills list              # List installed skills
android skills find <keyword>    # Search for skills
android skills add <id>          # Install a skill
android skills remove <id>       # Remove a skill
android skills update            # Update all skills
```

### studio — Android Studio Integration

```
android studio check                             # Check Studio status
android studio analyze-file <path>               # Analyze a file
android studio find-declaration <symbol>          # Find declaration
android studio find-usages <symbol>              # Find usages
android studio open-file <path>                  # Open in Studio
android studio render-compose-preview <path>     # Render Compose preview
android studio version-lookup <artifact>         # Check latest versions
```

### update — CLI Update

```
android update                   # Update to latest version
```

## ADB Commands (Complement to Android CLI)

When the Android CLI doesn't cover a task, use ADB directly:

```powershell
adb devices                          # List connected devices
adb shell input tap <x> <y>         # Tap coordinates
adb shell input swipe <x1> <y1> <x2> <y2> <ms>  # Swipe
adb shell input text "text"          # Type text (use %s for spaces)
adb shell input keyevent <code>      # Key event (66=Enter, 4=Back)
adb shell am start -n <pkg>/<activity>  # Start activity
adb shell pm list packages           # List packages
adb install -r <apk>                 # Install APK
adb uninstall <pkg>                  # Uninstall app
adb logcat -v time *:W               # Logcat (warnings+)
adb shell dumpsys activity top       # Current activity info
adb shell getprop ro.build.version.sdk  # Device API level
adb forward tcp:<local> tcp:<remote> # Port forwarding
adb push <local> <remote>           # Push file to device
adb pull <remote> <local>           # Pull file from device
adb shell settings get secure android_id  # Device ID
```

## Device Interaction Workflow

1. Use `android layout -p` to get the UI tree.
2. Find the target element by `text`, `resource-id`, or `content-desc`.
3. Use the element's `center` coordinates with `adb shell input tap`.
4. For text input, ensure the field has `FOCUSED` state first.
5. If elements aren't found, try `android layout --full` or
   `android screen capture --annotate`.
6. After actions, wait briefly then re-check layout for state changes.
