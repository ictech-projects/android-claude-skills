# Unit Testing Rules

Reusable guidelines for unit-testing Clean Architecture + MVVM Android apps.
Target: **≥ 90% line coverage** on every `Repository`, `UseCase`, and `ViewModel` class.

These rules are project-agnostic and support **both Mockito-Kotlin and MockK**. The mocking
library, JUnit version, error model, and file conventions are all *detected from the project*
during onboarding (§0) — never assumed.

Code templates live in `codegen/templates/<library>/` (see §8). A worked example on the
`Leave` feature is at the end.

---

## 0. Project Onboarding — Do This First

Before writing a single test, Claude must read the project to orient itself. These steps are
mandatory and non-skippable.

### Step 0.1 — Read the base package

Open `app/build.gradle.kts` and find `applicationId`. Every generated package and import
must be rooted at this value. Never guess or copy a package name from an example.

```kotlin
// app/build.gradle.kts
android {
    defaultConfig {
        applicationId = "com.example.myapp"   // ← base package
    }
}
```

### Step 0.2 — Detect the JUnit version

Open `gradle/libs.versions.toml` (or `app/build.gradle.kts` if there is no version catalog).
Look for:

| What you find | JUnit version | Action |
|---|---|---|
| `junit-jupiter` / `junit5` / `useJUnitPlatform()` in `testOptions` | JUnit 5 | Use JUnit5 patterns throughout (see §2.2) |
| `junit:junit:4.x` only | JUnit 4 | Use JUnit4 patterns throughout (see §2.1) |
| Neither | Unknown | **Ask the developer** which to set up, then follow the integration guide in §2.3 before writing any test |

Never mix JUnit4 and JUnit5 annotations in the same project (`@Before` + `@BeforeEach` in
the same class will silently mis-fire).

### Step 0.2b — Detect the mocking library

In the same dependency files, look for:

| What you find | Library | Action |
|---|---|---|
| `io.mockk` | MockK | Use MockK patterns + `codegen/templates/mockk/` |
| `org.mockito` / `org.mockito.kotlin` | Mockito | Use Mockito patterns + `codegen/templates/mockito/` |
| Both | Conflict | **Ask the developer** which one is the project standard. Never mix both in new tests. |
| Neither | Unknown | **Ask the developer.** Recommend MockK for Kotlin projects — it mocks final classes without configuration, has first-class suspend support (`coEvery`/`coVerify`), and can mock `object`s and extension functions (`mockkObject`/`mockkStatic`). Mockito is fine for teams already invested in it. |

All rules in §3–§7 are written library-agnostically. Where a snippet shows one library,
translate it with the cheat-sheet in §3.0.

### Step 0.2c — Detect the error model

Open the project's `Resource` (or equivalent result wrapper) class. There are two common
shapes, and the assertions you write depend on which one the project uses:

| Shape | Example | How to assert errors |
|---|---|---|
| **Typed errors** — `Resource.Error` wraps a sealed `AppError` (`Http`, `Network`, `Api`, …) | `Resource.Error(AppError.Http(500, …))` | Assert the `AppError` subtype, ideally via helpers like `assertHttpError(500)` (see §4.2) |
| **Data-carrying errors** — `Resource.Error` carries `message` / `statusCode` / `errors` fields directly | `Resource.Error(message = "Unauthorized", statusCode = 401)` | Assert `result.statusCode` and `result.message` directly; no helper file needed |

Read the project's `BaseRepository` (or equivalent) to confirm how HTTP errors, network
failures, and error bodies map into this type — e.g. a network failure may surface as
`statusCode = 0`, or as a dedicated `AppError.Network`. Write error assertions against the
*actual* mapping, not an assumed one.

### Step 0.3 — Locate or create the test harness files

Check what already exists under `app/src/test/`. Harness files vary by name across projects —
search by *purpose*, not by exact filename:

| Purpose | Common names |
|---|---|
| Shared repository-test base: `mockWebServer`, mocked common deps, `createApi<T>()` | `BaseTest.kt`, `BaseRepositoryTest.kt` |
| Typed `MockResponse` builders for `enqueue()` (and possibly `Resource` stubs for ViewModel tests) | `MockResponseFactory.kt` |
| Coroutine Main-dispatcher swap (JUnit5 extension or JUnit4 rule) | `MainDispatcherRule.kt` |
| `Resource` unwrappers / error-type assert helpers (typed-error projects only) | `TestAssertHelper.kt` |

For each file that already exists: **read it fully** before writing any test that uses it.
Use whatever is already there. If a method or property that these rules require is missing,
**propose the addition to the developer and wait for confirmation** before writing tests that
depend on it.

For each file that is missing: create it from the templates in §4 before writing feature
tests.

### Step 0.4 — Locate the fixture convention

Projects keep test fixtures in one of two ways — **detect which one exists and follow it**;
do not introduce the other style:

1. **`Source.kt` files** — top-level fixture functions co-located with the tests
   (`fun leaveBalanceResponse() = …`).
2. **`dummy/` objects** — a `dummy/XxxDummy.kt` object per feature holding fixture `val`s
   (`LeaveRepositoryDummy.leaveBalance`), referenced from repository, use case, *and*
   ViewModel tests.

Either way: if a fixture file exists for the feature, read it and reuse its fixtures — do
not duplicate them. If none exists, create one in the project's existing style (see §3 R5).

### Step 0.5 — Read the source files being tested

Before writing tests for any class, read the actual source file:

- `XxxRepository.kt` — note every public method, its parameters, return type, DAO/cache
  writes, and every branch (`if`, `when`, `?.let`, `?:`, early `return`).
- `XxxEvent.kt` + `XxxViewModel.kt` — list every `Event` subclass, every constructor
  parameter, every `init {}` side-effect, every state field the tests will assert on.
- `XxxUseCase.kt` — note parameters, return type, and whether it calls one or multiple
  repositories.

Replace all template `Xxx` / `xxx` placeholders with the actual names found in these files
**before writing a single test**. A test that doesn't compile against the real class is not
a test.

### Step 0.6 — Audit existing tests before adding new ones

Before writing tests for a class, search for existing `*Test.kt` files for that class.
Note the **file-organization convention** while you are at it (see §5.0). If tests exist:

1. Read them fully.
2. List which methods and event branches are already covered.
3. Ask the developer: **"I found existing test file(s). Do you want me to (a) complete the
   missing branches, or (b) rewrite to the current standard?"**
4. Proceed only after confirmation — do not silently add to or overwrite existing tests.

### Step 0.7 — Discover the available test Gradle task

Do not assume the test task name. Run:

```bash
./gradlew tasks --group verification
```

