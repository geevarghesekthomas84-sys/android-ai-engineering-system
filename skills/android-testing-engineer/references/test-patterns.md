# Testing Patterns and Best Practices

## Arrange-Act-Assert

Every test follows the same three-phase structure:

```kotlin
@Test
fun `adding item to cart updates total`() {
    // Arrange: set up preconditions
    val cart = ShoppingCart()
    val item = Product(id = "1", name = "Widget", price = 9.99)

    // Act: perform the action under test
    cart.addItem(item, quantity = 2)

    // Assert: verify the expected outcome
    assertEquals(19.98, cart.total, 0.001)
    assertEquals(1, cart.items.size)
    assertEquals(2, cart.items[0].quantity)
}
```

One act per test. If you need to assert after multiple actions, write multiple tests.

## Test Naming Conventions

Use backtick syntax for readable names that describe the scenario:

```kotlin
// Pattern: `subject_condition_expectedResult`
fun `fetchUser with valid ID returns user`()
fun `fetchUser with unknown ID throws NotFoundException`()
fun `fetchUser when offline returns cached user`()
fun `submitOrder with empty cart shows error message`()
fun `login button is disabled while loading`()
```

For parameterized tests, let the parameter name provide context:

```kotlin
@ParameterizedTest(name = "email \"{0}\" should be {1}")
@CsvSource("user@example.com, true", "invalid, false", "'', false")
fun `email validation`(email: String, expected: Boolean) {
    assertEquals(expected, validator.isValidEmail(email))
}
```

## Test Fixtures and Factories

Create factory functions to build test objects. Avoid copying constructor calls across tests.

```kotlin
// TestFixtures.kt (in test source set)
object TestFixtures {

    fun user(
        id: String = "user_1",
        name: String = "Alice",
        email: String = "alice@example.com",
        role: Role = Role.MEMBER,
    ) = User(id = id, name = name, email = email, role = role)

    fun order(
        id: String = "order_1",
        userId: String = "user_1",
        status: OrderStatus = OrderStatus.PENDING,
        items: List<OrderItem> = listOf(orderItem()),
    ) = Order(id = id, userId = userId, status = status, items = items)

    fun orderItem(
        productId: String = "prod_1",
        name: String = "Widget",
        price: Double = 9.99,
        quantity: Int = 1,
    ) = OrderItem(productId = productId, name = name, price = price, quantity = quantity)
}

// Usage in tests
@Test
fun `admin user can delete orders`() {
    val admin = TestFixtures.user(role = Role.ADMIN)
    val order = TestFixtures.order(userId = admin.id)
    // ...
}
```

## Fake vs Mock vs Stub

**Fake**: A working implementation with simplified behavior. Preferred when the interface is simple and the fake is reusable.

```kotlin
class FakeUserRepository : UserRepository {
    private val users = mutableMapOf<String, User>()

    override suspend fun getUser(id: String): User =
        users[id] ?: throw NotFoundException("User $id not found")

    override suspend fun saveUser(user: User) {
        users[user.id] = user
    }

    fun addUser(user: User) { users[user.id] = user }
    fun clear() { users.clear() }
}
```

**Mock**: Verifies interactions. Use when you need to confirm a method was called with specific arguments.

```kotlin
val analytics = mockk<Analytics>()
viewModel.onPurchaseComplete(order)
verify { analytics.trackEvent("purchase", mapOf("order_id" to "123", "total" to "49.99")) }
```

**Stub**: Returns canned data. Use MockK with `every`/`coEvery` for simple return values.

```kotlin
val repo = mockk<ProductRepository>()
coEvery { repo.getProduct("1") } returns Product("1", "Widget", 9.99)
```

**Guideline**: Prefer fakes for repositories and data sources. Use mocks sparingly, only to verify interactions that are part of the contract (e.g., analytics events, logging calls). Never mock data classes.

## Testing Error States

```kotlin
@Test
fun `network error shows retry button`() = runTest {
    val repo = mockk<ItemRepository>()
    coEvery { repo.getItems() } throws IOException("No connection")

    val viewModel = ItemListViewModel(repo, UnconfinedTestDispatcher(testScheduler))

    viewModel.uiState.test {
        skipItems(1) // skip initial

        viewModel.loadItems()

        assertEquals(ItemUiState.Loading, awaitItem())
        val error = awaitItem() as ItemUiState.Error
        assertEquals("No connection", error.message)
        assertTrue(error.canRetry)

        cancelAndIgnoreRemainingEvents()
    }
}

@Test
fun `retry after error reloads data`() = runTest {
    val repo = mockk<ItemRepository>()
    coEvery { repo.getItems() } throws IOException("fail") andThen listOf(Item("1", "OK"))

    val viewModel = ItemListViewModel(repo, UnconfinedTestDispatcher(testScheduler))

    viewModel.uiState.test {
        skipItems(1)

        viewModel.loadItems()
        skipItems(2) // Loading, Error

        viewModel.retry()
        assertEquals(ItemUiState.Loading, awaitItem())
        val success = awaitItem() as ItemUiState.Success
        assertEquals(1, success.items.size)

        cancelAndIgnoreRemainingEvents()
    }
}
```

## Testing Loading States

