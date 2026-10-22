# Screenshot Regression Testing

## Compose Preview Screenshot Testing

The official Gradle plugin captures screenshots from `@Preview` composables without a device.

### Setup

```kotlin
// build.gradle.kts (module-level)
plugins {
    id("com.android.application") // or com.android.library
    id("com.android.compose.screenshot") version "0.0.1-alpha09"
}

android {
    experimentalProperties["android.experimental.enableScreenshotTest"] = true
}

dependencies {
    screenshotTestImplementation("androidx.compose.ui:ui-tooling")
}
```

### Writing Preview Screenshot Tests

Create files in `src/screenshotTest/kotlin/`:

```kotlin
package com.example.app.screenshots

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.example.app.ui.theme.AppTheme

class ButtonScreenshots {

    @Preview(showBackground = true)
    @Composable
    fun PrimaryButton_Default() {
        AppTheme {
            PrimaryButton(text = "Submit", onClick = {})
        }
    }

    @Preview(showBackground = true, uiMode = Configuration.UI_MODE_NIGHT_YES)
    @Composable
    fun PrimaryButton_DarkTheme() {
        AppTheme(darkTheme = true) {
            PrimaryButton(text = "Submit", onClick = {})
        }
    }

    @Preview(showBackground = true, fontScale = 1.5f)
    @Composable
    fun PrimaryButton_LargeFont() {
        AppTheme {
            PrimaryButton(text = "Submit", onClick = {})
        }
    }

    @Preview(showBackground = true, locale = "ar")
    @Composable
    fun PrimaryButton_RTL() {
        AppTheme {
            PrimaryButton(text = "Submit", onClick = {})
        }
    }
}
```

### Running

```bash
# Generate golden images (reference screenshots)
./gradlew updateDebugScreenshotTest

# Verify current UI matches golden images
./gradlew validateDebugScreenshotTest
```

Golden images are stored in `src/screenshotTest/reference/` and should be committed to version control.

## Roborazzi

Roborazzi runs screenshot tests on JVM using Robolectric—no device or emulator needed. Fast CI execution.

### Setup

```kotlin
// build.gradle.kts (project-level)
plugins {
    id("io.github.takahirom.roborazzi") version "1.40.0" apply false
}

// build.gradle.kts (module-level)
plugins {
    id("io.github.takahirom.roborazzi")
}

dependencies {
    testImplementation("io.github.takahirom.roborazzi:roborazzi:1.40.0")
    testImplementation("io.github.takahirom.roborazzi:roborazzi-compose:1.40.0")
    testImplementation("io.github.takahirom.roborazzi:roborazzi-junit-rule:1.40.0")
    testImplementation("org.robolectric:robolectric:4.14.1")
}

android {
    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}
```

### Roborazzi Compose Tests

```kotlin
import com.github.takahirom.roborazzi.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class LoginScreenRoborazziTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @get:Rule
    val roborazziRule = RoborazziRule(
        composeRule = composeTestRule,
        captureRoot = composeTestRule.onRoot(),
        options = RoborazziRule.Options(
            captureType = RoborazziRule.CaptureType.LastImage(),
            outputDirectoryPath = "src/test/screenshots",
            roborazziOptions = RoborazziOptions(
                compareOptions = RoborazziOptions.CompareOptions(
                    changeThreshold = 0.01 // 1% pixel difference tolerance
                ),
                recordOptions = RoborazziOptions.RecordOptions(
                    resizeScale = 0.5 // reduce golden image size
                )
            )
        )
    )

    @Test
    fun loginScreen_idle() {
        composeTestRule.setContent {
            AppTheme {
                LoginScreen(uiState = LoginUiState.Idle)
            }
        }

        composeTestRule.onRoot().captureRoboImage()
    }

    @Test
    fun loginScreen_loading() {
        composeTestRule.setContent {
            AppTheme {
                LoginScreen(uiState = LoginUiState.Loading)
            }
        }

        composeTestRule.onRoot().captureRoboImage()
    }

    @Test
    fun loginScreen_error() {
        composeTestRule.setContent {
            AppTheme {
                LoginScreen(uiState = LoginUiState.Error("Invalid credentials"))
            }
        }

        composeTestRule.onRoot().captureRoboImage()
    }
}
```

### Capturing Specific Nodes

```kotlin
@Test
fun customButton_states() {
    composeTestRule.setContent {
        AppTheme {
            Column {
                PrimaryButton(text = "Enabled", enabled = true, onClick = {})
                PrimaryButton(text = "Disabled", enabled = false, onClick = {})
            }
        }
    }

    // Capture the entire column
    composeTestRule.onNodeWithTag("button_column").captureRoboImage(
        filePath = "src/test/screenshots/button_states.png"
    )
}
```

### Running Roborazzi

```bash
# Record golden images (overwrites existing)
./gradlew recordRoborazziDebug

# Verify current output against golden images
./gradlew verifyRoborazziDebug

# Compare and generate diff images (does not fail)
./gradlew compareRoborazziDebug
```

Diff images are generated at `build/outputs/roborazzi/` showing pixel differences highlighted in red.

## Testing Themes and Configurations

### Multi-Theme Screenshot Matrix

```kotlin
@RunWith(ParameterizedRobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class ThemeScreenshotTest(
    private val darkTheme: Boolean,
    private val fontScale: Float,
    private val description: String,
) {
    @get:Rule
    val composeTestRule = createComposeRule()

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{2}")
        fun params() = listOf(
            arrayOf(false, 1.0f, "light_normal"),
            arrayOf(true, 1.0f, "dark_normal"),
            arrayOf(false, 1.5f, "light_large"),
            arrayOf(true, 1.5f, "dark_large"),
            arrayOf(false, 2.0f, "light_xlarge"),
        )
    }

    @Test
    fun settingsScreen() {
        composeTestRule.setContent {
            CompositionLocalProvider(
                LocalDensity provides Density(
                    density = LocalDensity.current.density,
                    fontScale = fontScale,
                )
            ) {
                AppTheme(darkTheme = darkTheme) {
                    SettingsScreen()
                }
            }
        }

        composeTestRule.onRoot().captureRoboImage(
            filePath = "src/test/screenshots/settings_$description.png"
        )
    }
}
```

## CI Integration

### GitHub Actions for Screenshot Tests

```yaml
- name: Record golden images (on main merge)
  if: github.ref == 'refs/heads/main'
  run: ./gradlew recordRoborazziDebug

- name: Verify screenshots (on PR)
  if: github.event_name == 'pull_request'
  run: ./gradlew verifyRoborazziDebug

- name: Upload diff images on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: screenshot-diffs
    path: "**/build/outputs/roborazzi/**/*_compare.png"
    retention-days: 7
```

## Organizing Golden Images

```
src/
  test/
    screenshots/           # Roborazzi golden images
      LoginScreen_idle.png
      LoginScreen_loading.png
      LoginScreen_error.png
      settings_light_normal.png
      settings_dark_normal.png
  screenshotTest/
    reference/             # Compose Preview Screenshot golden images
      ButtonScreenshots/
        PrimaryButton_Default.png
        PrimaryButton_DarkTheme.png
```

Commit golden images to version control. Use Git LFS if the repository grows large:

```bash
git lfs track "*.png" --filename
git lfs track "src/test/screenshots/**" --filename
```

## Updating Baselines

When intentional UI changes are made:

```bash
# Roborazzi: re-record all golden images
./gradlew recordRoborazziDebug

# Compose Preview: re-record all golden images
./gradlew updateDebugScreenshotTest

# Review diffs before committing
git diff --stat
git diff --name-only
```

Review each changed image visually before committing. Never blindly overwrite goldens.