Look for a task matching `test*UnitTest` (e.g. `testDebugUnitTest`,
`testDevDebugUnitTest`, `testReleaseUnitTest`). Use that task name in all subsequent
`./gradlew` commands. Also note which coverage tool the project uses — `jacoco*` or
`kover*` tasks (see §9).

---

## 1. Scope

**In scope** — the layers where business logic lives:

| Layer | What to test | What "done" means |
|---|---|---|
| Repository | API call wiring, response mapping, cache writes, request body construction, error mapping | Every public method has success + error tests; non-trivial branches each have a test. |
| UseCase | Argument pass-through, result pass-through, ordering of multi-step orchestration | Success path + error path per public method. |
| ViewModel | Each event/intent branch, `init {}` side-effects, validation gates, state transitions | One test per `Event` subclass + tests for `init`. |
| Validators | Every rule and every rule combination | One test per validation rule, plus valid-input passes. |
| Local storage wrappers (DataStore / prefs) | Read/write/clear logic, conditional writes | See §5.4 — real DataStore on a temp file, not mocks. |
| Utils with logic (date/time/format/file helpers) | Each branch and edge case (`@ParameterizedTest` shines here) | Pure passthrough helpers can be skipped. |
| Custom `PagingSource` | `load()` success, error, and key calculation | `Pager(...)` wiring itself is skipped (framework glue). |

**Out of scope** — covered by other test types, not by these rules:

- UI / Compose composable tests → `androidTest/` + Compose UI testing.
- Screenshot tests → Paparazzi / Roborazzi / Shot.
- End-to-end / integration tests → instrumented tests against a staging environment.
- DAO / Room queries → in-memory Room test, separate file.
- Navigation, theming — test if they have logic, skip if they're pure passthrough.

---

## 2. Toolchain

### 2.1 JUnit 4 setup

```toml
# gradle/libs.versions.toml
[versions]
junit           = "4.13.2"
test-coroutine  = "1.10.x"
mock-webserver  = "5.x"

[libraries]
junit               = { module = "junit:junit",                                   version.ref = "junit" }
coroutines-test     = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "test-coroutine" }
mock-webserver      = { module = "com.squareup.okhttp3:mockwebserver",            version.ref = "mock-webserver" }
```

```kotlin
// app/build.gradle.kts
testImplementation(libs.junit)
testImplementation(libs.coroutines.test)
testImplementation(libs.mock.webserver)
```

`BaseTest` uses `@Before` / `@After`. `MainDispatcherRule` as a JUnit5 extension is **not
used** — dispatcher lifecycle is managed with `Dispatchers.setMain` / `resetMain` in
`@Before` / `@After`.

### 2.2 JUnit 5 setup

```toml
# gradle/libs.versions.toml
[versions]
junit5          = "5.11.x"
junit-platform  = "1.11.x"
test-coroutine  = "1.10.x"
mock-webserver  = "5.x"

[libraries]
junit5-api        = { module = "org.junit.jupiter:junit-jupiter-api",           version.ref = "junit5" }
junit5-engine     = { module = "org.junit.jupiter:junit-jupiter-engine",        version.ref = "junit5" }
junit5-params     = { module = "org.junit.jupiter:junit-jupiter-params",        version.ref = "junit5" }
platform-launcher = { module = "org.junit.platform:junit-platform-launcher",    version.ref = "junit-platform" }
coroutines-test   = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "test-coroutine" }
mock-webserver    = { module = "com.squareup.okhttp3:mockwebserver",            version.ref = "mock-webserver" }
```

```kotlin
// app/build.gradle.kts
android {
    testOptions {
        unitTests.all { it.useJUnitPlatform() }
    }
}

dependencies {
    testImplementation(libs.junit5.api)
    testImplementation(libs.junit5.params)
    testRuntimeOnly(libs.junit5.engine)
    testRuntimeOnly(libs.platform.launcher)
    testImplementation(libs.coroutines.test)
    testImplementation(libs.mock.webserver)
}
```

(Alternatively the `de.mannodermaus.android-junit5` plugin configures the platform; either
mechanism is fine — follow what the project already has.)

`BaseTest` uses `@BeforeEach` / `@AfterEach`. `MainDispatcherRule` is registered with
`@RegisterExtension` (see §4.4).

### 2.3 "Neither found" — ask first

If neither JUnit4 nor JUnit5 dependencies are present, stop and ask:

> "I don't see JUnit4 or JUnit5 in the project's dependencies. Which would you like to set
> up? I recommend JUnit5 for new projects, but JUnit4 is fine if you prefer it."

After confirmation, add the chosen dependencies (§2.1 or §2.2) then proceed to write tests.

### 2.4 Mocking library dependencies

Add **one** of the following per the detection in §0.2b:

```toml
# MockK
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }          # mockk = "1.14.x"

# Mockito
mockito-kotlin = { module = "org.mockito.kotlin:mockito-kotlin", version.ref = "mockito" }  # mockito = "5.x"
```

```kotlin
testImplementation(libs.mockk)            // or
testImplementation(libs.mockito.kotlin)
```

Mockito caveats in Kotlin projects (be explicit about these when recommending):

- Kotlin classes are `final` by default — Mockito needs the inline mock maker
  (`mockito-inline`, bundled in mockito-core 5.x) to mock them.
- `object` declarations, top-level functions, and extension functions cannot be mocked —
  refactor to injectable interfaces instead.
- MockK handles all of the above natively.

### 2.5 Optional / recommended libraries

- **Turbine** — *strongly recommended* wherever ViewModels expose `StateFlow`/`SharedFlow`
  and tests need to assert emission sequences or "no emission happened" (see §5.3). For a
  single `.value` check, plain assertions are fine.
- **kotlin-test** — `kotlin.test.assertEquals/assertTrue/...` reads naturally in Kotlin and
  works on both JUnit4 and JUnit5. Whichever assertion library the project uses, use it
  *consistently* — do not mix `kotlin.test`, `org.junit.Assert`, and
  `junit.framework.TestCase` imports across files.
- **Truth / AssertJ** — better failure diffs. Worth it on teams that read failure output a lot.
- **Robolectric** — only for classes that genuinely need Android framework primitives.
  Prefer DI so you don't need it.

---

## 3. Universal Rules

Every test in every layer must obey these.

### 3.0 Mockito ⇄ MockK cheat-sheet

The rules below show snippets in one library; translate mechanically with this table.
**Never mix both libraries in one project** (§0.2b).

