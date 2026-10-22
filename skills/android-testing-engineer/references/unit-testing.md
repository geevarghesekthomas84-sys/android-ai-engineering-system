# Unit Testing with JUnit 5 and Kotlin

## Dependencies

```kotlin
// build.gradle.kts (module-level)
dependencies {
    testImplementation(platform("org.junit:junit-bom:5.11.4"))
    testImplementation("org.junit.jupiter:junit-jupiter-api")
    testImplementation("org.junit.jupiter:junit-jupiter-params")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine")

    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.1")
    testImplementation("app.cash.turbine:turbine:1.2.0")
    testImplementation("io.mockk:mockk:1.13.16")
    testImplementation("com.google.truth:truth:1.4.4")
}

tasks.withType<Test> {
    useJUnitPlatform()
}
```

## JUnit 5 Basics

```kotlin
import org.junit.jupiter.api.*
import org.junit.jupiter.api.Assertions.*

class UserValidatorTest {

    private lateinit var validator: UserValidator

    @BeforeEach
    fun setUp() {
        validator = UserValidator()
    }

    @AfterEach
    fun tearDown() {
        // cleanup if needed
    }

    @Test
    fun `valid email returns true`() {
        assertTrue(validator.isValidEmail("user@example.com"))
    }

    @Test
    fun `blank email throws IllegalArgumentException`() {
        assertThrows<IllegalArgumentException> {
            validator.isValidEmail("")
        }
    }

    @Test
    fun `user fields are all validated together`() {
        val result = validator.validate(name = "", email = "bad", age = -1)
        assertAll(
            { assertFalse(result.isNameValid, "name should be invalid") },
            { assertFalse(result.isEmailValid, "email should be invalid") },
            { assertFalse(result.isAgeValid, "age should be invalid") },
        )
    }
}
```

## Nested Tests

```kotlin
class OrderServiceTest {

    @Nested
    inner class `when order is pending` {

        private lateinit var order: Order

        @BeforeEach
        fun setUp() {
            order = Order(status = OrderStatus.PENDING, total = 100.0)
        }

        @Test
        fun `cancel sets status to cancelled`() {
            order.cancel()
            assertEquals(OrderStatus.CANCELLED, order.status)
        }

        @Test
        fun `confirm sets status to confirmed`() {
            order.confirm()
            assertEquals(OrderStatus.CONFIRMED, order.status)
        }
    }

    @Nested
    inner class `when order is shipped` {

        @Test
        fun `cancel throws IllegalStateException`() {
            val order = Order(status = OrderStatus.SHIPPED, total = 50.0)
            assertThrows<IllegalStateException> { order.cancel() }
        }
    }
}
```

## Parameterized Tests

```kotlin
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.*

class StringUtilsTest {

    @ParameterizedTest
    @ValueSource(strings = ["racecar", "madam", "level"])
    fun `palindromes are detected correctly`(input: String) {
        assertTrue(StringUtils.isPalindrome(input))
    }

    @ParameterizedTest
    @CsvSource(
        "1, 1, 2",
        "0, 5, 5",
        "-1, 1, 0",
        "100, 200, 300",
    )
    fun `addition produces correct sum`(a: Int, b: Int, expected: Int) {
        assertEquals(expected, Calculator.add(a, b))
    }

    @ParameterizedTest
    @MethodSource("invalidEmails")
    fun `rejects invalid email formats`(email: String) {
        assertFalse(validator.isValidEmail(email))
    }

    companion object {
        @JvmStatic
        fun invalidEmails(): List<String> = listOf(
            "no-at-sign",
            "@missing-local",
            "missing-domain@",
            "spaces in@email.com",
        )
    }
}
```

## Testing Coroutines

```kotlin
import kotlinx.coroutines.test.*
import kotlinx.coroutines.ExperimentalCoroutinesApi

@OptIn(ExperimentalCoroutinesApi::class)
class UserRepositoryTest {

    private val testDispatcher = StandardTestDispatcher()

    @BeforeEach
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `fetchUser returns user from network`() = runTest {
        val api = mockk<UserApi>()
        val repo = UserRepository(api, testDispatcher)
        coEvery { api.getUser("123") } returns UserDto("123", "Alice")

        val user = repo.fetchUser("123")

        assertEquals("Alice", user.name)
        coVerify(exactly = 1) { api.getUser("123") }
    }

    @Test
    fun `fetchUser with cache returns cached value on second call`() = runTest {
        val api = mockk<UserApi>()
        val repo = UserRepository(api, StandardTestDispatcher(testScheduler))
        coEvery { api.getUser("1") } returns UserDto("1", "Bob")

        repo.fetchUser("1")
        advanceUntilIdle()
        val cached = repo.fetchUser("1")

        assertEquals("Bob", cached.name)
        coVerify(exactly = 1) { api.getUser("1") } // only one network call
    }
}
```

