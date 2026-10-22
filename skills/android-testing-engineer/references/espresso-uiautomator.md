# Espresso and UI Automator

## Espresso Dependencies

```kotlin
dependencies {
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.test.espresso:espresso-contrib:3.6.1")
    androidTestImplementation("androidx.test.espresso:espresso-intents:3.6.1")
    androidTestImplementation("androidx.test.espresso:espresso-idling-resource:3.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
}
```

## Espresso Basics

```kotlin
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.*
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.*
import androidx.test.ext.junit.rules.ActivityScenarioRule

class LoginActivityTest {

    @get:Rule
    val activityRule = ActivityScenarioRule(LoginActivity::class.java)

    @Test
    fun loginButton_isDisplayed() {
        onView(withId(R.id.btn_login))
            .check(matches(isDisplayed()))
    }

    @Test
    fun enterCredentials_andLogin() {
        onView(withId(R.id.et_email))
            .perform(typeText("user@example.com"), closeSoftKeyboard())

        onView(withId(R.id.et_password))
            .perform(typeText("secret123"), closeSoftKeyboard())

        onView(withId(R.id.btn_login))
            .perform(click())

        onView(withId(R.id.tv_welcome))
            .check(matches(withText("Welcome, user@example.com")))
    }

    @Test
    fun emptyEmail_showsError() {
        onView(withId(R.id.btn_login)).perform(click())

        onView(withId(R.id.til_email))
            .check(matches(hasDescendant(withText("Email is required"))))
    }
}
```

## View Matchers

```kotlin
// By ID
onView(withId(R.id.my_button))

// By text
onView(withText("Submit"))
onView(withText(R.string.submit_label))

// By hint
onView(withHint("Enter email"))

// By content description
onView(withContentDescription("Close dialog"))

// By class name
onView(withClassName(equalTo(EditText::class.java.name)))

// Combining matchers
onView(allOf(withId(R.id.tv_name), withText("Alice"), isDisplayed()))

// Negation
onView(allOf(withId(R.id.btn_submit), not(isEnabled())))

// Within a parent
onView(allOf(withText("Delete"), isDescendantOfA(withId(R.id.toolbar))))
```

## View Actions

```kotlin
// Click actions
perform(click())
perform(longClick())
perform(doubleClick())

// Text actions
perform(typeText("hello"))
perform(typeTextIntoFocusedView("hello"))
perform(replaceText("new text"))
perform(clearText())
perform(closeSoftKeyboard())
perform(pressImeActionButton())

// Scroll
perform(scrollTo()) // inside ScrollView/NestedScrollView

// Swipe
perform(swipeUp())
perform(swipeDown())
perform(swipeLeft())
perform(swipeRight())

// Press keys
perform(pressKey(KeyEvent.KEYCODE_ENTER))
perform(pressBack())
```

## RecyclerView Actions

```kotlin
import androidx.test.espresso.contrib.RecyclerViewActions

@Test
fun recyclerView_scrollToItemAndClick() {
    onView(withId(R.id.recycler_view))
        .perform(
            RecyclerViewActions.scrollToPosition<RecyclerView.ViewHolder>(15)
        )

    onView(withId(R.id.recycler_view))
        .perform(
            RecyclerViewActions.actionOnItemAtPosition<RecyclerView.ViewHolder>(
                15, click()
            )
        )
}

@Test
fun recyclerView_clickItemWithText() {
    onView(withId(R.id.recycler_view))
        .perform(
            RecyclerViewActions.actionOnItem<RecyclerView.ViewHolder>(
                hasDescendant(withText("Target Item")),
                click()
            )
        )
}
```

## Idling Resources

Espresso waits for the app to be idle before assertions. For async operations not on the main thread, register an IdlingResource.

```kotlin
// CountingIdlingResource — in production code
class DataRepository(private val idlingResource: CountingIdlingResource? = null) {

    suspend fun fetchData(): List<Item> {
        idlingResource?.increment()
        return try {
            api.getItems()
        } finally {
            idlingResource?.decrement()
        }
    }
}

// In test
class DataScreenTest {

    private val idlingResource = CountingIdlingResource("DataFetch")

    @Before
    fun setUp() {
        IdlingRegistry.getInstance().register(idlingResource)
    }

    @After
    fun tearDown() {
        IdlingRegistry.getInstance().unregister(idlingResource)
    }

    @Test
    fun dataLoads_andDisplays() {
        // Espresso waits until idlingResource count reaches 0
        onView(withId(R.id.tv_item_count))
            .check(matches(withText("10 items")))
    }
}
```

## Intent Verification

