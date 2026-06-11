# RepositoryTest template — MockK

Derived from this project's real tests (`LeaveRepositoryGetLeaveBalancesTest`). Layout:
**one test class per repository method**, all extending the shared `BaseRepositoryTest`
harness. Error model: data-carrying `Resource.Error(message, statusCode, errors)` — assert
`statusCode`/`message` directly. If the detected project uses one-class-per-SUT or typed
errors, keep the MockK syntax but follow the detected conventions (rules §0.2c, §5.0).

Copy-paste, rename, fill in. **Replace every `Xxx` / `xxx` / `getYyy` placeholder with
actual names read from the source files (rules §0.5) before writing the test.**

## Fixture object — `dummy/XxxRepositoryDummy.kt` (one per feature)

```kotlin
package <base_package>.features.data.remote.repositories.xxx.dummy

object XxxRepositoryDummy {
    val yyy = YyyResponse(
        id = 1,
        name = "Sample",
        // fill every field the tests assert on; specialize per-test with .copy(...)
    )
}
```

## Test file — one per repository method

```kotlin
package <base_package>.features.data.remote.repositories.xxx

import <base_package>.features.data.remote.apis.xxx.XxxApi
import <base_package>.features.data.remote.repositories.xxx.dummy.XxxRepositoryDummy
import <base_package>.features.data.remote.utils.Resource
import <base_package>.helper.BaseRepositoryTest
import <base_package>.helper.MockResponseFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class XxxRepositoryGetYyyTest : BaseRepositoryTest() {

    private lateinit var repository: XxxRepository

    @BeforeEach
    override fun setUp() {
        super.setUp()
        repository = XxxRepository(
            coroutineDispatcher = Dispatchers.Unconfined,
            context             = mockContext,
            xxxApi              = createApi<XxxApi>(),
            authSessionManager  = mockAuthSessionManager
        )
    }

    // =========================================================================
    // 1. Success
    // =========================================================================

    @Test
    fun `getYyy returns Resource Success when api returns 200 with data`() = runTest {
        val data = listOf(XxxRepositoryDummy.yyy)
        mockWebServer.enqueue(MockResponseFactory.success(data))

        val result = repository.getYyy()

        assertTrue(result is Resource.Success)
        assertNotNull(result.data?.data)
    }

    @Test
    fun `getYyy returns Resource Success when api returns empty list`() = runTest {
        mockWebServer.enqueue(MockResponseFactory.success(emptyList<YyyResponse>()))

        val result = repository.getYyy()

        assertTrue(result is Resource.Success)
        assertEquals(emptyList<YyyResponse>(), result.data?.data)
    }

    // =========================================================================
    // 2. HTTP error responses — 401, 500
    // =========================================================================

    @Test
    fun `getYyy returns Resource Error when api returns 401`() = runTest {
        mockWebServer.enqueue(MockResponseFactory.unauthorized())

        val result = repository.getYyy()

        assertTrue(result is Resource.Error)
        assertEquals(401, result.statusCode)
        assertEquals("Unauthorized", result.message)
    }

    @Test
    fun `getYyy returns Resource Error when api returns 500`() = runTest {
        mockWebServer.enqueue(MockResponseFactory.internalServerError())

        val result = repository.getYyy()

        assertTrue(result is Resource.Error)
        assertEquals(500, result.statusCode)
    }

    // =========================================================================
    // 3. Network failure
    // =========================================================================

    @Test
    fun `getYyy returns Resource Error on network failure`() = runTest {
        mockWebServer.enqueue(MockResponseFactory.networkFailure())

        val result = repository.getYyy()

        assertTrue(result is Resource.Error)
        assertEquals(0, result.statusCode)   // confirm the project's mapping (rules §0.2c)
    }

    // =========================================================================
    // 4. Verify correct endpoint is called
    // =========================================================================

    @Test
    fun `getYyy hits GET yyy endpoint`() = runTest {
        mockWebServer.enqueue(MockResponseFactory.success(emptyList<YyyResponse>()))

        repository.getYyy()

        val request = mockWebServer.takeRequest()
        assertEquals("GET", request.method)
        assertTrue(request.path?.contains("yyy-endpoint") == true)
    }
}
```

## Methods that build request bodies

Assert the body through MockWebServer in the same per-method file:

```kotlin
@Test
fun `submitYyy omits null time fields from multipart body`() = runTest {
    mockWebServer.enqueue(MockResponseFactory.success(XxxRepositoryDummy.yyy))

    repository.submitYyy(XxxRepositoryDummy.sampleRequest, document = null)

    val body = mockWebServer.takeRequest().body.readUtf8()
    assertTrue(body.contains("name=\"start_date\""))
    assertTrue(body.contains("2026-06-01"))
    kotlin.test.assertFalse(body.contains("name=\"start_time\""))  // null → omitted
}
```

## DAO / cache side effects

When the repository writes to a DAO on success, stub the DAO on `mockDatabaseManager` and
verify (strict mock — see the `relaxed` policy in rules §3.0):

```kotlin
private val mockYyyDao = mockk<YyyDao>(relaxUnitFun = true)

@BeforeEach
override fun setUp() {
    super.setUp()
    every { mockDatabaseManager.yyyDao } returns mockYyyDao
    // ...
}

@Test fun `getYyy caches result on success`() = runTest {
    mockWebServer.enqueue(MockResponseFactory.success(listOf(XxxRepositoryDummy.yyy)))

    repository.getYyy()

    coVerify(exactly = 1) { mockYyyDao.insertAll(any()) }
}

@Test fun `getYyy does not touch cache on http error`() = runTest {
    mockWebServer.enqueue(MockResponseFactory.internalServerError())

    repository.getYyy()

    coVerify(exactly = 0) { mockYyyDao.insertAll(any()) }
}
```

Per-method checklist (rules §5.1): success (+ empty-list variant where the response is a
list), 401 + 500 errors, network failure, endpoint shape, body shape, branch-fillers.
Skip `Pager(...)` wiring; test custom `PagingSource.load()` in its own file.