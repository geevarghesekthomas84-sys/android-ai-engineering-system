---
name: android-cli
description: >
  Comprehensive Android development skill for Claude Code. Provides expert-level
  instructions for the Google Android CLI, Kotlin/Jetpack Compose development,
  Gradle builds, ADB device management, emulator control, security engineering
  (OWASP MASVS), testing (JUnit/Espresso/Compose), performance optimization,
  and end-to-end autonomous app development workflows. Covers project creation
  through production APK/AAB generation.
license: Complete terms in LICENSE.txt
metadata:
  author: Google LLC (base), enhanced by user
  version: 3.0.0
  keywords:
    - android-cli
    - kotlin
    - jetpack-compose
    - material3
    - gradle
    - adb
    - emulator
    - sdk
    - security
    - testing
    - mvvm
    - hilt
    - room
    - retrofit
    - ci-cd
---

# Android Development Specialist

Expert-level Android development skill for Claude Code. Autonomously plans,
develops, builds, tests, debugs, optimizes, and maintains Android applications
using Kotlin, Jetpack Compose, and Material Design 3.

## Environment Detection

Before any Android task, detect the available tools. Run the environment check
script if uncertain:

```powershell
& "$HOME/.claude/skills/android-cli\scripts\check-environment.ps1"
```

### Known Environment Paths (Windows)

