# RepositoryTest template — Mockito

Layout: one test class per repository (one-class-per-SUT). Error model: typed `AppError`
with `TestAssertHelper` (`assertSuccess`, `assertHttpError`). If the detected project uses
data-carrying errors or the one-class-per-method layout, keep the Mockito syntax but follow
the detected conventions instead (rules §0.2c, §5.0).

Copy-paste, rename, fill in. **Replace every `Xxx` / `xxx` placeholder with actual names
read from the source files (rules §0.5) before writing the test.**

```kotlin
package <base_package>.features.data.remote.repository.xxx

import <base_package>.base.BaseTest
import <base_package>.helper.MockResponseFactory
import <base_package>.helper.assertHttpError
import <base_package>.helper.assertSuccess
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.kotlin.*

class XxxRepositoryTest : BaseTest() {
    private lateinit var repo: XxxRepository
    private lateinit var api: XxxApi
    private val daoX: XxxDao = mock()

    @Before
    override fun setup() {
        super.setup()
        Dispatchers.setMain(testDispatcher)
        api = createApi()
        whenever(databaseManager.xxxDao).thenReturn(daoX)
        repo = XxxRepository(testDispatcher, api, databaseManager, mockDeps)
    }

    @After
    override fun tearDown() {
        Dispatchers.resetMain()
        super.tearDown()
    }

    @Test fun `getXxx success returns data and caches result`() = runTest {
        mockWebServer.enqueue(MockResponseFactory.success(expectedXxx()))

        val result = repo.getXxx()

        result.assertSuccess()
        verify(daoX).insertAll(expectedXxx())
    }

    @Test fun `getXxx http error does not touch cache`() = runTest {
        mockWebServer.enqueue(MockResponseFactory.internalServerError())

        val result = repo.getXxx()

        result.assertHttpError(500)
        verify(daoX, never()).insertAll(any())
    }

    // Add one test per additional branch found in the source file
}
```

Per-method checklist (rules §5.1): success (+ cache side effects), HTTP error (+ no side
effects), network failure, endpoint shape via `takeRequest()`, branch-fillers.

For methods that build request bodies, assert the body through MockWebServer:

```kotlin
@Test fun `submitXxx omits null fields from multipart body`() = runTest {
    mockWebServer.enqueue(MockResponseFactory.success(expectedXxx()))

    repo.submitXxx(sampleXxxRequest(), document = null)

    val body = mockWebServer.takeRequest().body.readUtf8()
    assertTrue(body.contains("name=\"start_date\""))
    assertFalse(body.contains("name=\"start_time\""))  // null → omitted
}
```