| Operation | Mockito-Kotlin | MockK |
|---|---|---|
| Create a strict mock | `mock<Repo>()` | `mockk<Repo>()` |
| Incidental dependency (don't care about most calls) | `mock<Context>()` (lenient by default) | `mockk<Context>(relaxed = true)` |
| Stub | `whenever(x.f(a)).thenReturn(y)` | `every { x.f(a) } returns y` |
| Stub a `suspend` fun | `whenever(x.f(a)).thenReturn(y)` (inside `runTest`) | `coEvery { x.f(a) } returns y` |
| Stub to throw | `.thenThrow(e)` | `every { … } throws e` |
| Verify called | `verify(x).f(a)` | `verify { x.f(a) }` |
| Verify `suspend` called | `verify(x).f(a)` | `coVerify { x.f(a) }` |
| Verify count | `verify(x, times(2)).f(a)` | `verify(exactly = 2) { x.f(a) }` |
| Verify never | `verify(x, never()).f(any())` | `verify(exactly = 0) { x.f(any()) }` |
| Argument matchers | `any()`, `eq(v)`, `isNull()` | `any()`, `eq(v)`, `isNull()` |
| Match by predicate | `argThat { … }` | `match { … }` |
| Capture an argument | `argumentCaptor<T>()` | `slot<T>()` + `capture(slot)` |
| Verify call order | `inOrder(a, b).verify(…)` | `verifyOrder { … }` / `coVerifyOrder { … }` |
| Mock final class | needs inline mock maker | works by default |
| Mock `object` / static / extension fn | not supported | `mockkObject` / `mockkStatic` (use sparingly; `unmockkAll()` in teardown) |

**`relaxed = true` policy (MockK)**: relaxed mocks silently return defaults for unstubbed
calls, which can mask broken wiring. Use `relaxed = true` only for *incidental* dependencies
the test doesn't verify (e.g. `Context`, loggers). Dependencies whose interaction the test
asserts on must be strict mocks with explicit `every`/`coEvery` stubs.

### R1. Never mock the SUT — mock its dependencies

```kotlin
// ❌ Wrong — stubs the real use case, asserts nothing about its logic
val useCase = SendMessageUseCase(repo)
whenever(useCase.invoke(any(), any(), any())).thenReturn(Resource.Success(...))
val result = useCase.invoke(1, 1, "hi")
assertEquals(Resource.Success(...), result) // tautology

// ✅ Right — stubs the dependency, asserts the use case wires it correctly
val repo: ContactRepository = mock()                       // MockK: mockk<ContactRepository>()
val useCase = SendMessageUseCase(repo)
whenever(repo.sendMessage(any())).thenReturn(Resource.Success(expectedResponse()))
                                                           // MockK: coEvery { repo.sendMessage(any()) } returns …
val result = useCase.invoke(1, 1, "hi")
assertEquals(Resource.Success(expectedResponse()), result)
verify(repo).sendMessage(SendMessageRequest(1, 1, "hi"))   // MockK: coVerify { repo.sendMessage(…) }
```

### R2. Success and error, every method

For every public method:

1. One test for `Resource.Success`.
2. One test for `Resource.Error` — the standard error to simulate is an HTTP server error
   (5xx). Assert both that the result is an error **and** the error detail (see R2a).
3. One test per non-trivial branch (see §6.1).

#### R2a. Assert the error detail, not just `is Resource.Error`

How depends on the error model detected in §0.2c:

**Typed-error projects** (`AppError` sealed type) — use the helpers from `TestAssertHelper`:

```kotlin
// ❌ Too shallow
assertTrue(result is Resource.Error)

// ✅ Standard error test — HTTP 500
result.assertHttpError(500)

// ✅ When explicitly testing a network-offline branch
result.assertNetworkError()
```

Error subtypes handled generically by `BaseRepository` (`Unauthorized`, `Api`, `Unknown`)
do not need dedicated repository tests unless the method has explicit logic beyond what
`BaseRepository` already does.

**Data-carrying-error projects** (`Resource.Error(message, statusCode, errors)`) — assert
the fields directly; no helper file is needed:

```kotlin
// ✅ HTTP error
assertTrue(result is Resource.Error)
assertEquals(500, result.statusCode)
assertEquals("Internal Server Error", result.message)

// ✅ Network failure — confirm the project's actual mapping first (§0.2c);
//     e.g. BaseRepository may map IOExceptions to statusCode = 0
assertEquals(0, result.statusCode)
```

### R3. Verify the call shape, not just the return

Assert what actually left the SUT — the request the API received, or the arguments the
dependency was called with:

```kotlin
// Through MockWebServer (repository layer)
val request = mockWebServer.takeRequest()
assertEquals("GET", request.method)
assertTrue(request.path?.contains("leave-balances") == true)

// Through the mock (use case / ViewModel layer) — Mockito
verify(leaveApi).submitLeaveRequest(
    fields = argThat { it["start_date"]!!.readUtf8() == "2026-06-01" },
    document = isNull()
)
// MockK equivalent
coVerify { leaveApi.submitLeaveRequest(fields = match { it["start_date"]!!.readUtf8() == "2026-06-01" }, document = isNull()) }
```

If you only assert on the return value, swapping `startDate` and `endDate` inside the SUT
still passes.

### R4. One test = one behavior. Name it after the behavior

Two acceptable styles — pick one per project and stick to it:

```kotlin
// Style A — methodName_condition_expectedResult
@Test fun getLeaveBalances_success_cachesBalances()
@Test fun getLeaveBalances_httpError_doesNotTouchCache()

// Style B — backtick sentence (preferred for JUnit5)
@Test fun `getLeaveBalances caches balances on success`()
@Test fun `getLeaveBalances does not touch cache on http error`()
```

The body reads top-to-bottom as **Arrange / Act / Assert**. If a test has two act sections,
split it.

For table-shaped inputs (validators, formatters, parsers) prefer one `@ParameterizedTest`
(`@CsvSource` / `@MethodSource`) over N copy-pasted tests — JUnit5 only.

### R5. Co-locate fixtures, in the project's existing style

Mirror `src/main/` in `src/test/`. Keep one fixture file per feature, in whichever style
the project already uses (§0.4): top-level functions in a `Source.kt`, or `val`s in a
`dummy/XxxDummy.kt` object. The content is the same three kinds of fixtures, as applicable:

- **Response fixtures** — raw API response data (DTOs) passed into
  `MockResponseFactory.success(...)`.
- **Domain fixtures** — mapped domain models used to assert the repository's output after
  mapping. If the project uses the API response directly as the domain model (no separate
  mapping layer), one fixture per entity is enough.
- **Input fixtures** — sample request objects used as arguments to repository / use case
  calls.

```kotlin
// Style 1 — Source.kt (top-level functions)
fun leaveBalanceResponse() = listOf(
    LeaveBalanceDto(leaveTypeId = 1, balance = 12, leaveType = LeaveTypeDto(id = 1, name = "Annual")),
)
fun sampleLeaveRequest() = LeaveRequest(startLeave = "2026-06-01", endLeave = "2026-06-03", leaveTypeId = 1, leaveReason = "Family trip", startTime = null, endTime = null)

// Style 2 — dummy/LeaveRepositoryDummy.kt (object with vals)
object LeaveRepositoryDummy {
    val leaveBalance = LeaveBalanceResponse(leaveTypeId = 1, balance = 12, leaveType = LeaveType(id = 1, name = "Annual"))
    val historyItem  = LeaveHistoryResponse(id = 10, status = "pending")
}
```

Use cases and ViewModels that need the same fixtures import from the repository's fixture
file. Do not duplicate. Fixtures that are `data class`es can be specialized per-test with
`.copy(...)` instead of new fixture entries.

### R6. Use the right test dispatcher

| Layer | Dispatcher | Why |
|---|---|---|
| Repository, UseCase | `StandardTestDispatcher` via `runTest` | Deterministic ordering; call `advanceUntilIdle()` when needed. |
| ViewModel | Either of the two patterns below — **follow the project's existing choice** | |

Two valid ViewModel patterns:

1. **Unconfined**: `Dispatchers.setMain(UnconfinedTestDispatcher())` — `viewModelScope`
   coroutines run eagerly, so `uiState.value` reflects them immediately after `onEvent`.
2. **Standard + Turbine**: `MainDispatcherRule()` with the default
   `StandardTestDispatcher`, asserting through `flow.test { awaitItem() }`. `runTest`
   shares the mocked Main dispatcher's scheduler, so Turbine's suspension points let
   queued coroutines run. The rule's `afterEach` should call `advanceUntilIdle()` to
   drain leftovers.

Never `Thread.sleep`. Never `runBlocking`. Never `Dispatchers.IO` in a test.

#### R6a. `runTest` in ViewModel tests

With `UnconfinedTestDispatcher` set as main, `viewModelScope` coroutines run synchronously.
`runTest` is still required when calling `advanceUntilIdle()` / `advanceTimeBy()` or when
using Turbine. For a simple state assertion on a single event, it is optional. Be
consistent within a file — if the first ViewModel test uses `runTest`, use it throughout.

### R7. Tests must be fast and isolated

- No real network — use `MockWebServer`.
- No real database — mock the DAO interface.
- No real `Clock.System.now()` / `System.currentTimeMillis()` — inject a `Clock` /
  `TimeProvider`.
- DataStore is the exception: use a *real* DataStore on a temp file (§5.4), never the
  production file.
- Each test should run in well under 1 second.

---

## 4. Test Helper Files

Helper files live under `src/test/…/helper/` (or `…/base/`). Create them once per project;
reuse everywhere. Remember §0.3: if a project already has these under different names,
extend the existing ones — never create parallel duplicates.

### 4.1 `MockResponseFactory` — enqueue builders

Responsibility: everything that goes into `mockWebServer.enqueue(…)`. Optionally also
`Resource` stub builders for the ViewModel layer (see below).

**If the project already has a `MockResponseFactory`**: read it first. Use whatever methods
already exist. If a method needed by a test is missing (e.g. `error(httpCode, message)` or
`networkFailure()`), propose adding it to the developer before proceeding. Do not create a
second factory — extend the existing one.

#### ⚠️ Verify the `ApiResponse` envelope before writing any test

If the project's `BaseRepository` checks a field on the response body (e.g.
`body.success`) after a 2xx response, a factory that serializes the wrong field names makes
every call silently return an error — with no HTTP error to hint at the cause. Before
creating or using `MockResponseFactory`, open the project's `ApiResponse` class and confirm
its exact field names, then make the factory construct that class directly — not a plain
`Map` — so the JSON keys are right. The same applies to the error body: its shape must match
the project's `ErrorMessage`/`ErrorResponse` class (e.g. `status_code`, `message`, `errors`).