| Tool | Path |
|------|------|
| Android CLI | `${ANDROID_CLI_HOME}/android.exe` |
| Android SDK | `${ANDROID_HOME}` |
| Android CLI data | `$HOME/.android/cli` |
| ADB | SDK `platform-tools\adb.exe` |
| sdkmanager | SDK `cmdline-tools\latest\bin\sdkmanager.bat` |
| avdmanager | SDK `cmdline-tools\latest\bin\avdmanager.bat` |
| Emulator | SDK `emulator\emulator.exe` |
| Build tools | SDK `build-tools\{version}\` |
| Android Studio | `C:\Program Files\Android\Android Studio` |
| JDK 21 | `C:\Program Files\Java\jdk-21.0.12` |

If `ANDROID_HOME` or `JAVA_HOME` are not set, use full paths or set them in
the current session:

```powershell
$env:ANDROID_HOME = "${ANDROID_HOME}"
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21.0.12"
$env:PATH = "${ANDROID_CLI_HOME};$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\emulator;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:PATH"
```

### Android CLI Installation

If the `android` command is not in PATH, install or reinstall:

```
curl -fsSL https://dl.google.com/android/cli/latest/windows_x86_64/install.cmd -o "%TEMP%\i.cmd" && "%TEMP%\i.cmd"
```

After installation, restart the shell or add the install directory to PATH.

## Core Capabilities

### 1. Android CLI Commands
See [references/android-cli-commands.md](references/android-cli-commands.md)
for the complete command reference including `create`, `run`, `install`,
`layout`, `screen`, `sdk`, `emulator`, `docs`, `studio`, `input`, and more.

### 2. Kotlin & Jetpack Compose Development
See [references/kotlin-development.md](references/kotlin-development.md) and
[references/jetpack-compose.md](references/jetpack-compose.md) for patterns,
architecture, and Material 3 implementation.

### 3. Architecture & Dependency Injection
See [references/android-architecture.md](references/android-architecture.md)
for MVVM, Clean Architecture, Hilt, Navigation Compose, Room, Retrofit, and
state management patterns.

### 4. Gradle Build System
See [references/gradle-builds.md](references/gradle-builds.md) for build
configuration, variants, signing, dependency management, and AGP setup.

### 5. Device & Emulator Management
See [references/adb-device-management.md](references/adb-device-management.md)
and [references/emulator-management.md](references/emulator-management.md).

### 6. Debugging
See [references/debugging.md](references/debugging.md) for logcat, crash
analysis, layout inspection, and network debugging.

### 7. Security Engineering
See [references/android-security.md](references/android-security.md) for
OWASP MASVS compliance, secure storage, network security, and authorized
security testing.

### 8. Testing & QA
See [references/testing.md](references/testing.md) for JUnit, Compose UI
testing, Espresso, and CI/CD integration.

### 9. Performance
See [references/performance.md](references/performance.md) for profiling,
memory optimization, and startup performance.

### 10. Troubleshooting
See [references/troubleshooting.md](references/troubleshooting.md) for common
errors and their solutions.

## Autonomous Development Workflow

When asked to build an Android application, follow this workflow:

### Step 1 â€” Understand Requirements
- Clarify app purpose, target API levels, and required features.
- Identify UI complexity (single screen vs multi-screen navigation).
- Determine data sources (local DB, REST API, both).
- Note any security or compliance requirements.

### Step 2 â€” Plan Architecture
- Choose architecture pattern (default: MVVM with Clean Architecture layers).
- Identify modules: `app`, `data`, `domain` for larger apps.
- Plan navigation graph.
- Select dependencies (Hilt, Room, Retrofit as needed).
- Document the plan before writing code.

### Step 3 â€” Create Project
Use `android create` for template-based projects:
```
android create empty-activity --name="App Name" --namespace=com.example.app --output=./app-name
```

Or create manually with proper Gradle structure when templates don't fit.

### Step 4 â€” Implement
- Write Kotlin code following the architecture plan.
- Build Compose UI with Material 3 theming.
- Implement navigation, state management, data layers.
- Follow the coding standards in the reference docs.

### Step 5 â€” Build
```powershell
# From project root
.\gradlew assembleDebug
```
Or use the build script:
```powershell
& "$HOME/.claude/skills/android-cli\scripts\build-debug.ps1" -ProjectPath ".\app-name"
```

### Step 6 â€” Diagnose Errors
- Read Gradle output carefully. Do not claim success without clean output.
- For common errors, consult [references/troubleshooting.md](references/troubleshooting.md).
- Fix dependency conflicts, API incompatibilities, and Kotlin errors iteratively.

### Step 7 â€” Deploy & Test
```powershell
# Install and run on connected device/emulator
android run --apks=app/build/outputs/apk/debug/app-debug.apk
# Or via ADB
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.app/.MainActivity
```

### Step 8 â€” Automated Testing
```powershell
.\gradlew test              # Unit tests
.\gradlew connectedCheck    # Instrumentation tests (requires device)
```
Or use: `& "$HOME/.claude/skills/android-cli\scripts\run-tests.ps1" -ProjectPath ".\app-name"`

### Step 9 â€” Security Review
- Review AndroidManifest.xml for exported components and permissions.
- Check for hardcoded secrets, insecure storage, missing network security config.
- Run lint: `.\gradlew lint`

### Step 10 â€” Release Build
```powershell
.\gradlew assembleRelease   # APK
.\gradlew bundleRelease     # AAB for Play Store
```
Signing configuration must be set up in `build.gradle.kts` first.

## Critical Rules

1. **Never claim success without execution results.** Always show actual build
   output, test results, or error messages.
2. **Never invent Android CLI commands.** Only use commands documented in the
   `android --help` output. When the CLI lacks a feature, use Gradle, ADB, or
   SDK tools instead.
3. **Never weaken security for convenience.** Do not disable TLS validation,
   export components unnecessarily, or store secrets in plaintext.
4. **Never delete projects, reset devices, overwrite signing keys, or publish
   apps without explicit user approval.**
5. **Inspect before modifying.** Read existing project files, `build.gradle.kts`,
   and `AndroidManifest.xml` before making changes.
6. **Use actual installed tools.** Detect what's available and use full paths
   when tools aren't in PATH.
7. **Prefer Gradle wrapper (`gradlew`/`gradlew.bat`)** over system Gradle.
8. **Use `android docs search`** to look up current Android API documentation
   when uncertain about API usage.

## Quick Reference â€” Common Tasks

| Task | Command |
|------|---------|
| Create project | `android create empty-activity --name="MyApp" --output=./my-app` |
| List templates | `android create --list` |
| Build debug APK | `.\gradlew assembleDebug` |
| Build release AAB | `.\gradlew bundleRelease` |
| Install APK | `android install --apks=path/to/app.apk` |
| Run app | `android run --apks=path/to/app.apk` |
| List devices | `adb devices` |
| Screenshot | `android screen capture -o screenshot.png` |
| UI layout dump | `android layout -p` |
| Search docs | `android docs search "jetpack compose"` |
| Install SDK pkg | `android sdk install platforms/android-35` |
| List SDK pkgs | `android sdk list --all` |
| Create emulator | `android emulator create` |
| Start emulator | `android emulator start <name>` |
| Run unit tests | `.\gradlew test` |
| Run lint | `.\gradlew lint` |
| Check environment | `android info` |
| Logcat | `adb logcat -v time *:W` |
| Describe project | `android describe --project_dir=./my-app` |

## PowerShell Automation Scripts

Located in `scripts/`:
- **check-environment.ps1** â€” Detects installed Android tools and reports status.
- **build-debug.ps1** â€” Builds a debug APK with error handling.
- **run-tests.ps1** â€” Runs unit and instrumentation tests.
- **inspect-device.ps1** â€” Reports connected device status and properties.

## Cross-Skill Orchestration

This skill is the entry point for Android development. For specialized tasks,
identify and load the appropriate specialized skill:

| Task Domain | Skill | When to Use |
|-------------|-------|-------------|
| UI/UX Design | `android-ui-ux-design` | Premium design systems, Material 3 theming, responsive layouts, motion, design-to-code |
| Frontend Engineering | `android-frontend-engineer` | Compose architecture, Navigation3, MVVM/MVI, Hilt DI, coroutines, networking |
| Backend APIs | `backend-api-engineer` | REST APIs, NestJS/FastAPI, authentication, PostgreSQL, Docker |
| Database & Offline | `database-offline-sync` | Room, DataStore, migrations, offline-first, sync, conflict resolution |
| Security | `android-security-engineer` | OWASP MASVS, threat modeling, secure storage, network security, auth security |
| Security Labs | `android-security-lab-builder` | Intentionally vulnerable apps, CTF challenges, security training |
| Testing & QA | `android-testing-engineer` | JUnit, Compose tests, Espresso, screenshot testing, CI automation |
| Performance | `app-performance-engineer` | Startup optimization, Compose perf, memory, APK size, benchmarking |
| DevOps & Release | `devops-release-engineer` | CI/CD, signing, GitHub Actions, Docker, Play Console, monitoring |
| AI Integration | `ai-integration-engineer` | LLM APIs, chat UI, streaming, RAG, on-device ML, AI safety |
| Firebase/Supabase | `firebase-supabase-engineer` | Auth, Firestore, Realtime DB, Cloud Functions, Supabase |
| Web Companion | `fullstack-web-engineer` | React/Next.js dashboards, admin panels, web APIs |
| Product Architecture | `app-product-architect` | Requirements, system design, tech selection, project planning |

### Orchestration Workflow Example

For a complex request like "Build a premium cybersecurity Android app with
login, dashboard, backend, and database":

1. **app-product-architect** â€” Define requirements, architecture, data models
2. **android-ui-ux-design** â€” Create design system, screen layouts, theme
3. **android-frontend-engineer** â€” Implement Compose screens, navigation, state
4. **backend-api-engineer** â€” Build REST API, auth endpoints, Docker setup
5. **database-offline-sync** â€” Design schema, implement Room, sync strategy
6. **android-security-engineer** â€” Review auth, storage, network security
7. **android-testing-engineer** â€” Write tests, set up CI
8. **devops-release-engineer** â€” Configure builds, signing, deployment

Load skills as needed during the workflow. This skill handles the Android CLI
commands, project creation, building, and emulator management throughout.

## Example Projects

Located in `examples/`:
- **basic-compose-app/** â€” Minimal Jetpack Compose + Material 3 project scaffold.
- **secure-android-app/** â€” Security-hardened project with network security config,
  encrypted storage, and proper permission handling.
