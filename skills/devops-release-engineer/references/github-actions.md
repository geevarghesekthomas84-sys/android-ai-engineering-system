# GitHub Actions for Android CI/CD

## Complete Android CI Workflow

`.github/workflows/android-ci.yml`:

```yaml
name: Android CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
  checks: write

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4
        with:
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew

      - name: Build debug APK
        run: ./gradlew assembleDebug --no-daemon

      - name: Run unit tests
        run: ./gradlew testDebugUnitTest --no-daemon

      - name: Run lint
        run: ./gradlew lintDebug --no-daemon

      - name: Upload lint results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lint-results
          path: app/build/reports/lint-results-debug.html

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: app/build/reports/tests/testDebugUnitTest/

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk

  instrumented-tests:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    needs: build
    strategy:
      fail-fast: false
      matrix:
        api-level: [29, 33, 35]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm

      - name: AVD cache
        uses: actions/cache@v4
        id: avd-cache
        with:
          path: |
            ~/.android/avd/*
            ~/.android/adb*
          key: avd-${{ matrix.api-level }}

      - name: Create AVD and generate snapshot
        if: steps.avd-cache.outputs.cache-hit != 'true'
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: ${{ matrix.api-level }}
          arch: x86_64
          force-avd-creation: false
          emulator-options: -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim
          disable-animations: true
          script: echo "AVD snapshot generated"

      - name: Run instrumented tests
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: ${{ matrix.api-level }}
          arch: x86_64
          force-avd-creation: false
          emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim
          disable-animations: true
          script: ./gradlew connectedDebugAndroidTest --no-daemon

      - name: Upload instrumented test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: instrumented-test-results-api${{ matrix.api-level }}
          path: app/build/reports/androidTests/connected/
```

## Gradle Caching

The `gradle/actions/setup-gradle@v4` action handles caching automatically. For fine-grained control:

```yaml
- name: Cache Gradle packages
  uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
      build-cache
    key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties', '**/libs.versions.toml') }}
    restore-keys: |
      gradle-${{ runner.os }}-
```

To use a shared build cache across workflows:

```yaml
# In gradle.properties
org.gradle.caching=true

# In settings.gradle.kts
buildCache {
    local {
        directory = file("build-cache")
    }
}
```

## Release Workflow with Tag Triggers

`.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    environment: production
    timeout-minutes: 30

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v4

      - name: Decode keystore
        run: echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 --decode > app/release-keystore.jks

      - name: Build release AAB
        run: ./gradlew bundleRelease --no-daemon
        env:
          KEYSTORE_FILE: app/release-keystore.jks
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Build release APK
        run: ./gradlew assembleRelease --no-daemon
        env:
          KEYSTORE_FILE: app/release-keystore.jks
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Verify APK signature
        run: |
          BUILD_TOOLS=$(ls -d $ANDROID_HOME/build-tools/*/ | tail -1)
          ${BUILD_TOOLS}apksigner verify --verbose app/build/outputs/apk/release/app-release.apk

      - name: Upload AAB artifact
        uses: actions/upload-artifact@v4
        with:
          name: release-aab
          path: app/build/outputs/bundle/release/app-release.aab

      - name: Upload mapping file
        uses: actions/upload-artifact@v4
        with:
          name: mapping
          path: app/build/outputs/mapping/release/mapping.txt

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            app/build/outputs/apk/release/app-release.apk
            app/build/outputs/bundle/release/app-release.aab
          generate_release_notes: true

      - name: Upload to Play Console
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: internal
          mappingFile: app/build/outputs/mapping/release/mapping.txt
          status: completed
```

## Pull Request Workflow

`.github/workflows/pr-checks.yml`:

```yaml
name: PR Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  checks:
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - uses: gradle/actions/setup-gradle@v4

      - name: Build and test
        run: ./gradlew assembleDebug testDebugUnitTest lintDebug --no-daemon

      - name: Check APK size
        run: |
          APK_SIZE=$(stat -f%z app/build/outputs/apk/debug/app-debug.apk 2>/dev/null || stat --printf="%s" app/build/outputs/apk/debug/app-debug.apk)
          APK_SIZE_MB=$(echo "scale=2; $APK_SIZE / 1048576" | bc)
          echo "APK size: ${APK_SIZE_MB}MB"
          # Fail if APK exceeds 50MB
          if [ "$APK_SIZE" -gt 52428800 ]; then
            echo "::error::APK size ${APK_SIZE_MB}MB exceeds 50MB budget"
            exit 1
          fi

      - name: Publish test report
        if: always()
        uses: dorny/test-reporter@v1
        with:
          name: Unit Tests
          path: app/build/test-results/testDebugUnitTest/*.xml
          reporter: java-junit
```

## Branch Protection Rules

Configure via repository Settings > Branches > Branch protection rules:

For `main` branch:
- Require a pull request before merging (at least 1 approval)
- Require status checks to pass: `build`, `checks`
- Require branches to be up to date before merging
- Require conversation resolution before merging
- Do not allow bypassing the above settings

For `develop` branch:
- Require status checks to pass: `build`
- Require branches to be up to date before merging

## Workflow Optimization Tips

### Conditional job execution

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      src: ${{ steps.filter.outputs.src }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            src:
              - 'app/src/**'
              - '*.gradle.kts'
              - 'gradle/**'

  build:
    needs: changes
    if: needs.changes.outputs.src == 'true'
    runs-on: ubuntu-latest
    steps:
      # Only runs when source files changed
```

### Reusable workflows

Create `.github/workflows/reusable-build.yml`:

```yaml
name: Reusable Build

on:
  workflow_call:
    inputs:
      build-type:
        required: true
        type: string

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew assemble${{ inputs.build-type }} --no-daemon
```

Call it from another workflow:

```yaml
jobs:
  build-debug:
    uses: ./.github/workflows/reusable-build.yml
    with:
      build-type: Debug

  build-release:
    uses: ./.github/workflows/reusable-build.yml
    with:
      build-type: Release
    secrets: inherit
```

### Artifact retention

Control how long artifacts are kept:

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: debug-apk
    path: app/build/outputs/apk/debug/app-debug.apk
    retention-days: 7  # PR artifacts: 7 days
```

For release artifacts, use a longer retention or upload to a permanent store (GitHub Releases, Cloud Storage).