A quick sanity check: run one success test — if it fails with an API-error result instead of
the expected data, the envelope fields are wrong.

```kotlin
object MockResponseFactory {
    private val gson = Gson()

    // Wraps data in the project's ApiResponse envelope — confirm field names first (see above).
    fun <T> success(data: T): MockResponse {
        val body = gson.toJson(
            ApiResponse(statusCode = 200, success = true, message = "OK", data = data)
        )
        return MockResponse().setResponseCode(200).setBody(body)
    }

    // HTTP error responses — body shape must match the project's error-body class.
    fun error(httpCode: Int, message: String = "Error"): MockResponse {
        val body = gson.toJson(mapOf("status_code" to httpCode, "message" to message))
        return MockResponse().setResponseCode(httpCode).setBody(body)
    }

    fun unauthorized(): MockResponse        = error(401, "Unauthorized")
    fun notFound(): MockResponse            = error(404, "Not Found")
    fun unprocessable(msg: String = "Unprocessable Entity"): MockResponse = error(422, msg)
    fun internalServerError(): MockResponse = error(500, "Internal Server Error")

    // Simulates a network-level failure (no HTTP response at all).
    fun networkFailure(): MockResponse =
        MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AT_START)

    // Optional — Resource stubs for stubbing use cases in ViewModel tests, so ViewModel
    // tests don't touch MockWebServer at all:
    fun <T> successResource(data: T): Resource.Success<ApiResponse<T>> =
        Resource.Success(ApiResponse(statusCode = 200, success = true, message = "OK", data = data))

    fun <T> errorResource(message: String = "Failure", statusCode: Int? = null): Resource.Error<ApiResponse<T>> =
        Resource.Error(message = message, statusCode = statusCode)   // pass the params through — do not hardcode
}
```

The layering rule this enables: **MockWebServer at the repository layer; `Resource` stubs at
the use case / ViewModel layers.** ViewModel tests should never enqueue HTTP responses.

### 4.2 `TestAssertHelper` — assertion utilities (typed-error projects only)

Only needed when §0.2c detected a typed `AppError`-style error model. Data-carrying-error
projects assert `statusCode`/`message` directly and should **not** create this file.

```kotlin
// app/src/test/…/helper/TestAssertHelper.kt

fun <T> Resource<T>.assertSuccess(): T {
    assertTrue("Expected Resource.Success but got $this", this is Resource.Success)
    return (this as Resource.Success).data
}

fun Resource<*>.assertHttpError(expectedCode: Int? = null) {
    assertTrue("Expected Resource.Error but got $this", this is Resource.Error)
    val error = (this as Resource.Error).error
    assertTrue("Expected AppError.Http but got $error", error is AppError.Http)
    if (expectedCode != null) {
        assertEquals(expectedCode, (error as AppError.Http).code)
    }
}

fun Resource<*>.assertNetworkError() {
    assertTrue("Expected Resource.Error but got $this", this is Resource.Error)
    assertTrue(
        "Expected AppError.Network but got ${(this as Resource.Error).error}",
        (this as Resource.Error).error is AppError.Network
    )
}
```