```kotlin
@Test
fun `loading state shows while fetching data`() {
    composeTestRule.mainClock.autoAdvance = false

    composeTestRule.setContent {
        ItemListScreen(viewModel = viewModel)
    }

    viewModel.loadItems()
    composeTestRule.mainClock.advanceTimeByFrame()

    composeTestRule.onNodeWithTag("loading_indicator").assertIsDisplayed()
    composeTestRule.onNodeWithTag("item_list").assertDoesNotExist()

    composeTestRule.mainClock.autoAdvance = true
    composeTestRule.waitForIdle()

    composeTestRule.onNodeWithTag("loading_indicator").assertDoesNotExist()
    composeTestRule.onNodeWithTag("item_list").assertIsDisplayed()
}
```

## Testing Pagination

```kotlin
@Test
fun `loading next page appends items`() = runTest {
    val repo = FakePaginatedRepository(
        pages = mapOf(
            1 to listOf(Item("1"), Item("2")),
            2 to listOf(Item("3"), Item("4")),
        )
    )
    val viewModel = PaginatedViewModel(repo, UnconfinedTestDispatcher(testScheduler))

    viewModel.uiState.test {
        skipItems(1)

        viewModel.loadInitial()
        val first = (awaitItem() as PaginatedUiState.Success)
        assertEquals(2, first.items.size)
        assertTrue(first.hasMore)

        viewModel.loadNextPage()
        val second = (awaitItem() as PaginatedUiState.Success)
        assertEquals(4, second.items.size)
        assertFalse(second.hasMore)

        cancelAndIgnoreRemainingEvents()
    }
}
```

## Integration Testing with Room

```kotlin
@RunWith(AndroidJUnit4::class)
class TaskDaoTest {

    private lateinit var database: AppDatabase
    private lateinit var taskDao: TaskDao

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        taskDao = database.taskDao()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun insertAndRetrieveTask() = runTest {
        val task = TaskEntity(id = "1", title = "Buy milk", completed = false)

        taskDao.insert(task)
        val loaded = taskDao.getById("1")

        assertEquals("Buy milk", loaded?.title)
        assertFalse(loaded!!.completed)
    }

    @Test
    fun completedTasksFlow_updatesOnChange() = runTest {
        val task = TaskEntity(id = "1", title = "Test", completed = false)
        taskDao.insert(task)

        taskDao.getCompletedTasks().test {
            assertEquals(0, awaitItem().size)

            taskDao.update(task.copy(completed = true))
            assertEquals(1, awaitItem().size)

            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

## Testing Network with MockWebServer

```kotlin
class ApiServiceTest {

    private lateinit var mockWebServer: MockWebServer
    private lateinit var apiService: ApiService

    @Before
    fun setUp() {
        mockWebServer = MockWebServer()
        mockWebServer.start()

        val retrofit = Retrofit.Builder()
            .baseUrl(mockWebServer.url("/"))
            .addConverterFactory(MoshiConverterFactory.create())
            .build()

        apiService = retrofit.create(ApiService::class.java)
    }

    @After
    fun tearDown() {
        mockWebServer.shutdown()
    }

    @Test
    fun `getUsers parses response correctly`() = runTest {
        mockWebServer.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setHeader("Content-Type", "application/json")
                .setBody("""[{"id":"1","name":"Alice"},{"id":"2","name":"Bob"}]""")
        )

        val users = apiService.getUsers()

        assertEquals(2, users.size)
        assertEquals("Alice", users[0].name)

        val request = mockWebServer.takeRequest()
        assertEquals("GET", request.method)
        assertEquals("/users", request.path)
    }

    @Test
    fun `getUsers on 500 throws HttpException`() = runTest {
        mockWebServer.enqueue(MockResponse().setResponseCode(500))

        assertThrows<HttpException> {
            apiService.getUsers()
        }
    }
}
```

## Flaky Test Mitigation

1. **Never use `Thread.sleep()` or `delay()` in tests.** Use `advanceUntilIdle()`, `waitUntil {}`, or Turbine's `awaitItem()`.

2. **Isolate test state.** Each test creates its own instances. Use `@BeforeEach` to reset shared state. Use Room's `inMemoryDatabaseBuilder` with `allowMainThreadQueries()`.

3. **Disable animations on emulator.** In CI, use `disable-animations: true` in the emulator runner action. Locally: `adb shell settings put global window_animation_scale 0`.

4. **Use `IdlingResource` for Espresso.** Register for every async operation Espresso does not know about.

5. **Avoid real time dependencies.** Inject `Clock` or `TimeProvider` interfaces. In tests, provide a `FakeClock` that returns controlled values.

6. **Retry flaky connected tests in CI** only as a temporary measure while fixing root cause:

```kotlin
// build.gradle.kts
android {
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
        // Retry failed tests once
        emulatorSnapshots { enableForTestFailures = true }
    }
}
```

7. **Quarantine persistently flaky tests.** Tag them with `@Tag("flaky")` and exclude from the main CI run until fixed:

```kotlin
tasks.withType<Test> {
    useJUnitPlatform {
        excludeTags("flaky")
    }
}
```

## Test Isolation

- Each test must be independent. Running tests in any order must produce the same results.
- Never rely on test execution order. JUnit 5 does not guarantee order by default.
- Use `@TestInstance(TestInstance.Lifecycle.PER_METHOD)` (the default) so each test gets a fresh instance.
- For instrumented tests, use AndroidX Test Orchestrator to clear app state between tests.
- For database tests, use in-memory databases that are closed in `@After`.
- For shared preferences, use `context.getSharedPreferences("test", MODE_PRIVATE)` and call `edit().clear().apply()` in `@Before`.