### StandardTestDispatcher vs UnconfinedTestDispatcher

```kotlin
@Test
fun `StandardTestDispatcher requires explicit advancement`() = runTest {
    // Coroutines are queued, not executed immediately.
    // Call advanceUntilIdle(), advanceTimeBy(), or runCurrent() to execute.
    val deferred = async { computeExpensiveValue() }
    advanceUntilIdle() // runs the queued coroutine
    assertEquals(42, deferred.await())
}

@Test
fun `UnconfinedTestDispatcher executes eagerly`() = runTest(UnconfinedTestDispatcher()) {
    // Coroutines start executing immediately upon launch.
    // Useful when you do not need to control execution order.
    var value = 0
    launch { value = 42 }
    assertEquals(42, value) // already executed
}
```

## Testing Flow with Turbine

```kotlin
import app.cash.turbine.test

class SearchViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    @Test
    fun `search query emits loading then results`() = runTest {
        val repo = mockk<SearchRepository>()
        coEvery { repo.search("kotlin") } returns listOf("Kotlin Basics", "Kotlin Coroutines")

        val viewModel = SearchViewModel(repo, testDispatcher)

        viewModel.uiState.test {
            assertEquals(SearchUiState.Idle, awaitItem())

            viewModel.search("kotlin")

            assertEquals(SearchUiState.Loading, awaitItem())
            val success = awaitItem() as SearchUiState.Success
            assertEquals(2, success.results.size)

            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `search error emits error state`() = runTest {
        val repo = mockk<SearchRepository>()
        coEvery { repo.search(any()) } throws IOException("Network error")

        val viewModel = SearchViewModel(repo, UnconfinedTestDispatcher(testScheduler))

        viewModel.uiState.test {
            skipItems(1) // skip Idle

            viewModel.search("fail")

            assertEquals(SearchUiState.Loading, awaitItem())
            val error = awaitItem() as SearchUiState.Error
            assertEquals("Network error", error.message)

            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

## Testing ViewModel State Transitions

```kotlin
class CounterViewModelTest {

    @Test
    fun `increment updates count`() = runTest {
        val viewModel = CounterViewModel()

        viewModel.uiState.test {
            assertEquals(CounterUiState(count = 0), awaitItem())

            viewModel.increment()
            assertEquals(CounterUiState(count = 1), awaitItem())

            viewModel.increment()
            assertEquals(CounterUiState(count = 2), awaitItem())

            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

## MockK Patterns

```kotlin
import io.mockk.*

class PaymentServiceTest {

    private val gateway = mockk<PaymentGateway>()
    private val logger = mockk<TransactionLogger>(relaxed = true) // relaxed = ignore unconfigured calls
    private val service = PaymentService(gateway, logger)

    @Test
    fun `processPayment captures transaction ID`() = runTest {
        val slot = slot<String>()
        coEvery { gateway.charge(any(), any()) } returns PaymentResult.Success("txn_abc")
        every { logger.log(capture(slot)) } just Runs

        service.processPayment(amount = 99.99, currency = "USD")

        assertEquals("txn_abc", slot.captured)
        coVerify { gateway.charge(99.99, "USD") }
        verify { logger.log("txn_abc") }
    }

    @Test
    fun `processPayment retries on transient failure`() = runTest {
        coEvery { gateway.charge(any(), any()) } throws
            IOException("timeout") andThen
            PaymentResult.Success("txn_retry")

        val result = service.processPayment(50.0, "EUR")

        assertTrue(result.isSuccess)
        coVerify(exactly = 2) { gateway.charge(50.0, "EUR") }
    }

    @Test
    fun `mock static extension function`() {
        mockkStatic("com.example.ExtensionsKt")
        every { "test".toSlug() } returns "test-slug"

        assertEquals("test-slug", "test".toSlug())

        unmockkStatic("com.example.ExtensionsKt")
    }
}
```

## Gradle Execution

```bash
# Run all unit tests for debug variant
./gradlew testDebugUnitTest

# Run a specific test class
./gradlew testDebugUnitTest --tests "com.example.app.UserValidatorTest"

# Run a specific test method
./gradlew testDebugUnitTest --tests "com.example.app.UserValidatorTest.valid email returns true"

# Run with verbose output
./gradlew testDebugUnitTest --info

# Generate HTML report (build/reports/tests/testDebugUnitTest/index.html)
./gradlew testDebugUnitTest --continue
```