### 4.3 `BaseTest` / `BaseRepositoryTest` — shared repository-test harness

**If the project already has one**: read it. Use it as-is. If it is missing something these
rules require, propose the addition to the developer and wait for confirmation.

**If none exists**: create from the template below, adapting the mocked common deps
(session manager, database manager, `Context`, …) to the project's actual constructor needs.

```kotlin
// app/src/test/…/helper/BaseRepositoryTest.kt   (JUnit5 shown; JUnit4 swaps the annotations)
abstract class BaseRepositoryTest {

    protected val mockWebServer = MockWebServer()

    // Common deps — relaxed only because they are incidental here (see §3.0 policy)
    protected val mockContext            = mockk<Context>(relaxed = true)      // Mockito: mock()
    protected val mockDatabaseManager    = mockk<DatabaseManager>(relaxed = true)
    protected val mockAuthSessionManager = mockk<AuthSessionManager>(relaxed = true)

    @BeforeEach
    open fun setUp() {
        mockWebServer.start()
        // If BaseRepository resolves error strings via context.getString:
        every { mockContext.getString(any()) } returns "Unexpected error"
    }

    @AfterEach
    open fun tearDown() {
        mockWebServer.shutdown()
    }

    // Short timeouts so a missing enqueue() fails fast instead of hanging the suite.
    protected inline fun <reified T> createApi(): T =
        Retrofit.Builder()
            .baseUrl(mockWebServer.url("/"))
            .client(
                OkHttpClient.Builder()
                    .connectTimeout(1, TimeUnit.SECONDS)
                    .readTimeout(1, TimeUnit.SECONDS)
                    .writeTimeout(1, TimeUnit.SECONDS)
                    .build()
            )
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(T::class.java)
}
```

### 4.4 `MainDispatcherRule`

JUnit5 extension form:

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(
    val testDispatcher: TestDispatcher = StandardTestDispatcher()
) : BeforeEachCallback, AfterEachCallback {

    override fun beforeEach(context: ExtensionContext?) {
        Dispatchers.setMain(testDispatcher)
    }

    override fun afterEach(context: ExtensionContext?) {
        testDispatcher.scheduler.advanceUntilIdle()
        Dispatchers.resetMain()
    }
}
```

Register in ViewModel tests (JUnit5):

```kotlin
@RegisterExtension
val mainDispatcherRule = MainDispatcherRule()                           // Standard + Turbine pattern
// or
val mainDispatcherRule = MainDispatcherRule(UnconfinedTestDispatcher()) // Unconfined pattern
```

For JUnit4 ViewModel tests, manage the dispatcher manually in `@Before` / `@After`:

```kotlin
@Before fun setup()    { Dispatchers.setMain(UnconfinedTestDispatcher()) }
@After  fun tearDown() { Dispatchers.resetMain() }
```

---

## 5. Layer Rules

### 5.0 File organization — detect and follow the existing convention

Two valid layouts; **never introduce the second style into a project using the first**:

1. **One test class per SUT** — `LeaveRepositoryTest.kt` holds all `LeaveRepository` tests.
2. **One test class per method / concern** — `LeaveRepositoryGetLeaveBalancesTest.kt`,
   `LeaveRepositorySubmitLeaveRequestTest.kt`, …; ViewModel tests split per concern
   (`LeaveViewModelSubmitTest.kt`, `LeaveViewModelTabTest.kt`) and share an abstract
   `LeaveViewModelBaseTest` that owns the mocks, the `MainDispatcherRule`, and a
   `@BeforeEach baseSetup()` that constructs the ViewModel.

Layout 2 keeps files small and lets the shared base test stub `init {}` dependencies once.
If the project is layout 2, a "test file per Event subclass count" check (§6.2) applies to
the *sum across the split files*, not any single file.

### 5.1 Repository

**Before writing tests**: read the repository source file. For each public method note:

- Parameters, return type.
- Every branch: `if`, `when`, `?.let`, `?:`, `try/catch`, early `return`.
- DAO / cache writes on success — these need DAO `verify` assertions.
- Whether it builds a multipart, query-param, or JSON body — these need
  `mockWebServer.takeRequest()` assertions.

Then cross-reference with the existing test files (§0.6). For each method that is fully
covered, skip it. For each method that is missing tests or missing branches, add them.

**Required tests per method**:

1. **Success** — enqueue a success response, call the method, assert success + mapped data,
   assert DAO/cache side effects.
2. **HTTP error** — enqueue a server error (5xx), assert the error detail per R2a,
   assert side effects did **not** happen.
3. **Network failure** — enqueue `MockResponseFactory.networkFailure()`, assert the
   project's network-failure mapping (§0.2c).
4. **Endpoint shape** — at least one test per method asserting `takeRequest().method` and
   path (and body, when the method builds one).
5. **Branch-fillers** — one test per remaining branch. Common cases: nullable field present
   vs absent in a request body, ID-zero mapping fallback, behaviour depending on a cached
   value, empty-list responses.

**For methods that build request bodies** — use `mockWebServer.takeRequest()`:

```kotlin
@Test fun `submitLeaveRequest omits null time fields from multipart body`() = runTest {
    mockWebServer.enqueue(MockResponseFactory.success(expectedLeaveHistoryItem()))

    repo.submitLeaveRequest(sampleLeaveRequest(), document = null)

    val body = mockWebServer.takeRequest().body.readUtf8()
    assertTrue(body.contains("name=\"start_date\""))
    assertTrue(body.contains("2026-06-01"))
    assertFalse(body.contains("name=\"start_time\""))  // null → omitted
}
```

**Skip** (framework glue — coverage-exclude): `Pager(…)` construction, plain `Flow`
operators, constructor parameter assignment. A **custom `PagingSource`**, however, is real
logic — test `load()` directly: success page (data, prevKey, nextKey), error result, and
refresh-key calculation.

### 5.2 UseCase

Most use cases are thin operators. Two to three tests per public method is usually enough:
success pass-through, error pass-through, and (optionally) an exact-count delegation check.

```kotlin
// Mockito flavor — see templates/mockk/usecase_test.md for the MockK twin
class SubmitLeaveRequestUseCaseTest {
    private val repo: LeaveRepository = mock()
    private val useCase = SubmitLeaveRequestUseCase(repo)