```kotlin
import androidx.test.espresso.intent.Intents
import androidx.test.espresso.intent.Intents.intended
import androidx.test.espresso.intent.matcher.IntentMatchers.*

class ShareFeatureTest {

    @get:Rule
    val activityRule = ActivityScenarioRule(ArticleActivity::class.java)

    @Before
    fun setUp() {
        Intents.init()
    }

    @After
    fun tearDown() {
        Intents.release()
    }

    @Test
    fun shareButton_firesShareIntent() {
        onView(withId(R.id.btn_share)).perform(click())

        intended(
            allOf(
                hasAction(Intent.ACTION_CHOOSER),
                hasExtra(
                    equalTo(Intent.EXTRA_INTENT),
                    allOf(
                        hasAction(Intent.ACTION_SEND),
                        hasType("text/plain")
                    )
                )
            )
        )
    }

    @Test
    fun stubExternalActivityResult() {
        val resultData = Intent().putExtra("selected_contact", "Alice")
        val result = Instrumentation.ActivityResult(Activity.RESULT_OK, resultData)

        Intents.intending(hasComponent("com.example.ContactPickerActivity"))
            .respondWith(result)

        onView(withId(R.id.btn_pick_contact)).perform(click())

        onView(withId(R.id.tv_contact)).check(matches(withText("Alice")))
    }
}
```

## UI Automator Dependencies

```kotlin
dependencies {
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
```

## UI Automator Basics

```kotlin
import androidx.test.uiautomator.*
import androidx.test.platform.app.InstrumentationRegistry

class CrossAppTest {

    private lateinit var device: UiDevice

    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    @Test
    fun openNotificationAndTapAction() {
        device.openNotification()
        device.wait(Until.hasObject(By.text("New message")), 5_000)

        val notification: UiObject2 = device.findObject(By.text("New message"))
        notification.click()

        // Wait for app to open
        device.wait(Until.hasObject(By.res("com.example.app", "message_detail")), 5_000)

        val detail = device.findObject(By.res("com.example.app", "message_detail"))
        assertNotNull(detail)
    }
}
```

## UI Automator Selectors

```kotlin
// By resource ID (package:id/name)
device.findObject(By.res("com.example.app", "btn_submit"))

// By text
device.findObject(By.text("Accept"))
device.findObject(By.textContains("Accept"))
device.findObject(By.textStartsWith("Acc"))

// By content description
device.findObject(By.desc("Navigate up"))

// By class
device.findObject(By.clazz("android.widget.Button"))

// Combining selectors
device.findObject(
    By.res("com.example.app", "item_title")
        .text("Important")
        .enabled(true)
)

// Child selector
val list = device.findObject(By.res("com.example.app", "recycler"))
val firstItem = list.findObject(By.res("com.example.app", "item_title"))
```

## Device Interactions

```kotlin
// Navigation
device.pressBack()
device.pressHome()
device.pressRecentApps()

// Swipe and scroll
device.swipe(500, 1500, 500, 500, 10) // x1, y1, x2, y2, steps

// Scroll until element found
val scrollable = UiScrollable(UiSelector().scrollable(true))
scrollable.scrollTextIntoView("Target Item")

// Rotate device
device.setOrientationLandscape()
device.setOrientationPortrait()
device.setOrientationNatural()

// Wait for app to launch
device.wait(Until.hasObject(By.pkg("com.example.app").depth(0)), 10_000)

// Take a screenshot
device.takeScreenshot(File("/sdcard/test_screenshot.png"))

// Wake up the device
device.wakeUp()
device.pressKeyCode(KeyEvent.KEYCODE_MENU)
```

## Permission Dialogs (UI Automator)

```kotlin
@Test
fun handleRuntimePermission() {
    // Trigger the permission request in your app
    onView(withId(R.id.btn_camera)).perform(click())

    // Handle the system permission dialog with UI Automator
    val allowButton = device.findObject(
        By.res("com.android.permissioncontroller", "permission_allow_foreground_only_button")
    )
    if (allowButton != null) {
        allowButton.click()
    }

    // Verify camera preview is shown
    device.wait(Until.hasObject(By.res("com.example.app", "camera_preview")), 5_000)
}
```

## Combining Espresso and UI Automator

```kotlin
@Test
fun shareToExternalApp_andReturn() {
    // Espresso: interact with your app
    onView(withId(R.id.btn_share)).perform(click())

    // UI Automator: interact with the share sheet (system UI)
    val shareSheet = device.wait(Until.hasObject(By.text("Messages")), 5_000)
    device.findObject(By.text("Messages")).click()

    // UI Automator: wait for external app
    device.wait(Until.hasObject(By.pkg("com.google.android.apps.messaging")), 5_000)

    // Navigate back to your app
    device.pressBack()
    device.pressBack()

    // Espresso: verify you are back in your app
    onView(withId(R.id.btn_share)).check(matches(isDisplayed()))
}
```

## Gradle Execution

```bash
# Run all instrumented tests
./gradlew connectedDebugAndroidTest

# Run on a specific device
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.CrossAppTest

# Clear app data between tests (with orchestrator)
# In build.gradle.kts:
# testOptions {
#     execution = "ANDROIDX_TEST_ORCHESTRATOR"
# }
./gradlew connectedDebugAndroidTest
```
