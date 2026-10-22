# Android Testing

## Test Structure

```
app/src/
â”œâ”€â”€ main/                    # Production code
â”œâ”€â”€ test/                    # Unit tests (JVM)
â”‚   â””â”€â”€ java/com/example/app/
â”‚       â”œâ”€â”€ viewmodel/
â”‚       â”œâ”€â”€ repository/
â”‚       â””â”€â”€ usecase/
â””â”€â”€ androidTest/             # Instrumentation tests (device/emulator)
    â””â”€â”€ java/com/example/app/
        â”œâ”€â”€ ui/
        â””â”€â”€ db/
```

## Dependencies

```kotlin
dependencies {
    // Unit testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
    testImplementation("io.mockk:mockk:1.13.13")
    testImplementation("app.cash.turbine:turbine:1.2.0")
    testImplementation("com.google.truth:truth:1.4.4")

    // Compose UI testing
    androidTestImplementation(platform("androidx.compose:compose-bom:2025.06.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    // Espresso
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")

    // Hilt testing
    androidTestImplementation("com.google.dagger:hilt-android-testing:2.53.1")
    kspAndroidTest("com.google.dagger:hilt-compiler:2.53.1")
}
```

## Unit Tests (JVM)

### ViewModel Test
```kotlin
class HomeViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val getUsersUseCase = mockk<GetUsersUseCase>()
    private lateinit var viewModel: HomeViewModel

    @Before
    fun setup() {
        every { getUsersUseCase() } returns flowOf(listOf(
            User("1", "Alice", "alice@example.com"),
            User("2", "Bob", "bob@example.com")
        ))
        viewModel = HomeViewModel(getUsersUseCase)
    }

    @Test
    fun `initial state loads users successfully`() = runTest {
        viewModel.uiState.test {
            val loading = awaitItem()
            assertThat(loading).isInstanceOf(HomeUiState.Loading::class.java)

            val success = awaitItem()
            assertThat(success).isInstanceOf(HomeUiState.Success::class.java)
            assertThat((success as HomeUiState.Success).users).hasSize(2)
        }
    }

    @Test
    fun `error state when use case fails`() = runTest {
        every { getUsersUseCase() } returns flow { throw RuntimeException("Network error") }
        viewModel = HomeViewModel(getUsersUseCase)

        viewModel.uiState.test {
            skipItems(1) // Skip loading
            val error = awaitItem()
            assertThat(error).isInstanceOf(HomeUiState.Error::class.java)
            assertThat((error as HomeUiState.Error).message).contains("Network error")
        }
    }
}
```

### MainDispatcherRule (Test Utility)
```kotlin
class MainDispatcherRule(
    val testDispatcher: TestDispatcher = UnconfinedTestDispatcher()
) : TestWatcher() {
    override fun starting(description: Description) {
        Dispatchers.setMain(testDispatcher)
    }
    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}
```

### Repository Test
```kotlin
class UserRepositoryImplTest {

    private val api = mockk<ApiService>()
    private val dao = mockk<UserDao>(relaxed = true)
    private val repository = UserRepositoryImpl(api, dao)

    @Test
    fun `getUsers returns mapped domain models from dao`() = runTest {
        val entities = listOf(UserEntity("1", "Alice", "alice@example.com"))
        every { dao.getAll() } returns flowOf(entities)

        repository.getUsers().test {
            val users = awaitItem()
            assertThat(users).hasSize(1)
            assertThat(users[0].name).isEqualTo("Alice")
            awaitComplete()
        }
    }

    @Test
    fun `refreshUsers fetches from api and saves to dao`() = runTest {
        val dtos = listOf(UserDto("1", "Alice", "alice@example.com"))
        coEvery { api.getUsers() } returns dtos

        repository.refreshUsers()

        coVerify { dao.upsert(any()) }
    }
}
```

### Use Case Test
```kotlin
class GetUsersUseCaseTest {

    private val repository = mockk<UserRepository>()
    private val useCase = GetUsersUseCase(repository)

    @Test
    fun `invoke delegates to repository`() = runTest {
        val users = listOf(User("1", "Alice", "alice@example.com"))
        every { repository.getUsers() } returns flowOf(users)

        useCase().test {
            assertThat(awaitItem()).isEqualTo(users)
            awaitComplete()
        }
    }
}
```

## Compose UI Tests