    @Test fun `delegates to repository with provided args`() = runTest {
        val req      = sampleLeaveRequest()
        val expected = Resource.Success(expectedLeaveHistoryItem())
        whenever(repo.submitLeaveRequest(req, null)).thenReturn(expected)

        val result = useCase(req, null)

        assertEquals(expected, result)
        verify(repo).submitLeaveRequest(req, null)
    }

    @Test fun `propagates error from repository`() = runTest {
        whenever(repo.submitLeaveRequest(any(), anyOrNull()))
            .thenReturn(/* error per the project's error model, §0.2c */)

        val result = useCase(sampleLeaveRequest(), null)

        assertTrue(result is Resource.Error)
        // + error-detail assertion per R2a
    }
}
```

**Use cases that orchestrate multiple repositories or stores** need extra tests:

- Call **order** (`inOrder` / `verifyOrder`).
- Second call uses data from the first result.
- Second call is **skipped** if the first fails or a precondition short-circuits
  (e.g. token already synced → repository never called).

### 5.3 ViewModel

**This is where most coverage gaps live.**

**Before writing tests**: read `XxxEvent.kt` and `XxxViewModel.kt`. Count every `Event`
subclass — that is your minimum test count. Note every constructor parameter (these become
mocks), every `init {}` side-effect, and every state field the tests will assert on.
Cross-reference with the existing test files (§0.6) and ask whether to complete or rewrite.

**Setup**: per the project's layout convention (§5.0) — either mocks declared in the single
test class, or an abstract `XxxViewModelBaseTest` shared by the split concern files. Either
way, `init {}` dependencies must be stubbed **before** the ViewModel is constructed; that is
exactly what the base test's `@BeforeEach baseSetup()` is for.

**One test per event branch**:

| Event type | What to assert | Tests |
|---|---|---|
| Load (`LoadX`, `RefreshX`) | Loading state → use case called → success/error state | 2 each |
| Field updates (`UpdateName`, `SelectDate`) | Field state updated; no use case called | 1 each |
| Submit / Save | (a) invalid → use case never called; (b) valid → use case called with mapped args; (c) server error → error state | 3 each |
| Cancel / Delete | Success + error state | 2 each |
| Dialog / sheet toggles | Boolean flag flips | 1 each |

**The validation-gate test is the highest-value ViewModel test**:

```kotlin
@Test fun `submit with invalid form does not call use case`() = runTest {
    whenever(validator.validate(any())).thenReturn(listOf(StartDateRequired))
    val vm = newViewModel()

    vm.onEvent(XxxEvent.Submit)

    verify(submitUseCase, never()).invoke(any(), anyOrNull())
    assertTrue(vm.fieldState.value.hasErrors)
}
```

#### 5.3a Turbine patterns for `StateFlow` / `SharedFlow`

Use Turbine whenever the assertion is about an emission *sequence* or the *absence* of an
emission — both are unreliable with bare `.value` reads under `StandardTestDispatcher`:

```kotlin
@Test fun `emits filtered balances on success`() = runTest {
    coEvery { leaveUseCases.getLeaveBalances() } returns MockResponseFactory.successResource(listOf(valid, hidden))

    viewModel.leaveBalances.test {
        skipItems(1)                       // skip the StateFlow's initial value
        viewModel.onEvent(HomeEvent.GetLeaveBalances)
        val result = awaitItem()
        assertEquals(listOf(valid), result)
        cancelAndIgnoreRemainingEvents()
    }
}

@Test fun `does not update balances on error`() = runTest {
    coEvery { leaveUseCases.getLeaveBalances() } returns Resource.Error("Network error")

    viewModel.leaveBalances.test {
        skipItems(1)
        viewModel.onEvent(HomeEvent.GetLeaveBalances)
        expectNoEvents()                   // the high-value negative assertion
        cancelAndIgnoreRemainingEvents()
    }
}
```

Rules of thumb:

- `skipItems(1)` for the `StateFlow` initial value; adjust if `init {}` already emitted.
- `expectNoEvents()` is the way to prove "error did not corrupt state".
- End every `test { }` block with `cancelAndIgnoreRemainingEvents()` unless asserting completion.
- A single final-state check can still be a plain `viewModel.x.value` assertion — don't
  force Turbine where it adds nothing.
- For `Flow<PagingData<T>>`, don't assert page contents in the ViewModel test (that's the
  `PagingSource`'s job); assert that the flow is wired (collecting one emission suffices)
  and that refresh/invalidation events trigger it.

### 5.4 Local storage — DataStore / SharedPreferences wrappers

The standing instruction: **never mock `DataStore<Preferences>` itself.** It is an
interface to a coroutine pipeline; mocking it produces stubs that lie about transactional
behaviour (`edit` semantics, conditional writes). Two tiers instead:

**Tier 1 — testing consumers of a store** (use cases, repositories, ViewModels): the store
should be wrapped in a project class (e.g. `FcmTokenStore`). Mock the *wrapper*:

```kotlin
// MockK — works out of the box, the wrapper being final doesn't matter
private val mockFcmStore = mockk<FcmTokenStore>()
coEvery { mockFcmStore.getToken() } returns "token"
coEvery { mockFcmStore.isSynced() } returns false
coVerify(exactly = 1) { mockFcmStore.markSynced() }

// Mockito — requires the inline mock maker (default in mockito-core 5.x) because
// Kotlin classes are final. If the project is on an older Mockito, either add
// mockito-inline or extract an interface for the store.
```

**Tier 2 — testing the store itself**: use a **real** Preferences DataStore on a temp file.
This is identical for both mocking libraries (no mocking involved) and exercises the real
`edit`/`first()` semantics:

```kotlin
class FcmTokenStoreTest {
    @TempDir lateinit var tempDir: File                       // JUnit4: @get:Rule TemporaryFolder

    private val testDispatcher = UnconfinedTestDispatcher()
    private val testScope = TestScope(testDispatcher + Job())
    private lateinit var store: FcmTokenStore

    @BeforeEach fun setUp() {
        val dataStore = PreferenceDataStoreFactory.create(
            scope = testScope,
            produceFile = { File(tempDir, "test.preferences_pb") }
        )
        store = FcmTokenStore(testDispatcher, dataStore)
    }

