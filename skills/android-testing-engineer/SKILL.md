---
name: android-testing-engineer
description: Comprehensive Android testing with JUnit, Compose UI tests, Espresso, UI Automator, screenshot testing, accessibility checks, and CI automation
metadata:
  author: Custom
  keywords:
  - testing
  - junit
  - compose-test
  - espresso
  - ui-automator
  - screenshot-testing
  - accessibility
  - ci-cd
---

# Android Testing Engineer

## Trigger Conditions

Activate this skill when:
- Writing new tests or modifying existing tests for Android code
- Investigating test failures, flaky tests, or test infrastructure issues
- Analyzing code coverage and identifying untested paths
- Setting up or modifying CI/CD pipelines for Android projects
- Adding accessibility testing or validating WCAG compliance
- Performing screenshot regression testing or updating golden images
- Configuring test matrices across API levels or device configurations
- Running static analysis (detekt, ktlint) or dependency vulnerability scans
- Benchmarking performance or profiling test execution times

## Testing Pyramid

Follow the testing pyramid strictly. Each layer has a cost/speed tradeoff:

```
        /  E2E  \          ~5%   — UI Automator cross-app flows
       / UI Tests \        ~15%  — Compose test rules, Espresso
      / Integration \      ~20%  — Room, Retrofit + MockWebServer, Hilt
     /  Unit Tests   \     ~60%  — JUnit 5, coroutine tests, Flow tests
```

**Unit tests** run on JVM with no Android framework. They are fast, deterministic, and form the foundation. Test ViewModels, repositories, mappers, validators, and business logic here.

**Integration tests** verify component interactions. Use Room's `inMemoryDatabaseBuilder`, MockWebServer for network, and Hilt's `@HiltAndroidTest` for DI wiring.

**UI tests** run on a device or emulator. Compose UI tests with `createComposeRule` cover component rendering, interaction, and navigation. Espresso handles View-based UI.

**E2E tests** use UI Automator to cross app boundaries, test notifications, permissions dialogs, deep links from external apps, and multi-app workflows.

## Capabilities

### Test Frameworks
- **JUnit 5** (Jupiter): `@Test`, `@Nested`, `@ParameterizedTest`, `@RepeatedTest`, lifecycle callbacks, assertions, assumptions, dynamic tests
- **Compose UI Tests**: `ComposeTestRule`, semantic matchers, actions, assertions, clock control, screenshot capture
- **Espresso**: View matching, actions, assertions, idling resources, intents, RecyclerView actions
- **UI Automator**: `UiDevice`, `UiObject2`, cross-app interaction, device controls

### Test Infrastructure
- **Coroutine Testing**: `runTest`, `StandardTestDispatcher`, `UnconfinedTestDispatcher`, `advanceUntilIdle`, `TestScope`
- **Flow Testing**: Turbine library (`test {}`, `awaitItem`, `awaitComplete`, `awaitError`, `expectNoEvents`)
- **Mocking**: MockK (`every`, `coEvery`, `verify`, `coVerify`, `slot`, `answers`, `spyk`, `mockkStatic`)
- **DI Testing**: Hilt test rules, `@UninstallModules`, `@BindValue`, custom test modules

### Quality Gates
- **Screenshot Regression**: Compose Preview Screenshot Testing, Roborazzi golden image comparison
- **Accessibility**: Semantics assertions, touch target validation, contrast checks, TalkBack verification
- **Static Analysis**: detekt (code smells, complexity), ktlint (formatting), Android Lint
- **Dependency Scanning**: Gradle dependency verification, OWASP dependency-check, Renovate/Dependabot

### CI/CD
- GitHub Actions workflows with emulator matrices
- JaCoCo coverage reports with enforced thresholds
- Test sharding across API levels (26, 30, 34, 35)
- Gradle build cache and dependency caching
- Parallel test execution with `maxParallelForks`

## Workflow

When asked to write tests or improve test coverage:

1. **Identify testable behavior**: Read the source code. List the public API, state transitions, edge cases, error paths, and boundary conditions. Do not test private implementation details.

2. **Choose the right test level**: Unit test by default. Escalate to integration only when verifying real component wiring. Escalate to UI test only when verifying visual rendering or user interaction flows.

3. **Write the test**: Follow Arrange-Act-Assert. Use descriptive test names that state the scenario and expected outcome. One logical assertion per test method.

4. **Run the test**: Execute via Gradle. For unit tests: `./gradlew testDebugUnitTest --tests "com.example.FeatureTest"`. For connected tests: `./gradlew connectedDebugAndroidTest`. Capture and read the output.

5. **Verify the result**: Confirm the test passes. If it fails, diagnose the root cause—do not blindly adjust assertions to match broken behavior.

6. **Add to CI**: Ensure the test runs in the CI pipeline. Add to the appropriate test suite. Update coverage thresholds if adding a new module.

## Rules

- **Every sample has meaningful automated tests.** Any code example, feature implementation, or architectural pattern must include tests that exercise its core behavior, edge cases, and error states. A feature without tests is incomplete.

- **Never report unexecuted tests as passed.** Always run tests through Gradle or the test runner and read the actual output. Do not assume a test passes based on how it looks. Do not fabricate test results.

- **Test behavior, not implementation.** Tests should survive refactoring. Assert on observable outputs (return values, state changes, emitted events, rendered UI) rather than internal method calls or field values.

- **Keep tests deterministic.** No sleeping, no relying on real clocks, no network calls in unit tests, no shared mutable state between tests. Use `TestDispatcher` for coroutines, `MainClock` for Compose animations, and `MockWebServer` for HTTP.

- **Name tests descriptively.** Use the pattern: `fun methodOrScenario_condition_expectedResult()` or backtick syntax: `` fun `login with expired token refreshes and retries`() ``.

- **Treat test code as production code.** Apply the same standards for readability, DRY (via fixtures and helpers), and maintainability. Review test code in PRs.

## Reference Files

- `references/unit-testing.md` — JUnit 5, coroutines, Flow, ViewModel, MockK
- `references/compose-testing.md` — Compose UI test rules, matchers, actions, assertions
- `references/espresso-uiautomator.md` — Espresso and UI Automator APIs
- `references/screenshot-testing.md` — Screenshot regression with Roborazzi and Compose Preview
- `references/accessibility-testing.md` — Accessibility validation and WCAG compliance
- `references/ci-automation.md` — GitHub Actions, coverage, emulator matrices
- `references/test-patterns.md` — Patterns, anti-patterns, and best practices