### Basic Compose Test
```kotlin
class HomeScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun `displays user list when loaded`() {
        val users = listOf(
            User("1", "Alice", "alice@example.com"),
            User("2", "Bob", "bob@example.com")
        )

        composeTestRule.setContent {
            AppTheme {
                UserList(users = users, onUserClick = {})
            }
        }

        composeTestRule.onNodeWithText("Alice").assertIsDisplayed()
        composeTestRule.onNodeWithText("Bob").assertIsDisplayed()
    }

    @Test
    fun `shows loading indicator`() {
        composeTestRule.setContent {
            AppTheme {
                AsyncContent(state = Result.Loading, onRetry = {}) {}
            }
        }

        composeTestRule.onNode(hasProgressBarRangeInfo(ProgressBarRangeInfo.Indeterminate))
            .assertIsDisplayed()
    }

    @Test
    fun `search bar handles input`() {
        var searchQuery = ""

        composeTestRule.setContent {
            SearchBarStateful(onSearch = { searchQuery = it })
        }

        composeTestRule.onNodeWithText("Search...").performTextInput("test query")
        composeTestRule.onNodeWithContentDescription("Search").performClick()

        assertThat(searchQuery).isEqualTo("test query")
    }
}
```

### Navigation Test
```kotlin
class NavigationTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun `navigates to detail on user click`() {
        // Setup test data
        composeTestRule.onNodeWithText("Alice").performClick()
        composeTestRule.onNodeWithText("User Detail").assertIsDisplayed()
    }
}
```

## Espresso Instrumentation Tests

### Basic Espresso Test
```kotlin
@RunWith(AndroidJUnit4::class)
class MainActivityTest {

    @get:Rule
    val activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Test
    fun appLaunches() {
        onView(withId(R.id.main_container)).check(matches(isDisplayed()))
    }
}
```

## Room Database Tests

```kotlin
@RunWith(AndroidJUnit4::class)
class UserDaoTest {

    private lateinit var database: AppDatabase
    private lateinit var dao: UserDao

    @Before
    fun setup() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java
        ).allowMainThreadQueries().build()
        dao = database.userDao()
    }

    @After
    fun teardown() { database.close() }

    @Test
    fun insertAndRetrieveUser() = runTest {
        val user = UserEntity("1", "Alice", "alice@example.com")
        dao.upsert(user)

        dao.getAll().test {
            val users = awaitItem()
            assertThat(users).hasSize(1)
            assertThat(users[0].name).isEqualTo("Alice")
            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

## Running Tests

### Command Line
```powershell
# All unit tests
.\gradlew test

# Specific module
.\gradlew :app:test

# Specific test class
.\gradlew :app:testDebugUnitTest --tests "com.example.app.HomeViewModelTest"

# With verbose output
.\gradlew test --info

# Instrumentation tests (requires connected device/emulator)
.\gradlew connectedAndroidTest

# Specific instrumentation test
.\gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.example.app.ui.HomeScreenTest
```

### Using the Automation Script
```powershell
& "$HOME/.claude/skills/android-cli\scripts\run-tests.ps1" -ProjectPath ".\my-app"
& "$HOME/.claude/skills/android-cli\scripts\run-tests.ps1" -ProjectPath ".\my-app" -Instrumented
```

### Test Reports
After running tests, reports are at:
- Unit tests: `app/build/reports/tests/testDebugUnitTest/index.html`
- Instrumentation: `app/build/reports/androidTests/connected/index.html`

## CI/CD with GitHub Actions

```yaml
name: Android CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
      - name: Run unit tests
        run: ./gradlew test
      - name: Run lint
        run: ./gradlew lint
      - name: Build debug APK
        run: ./gradlew assembleDebug
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk

  instrumented-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: gradle/actions/setup-gradle@v4
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          arch: x86_64
          script: ./gradlew connectedCheck
```

## Accessibility Testing

```kotlin
// Enable accessibility checks in tests
@get:Rule
val composeTestRule = createComposeRule().apply {
    // Compose automatically validates semantics
}

@Test
fun `all interactive elements have content descriptions`() {
    composeTestRule.setContent { HomeScreen() }

    // Check that all clickable elements have descriptions
    composeTestRule.onAllNodes(hasClickAction())
        .assertAll(hasContentDescription())
}
```

Also test manually with TalkBack enabled on a device/emulator.