    @Test fun `saveToken resets synced flag only when token changes`() = testScope.runTest {
        store.saveToken("a"); store.markSynced()
        store.saveToken("a")                                  // same token → no-op
        assertTrue(store.isSynced())
        store.saveToken("b")                                  // new token → reset
        assertFalse(store.isSynced())
    }
}
```

**Precondition**: Tier 2 only works if the store receives its `DataStore<Preferences>` via
the constructor. If the store creates it internally (the
`private val Context.dataStore by preferencesDataStore(...)` delegate pattern), the class is
not unit-testable as-is. **Propose the refactor to the developer** — move the delegate to a
DI module and inject `DataStore<Preferences>` — and until then, coverage-exclude the store
and cover it indirectly via Tier 1 consumer tests.

### 5.5 Validators and utils

- **Validators** (`XxxValidator`): pure logic — no mocks, no dispatchers. One test per rule,
  one per rule-combination that the implementation special-cases, one all-valid test.
  Ideal `@ParameterizedTest` territory.
- **Utils** (date/time/format/file helpers): test every branch; skip pure passthroughs.
  Helpers touching `android.*` types should take injectable seams; otherwise they belong in
  instrumented tests, not here.

---

## 6. The 90% Rule — How to Actually Hit It

### 6.1 Count branches before writing tests

For each public method in the SUT:

1. Count: `if`, `when`, `?.let`, `?:`, `try/catch`, early `return`, `for`/`while`.
2. That is your minimum test count for that method.
3. For ViewModels, also count every `Event` subclass.

A method with 0 branches → 1 test (2 if it can throw). A method with 3 branches → 3–4 tests.

### 6.2 Enumerate `Event` classes for ViewModels

```kotlin
sealed interface LeaveEvent {
    object LoadLeaveBalance : LeaveEvent          // 2 tests (success/error)
    object LoadLeaveHistory : LeaveEvent          // 2 tests
    data class UpdateStartDate(val d: String)     // 1 test
    data class UpdateEndDate(val d: String)       // 1 test
    data class UpdateLeaveType(val id: Int)       // 1 test
    data class UpdateReason(val s: String)        // 1 test
    object SubmitLeaveRequest : LeaveEvent        // 3 tests
    object UpdateLeaveRequest : LeaveEvent        // 3 tests
    data class CancelLeaveRequest(val id: Int)    // 2 tests
    object DeleteDocument : LeaveEvent            // 2 tests
    data class AttachDocument(val uri: Uri)       // 1 test
    object ToggleEditMode : LeaveEvent            // 1 test
    object ShowDatePicker : LeaveEvent            // 1 test
    object DismissDialog : LeaveEvent             // 1 test
}
// Expected test count: ~22, plus 1–2 for init {}
```

If the `Event` file has 15 subclasses, the feature has ≥ 15 tests — in one file or summed
across split concern files (§5.0).

### 6.3 Tell the coverage tool what to exclude

**Jacoco**:

```kotlin
// app/build.gradle.kts
val coverageExclusions = listOf(
    "**/*Activity*", "**/*Screen*", "**/*Composable*",
    "**/di/**", "**/*_Factory*", "**/Hilt_*", "**/*_HiltModules*",
    "**/databinding/**", "**/generated/**",
    "**/*PagingSource*"   // only if the project has no custom load() logic
)
```

**Kover**:

```kotlin
// app/build.gradle.kts
kover {
    reports {
        filters {
            excludes {
                classes(
                    "R", "R$*", "BuildConfig", "Manifest*",
                    "*Test*", "*ComposableSingletons*", "*Preview*",
                    "*Hilt*", "*_MembersInjector*", "*_Factory*", "*_GeneratedInjector*",
                    "*Module", "*Module_*",
                    "*_Impl*",                 // Room
                    "*State", "*Event"         // plain state/event data holders
                )
                packages(
                    "dagger", "hilt_aggregated_deps",
                    "<base_package>.features.data.remote.request",
                    "<base_package>.features.data.remote.response",
                    "<base_package>.features.domain.entities"
                )
            }
        }
    }
}
```

### 6.4 Read the coverage report

```
Jacoco: app/build/reports/jacoco/.../html/index.html
Kover:  app/build/reports/kover/html/index.html
```

Red lines are uncovered. Add one test per red region until green.

---

## 7. Anti-patterns to Avoid

| Anti-pattern | Why it's bad | Fix |
|---|---|---|
| **Mocking the SUT** | Tests only prove the mocking library works. | Mock the SUT's dependencies, not the SUT itself. |
| **Happy-path-only** | All the bugs are in the failure path. | R2 — every method gets success + HTTP error tests. |
| **`is Resource.Error` only** | Misses the wrong error type/code. | Assert the error detail per the project's error model (R2a). |
| **Mocking `DataStore<Preferences>` directly** | Stubs lie about `edit` transactional semantics. | Mock the wrapper class (Tier 1) or use a real temp-file DataStore (Tier 2) — §5.4. |
| **`relaxed = true` on a verified dependency** (MockK) | Unstubbed calls silently return defaults; broken wiring passes. | Relaxed only for incidental deps; strict mocks + explicit stubs for everything the test verifies. |
| **Asserting fixture against fixture** (`assertEquals(expectedX(), expectedX())`) | Passes even if SUT returns garbage. | Compare the SUT's return / state against the expected fixture. |
| **Writing tests before reading the source** | Tests won't compile; wrong method signatures, wrong state field names. | Always read the source file first (§0.5). |
| **Silently adding to or rewriting existing tests** | Breaks other tests; loses history of intent. | Ask first (§0.6). |
| **Silently extending helper files** | Breaks other tests that rely on the old behaviour. | Propose the change to the developer; wait for confirmation. |
| **Real time / randomness** | Flaky around midnight. | Inject a `Clock` / `Random` interface. |
| **Tests that share mutable state** | Order-dependent; flaky in parallel runs. | Each test sets up its own state. |
| **Snapshot-asserting the entire UI state** | Adding any new field breaks every test. | Assert only on the fields the event was supposed to change. |
| **Assuming the Gradle test task name** | Wrong task → no tests run. | Discover the task with `./gradlew tasks --group verification` (§0.7). |
| **Mixing JUnit4 and JUnit5 annotations** | `@Before` + `@BeforeEach` in the same class mis-fire silently. | Pick one version per project (§0.2). |
| **Mixing Mockito and MockK** | Two mocking runtimes, double the learning surface, inconsistent failures. | Pick one per project (§0.2b). |
| **Mixed assertion imports** (`kotlin.test` + `org.junit.Assert` + `junit.framework`) | Inconsistent failure messages; `junit.framework` is JUnit 3 vintage. | One assertion library per project, consistently. |
| **`mockkStatic`/`mockkObject` without `unmockkAll()`** (MockK) | Static mocks leak across tests in the same JVM. | `unmockkAll()` in `@AfterEach`, or avoid static mocking via DI. |

---

## 8. Templates

Templates are split per mocking library under `codegen/templates/`. After detecting the
library (§0.2b), load **only** the matching set and follow it:

```
codegen/templates/
├── mockito/
│   ├── repository_test.md
│   ├── usecase_test.md
│   └── viewmodel_test.md
└── mockk/
    ├── repository_test.md
    ├── usecase_test.md
    └── viewmodel_test.md
```

The Mockito set assumes the one-class-per-SUT layout and a typed-error model; the MockK set
assumes the one-class-per-method layout, data-carrying errors, and Turbine. Those pairings
reflect the reference projects they came from, **not** requirements of the libraries — when
the detected project mixes traits (e.g. MockK + typed errors), keep the library syntax from
one template and the structure conventions detected in §0.2c–§0.4 and §5.0.

In every template, **replace every `Xxx` / `xxx` placeholder with actual names read from
the source files (§0.5) before writing the test.**

---

## 9. Coverage Verification

### Discover the test task first

```bash
./gradlew tasks --group verification
```

Use the task name returned (e.g. `testDebugUnitTest`, `testDevDebugUnitTest`) in all
commands below.

### Run unit tests

```bash
# All tests
./gradlew <testTask>

# Single package
./gradlew <testTask> --tests "<base_package>.features.*.xxx.*"

# Single class
./gradlew <testTask> --tests "<base_package>.XxxViewModelTest"
```

### Generate the coverage report

**Jacoco projects**:

```bash
./gradlew jacocoTestReport
open app/build/reports/jacoco/jacocoTestReport/html/index.html
```

**Kover projects**:

```bash
./gradlew koverHtmlReport          # human-readable
./gradlew koverXmlReport           # XML — what Sonar reads
open app/build/reports/kover/html/index.html
```

If the project feeds Sonar, check `app/build.gradle.kts` for
`sonar.coverage.jacoco.xmlReportPaths` — it usually points at the Kover/Jacoco XML report;
keep the path and the generating task in sync.

### CI gate (recommended)

```yaml
# Jacoco
- run: ./gradlew <testTask> jacocoTestReport jacocoCoverageVerification

# Kover
- run: ./gradlew <testTask> koverXmlReport koverVerify
```

The verification task asserts ≥ 0.90 line coverage on `data.remote.repository`,
`domain.usecases`, and the ViewModel packages. Full task configuration is project-specific.

---

## 10. Worked Example — Leave Feature

(Shown in the one-class-per-method layout with a `dummy/` fixture object; transpose to the
one-class-per-SUT + `Source.kt` layout if that is what the project uses.)

### 10.1 Files to create

```
app/src/test/java/<base_package>/features/
├── data/remote/repositories/leave/
│   ├── LeaveRepositoryGetLeaveBalancesTest.kt
│   ├── LeaveRepositoryGetLeaveHistoryTest.kt
│   ├── LeaveRepositorySubmitLeaveRequestTest.kt
│   ├── LeaveRepositoryUpdateLeaveRequestTest.kt
│   ├── LeaveRepositoryCancelLeaveRequestTest.kt
│   └── dummy/LeaveRepositoryDummy.kt
├── domain/usecases/leave/
│   ├── LeaveUseCasesGetLeaveBalancesTest.kt        (3)
│   ├── LeaveUseCasesGetLeaveHistoryTest.kt         (3)
│   ├── LeaveUseCasesSubmitLeaveRequestTest.kt      (3)
│   ├── LeaveUseCasesUpdateLeaveRequestTest.kt      (3)
│   ├── LeaveUseCasesCancelLeaveRequestTest.kt      (3)
│   └── LeaveUseCasesDeleteLeaveDocumentTest.kt     (3)
└── viewmodels/leave/main/
    ├── LeaveViewModelBaseTest.kt                   (abstract: mocks + rule + baseSetup)
    ├── LeaveViewModelInitTest.kt
    ├── LeaveViewModelFetchTest.kt
    ├── LeaveViewModelEventTest.kt
    ├── LeaveViewModelSubmitTest.kt
    ├── LeaveViewModelCancelTest.kt
    ├── LeaveViewModelFileTest.kt
    └── LeaveViewModelTabTest.kt
```

### 10.2 LeaveRepository — per-method test files

| Method | Tests |
|---|---|
| `getLeaveBalances()` | (1) success with data; (2) success with empty list; (3) 401 error — `statusCode`+`message`; (4) 500 error; (5) network failure; (6) endpoint shape (`GET` + path) |
| `getLeaveHistory()` | success; error; endpoint shape |
| `submitLeaveRequest()` | success — multipart body contains required fields, omits null `start_time`/`end_time`; success — with times set, both appear; http error |
| `updateLeaveRequest()` | success — `id` reaches URL path; http error |
| `cancelLeaveRequest()` | success — `id` reaches URL path; http error |

Skip `getLeaveHistoryPaged` / `invalidateLeavePagingSource` (framework glue —
coverage-exclude), but test any custom `PagingSource.load()` separately (§5.1).

### 10.3 Use cases — ~3 tests each

Each gets: success pass-through, error pass-through, `exactly = 1` delegation check.

### 10.4 LeaveViewModel — enumerate `LeaveEvent.kt` first

| Event category | Events | Tests |
|---|---|---|
| Load | `LoadLeaveBalance`, `LoadLeaveHistory`, `RefreshHistory` | 6 |
| Field updates | `UpdateStartDate`, `UpdateEndDate`, `UpdateStartTime`, `UpdateEndTime`, `SelectLeaveType`, `UpdateReason` | 6 |
| Submit / Update | `SubmitLeaveRequest`, `UpdateLeaveRequest` | 6 |
| Cancel / Delete | `CancelLeaveRequest`, `DeleteDocument` | 4 |
| Document attach | `AttachDocument` | 1 |
| UI toggles | `ToggleEditMode`, `ShowDatePicker`, `DismissDialog` | 3 |
| Init | Initial balance load side-effect | 1–2 |

**Expected total: ~22–26 tests**, summed across the split concern files.

### 10.5 Running the suite

```bash
./gradlew tasks --group verification           # discover task name first
./gradlew <testTask> --tests "<base_package>.features.*.leave.*"
./gradlew koverHtmlReport                      # or jacocoTestReport
```

---

## 11. Reuse in Other Projects

1. Copy this file **and the `codegen/templates/` directory** into the new project.
2. Follow §0 (onboarding steps) — base package, JUnit version, mocking library, error
   model, conventions.
3. Create the helper files from §4 under `app/src/test/…/helper/`.
4. Add coverage exclusions (§6.3) for the project's coverage tool.
5. Wire the coverage verification task into CI (§9).
6. Apply the matching template set (§8) per feature.

Rough time estimates once the harness is in place:

- Repository: ~30 min for 6–10 tests.
- Use cases: ~5 min per use case (2–3 tests).
- ViewModel: ~5 min per event branch.

A medium feature (1 repo, 5 use cases, 1 viewmodel with 15 events) → ~3 hours, hits 90%+
coverage.