# UseCaseTest template — MockK

Derived from this project's real tests (`LeaveUseCasesGetLeaveBalancesTest`,
`NotificationsUseCaseSyncFcmTokenTest`). Layout: **one test class per use-case method**.
No base class needed — use cases only need mocked dependencies.

Copy-paste, rename, fill in. **Replace every `Xxx` / `xxx` / `getYyy` placeholder with
actual names read from the source files (rules §0.5) before writing the test.**

## Thin delegating use case (the common case — 3 tests)

```kotlin
package <base_package>.features.domain.usecases.xxx

import <base_package>.features.data.remote.repositories.xxx.XxxRepository
import <base_package>.features.data.remote.response.ApiResponse
import <base_package>.features.data.remote.utils.Resource
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

class XxxUseCasesGetYyyTest {

    private val mockRepository = mockk<XxxRepository>()
    private lateinit var useCase: XxxUseCases

    private val successResult = Resource.Success(
        ApiResponse(200, true, "OK", listOf<YyyResponse>())
    )

    private val errorResult = Resource.Error<ApiResponse<List<YyyResponse>>>(
        message = "Error",
        statusCode = 0
    )

    @BeforeEach
    fun setUp() {
        useCase = XxxUseCases(mockRepository)
    }

    // =========================================================================
    // 1. Delegates to repository and returns result
    // =========================================================================

    @Test
    fun `getYyy returns Resource Success from repository`() = runTest {
        coEvery { mockRepository.getYyy() } returns successResult

        val result = useCase.getYyy()

        assertEquals(successResult, result)
    }

    @Test
    fun `getYyy returns Resource Error from repository`() = runTest {
        coEvery { mockRepository.getYyy() } returns errorResult

        val result = useCase.getYyy()

        assertEquals(errorResult, result)
    }

    // =========================================================================
    // 2. Verify correct repository method is called
    // =========================================================================

    @Test
    fun `getYyy calls repository exactly once`() = runTest {
        coEvery { mockRepository.getYyy() } returns successResult

        useCase.getYyy()

        coVerify(exactly = 1) { mockRepository.getYyy() }
    }
}
```

For non-suspend flow accessors (e.g. paged history), use `every`/`verify` instead of the
`co` variants:

```kotlin
@Test
fun `getPagedYyyHistory calls repository`() {
    every { mockRepository.getYyyHistoryPaged() } returns flowOf(PagingData.empty())

    useCase.getPagedYyyHistory()

    verify(exactly = 1) { mockRepository.getYyyHistoryPaged() }
}
```

## Orchestrating use case (multiple deps / branching — one test per branch)

Pattern from `NotificationsUseCaseSyncFcmTokenTest`: the use case reads a local store,
short-circuits on preconditions, calls the repository, and writes back on success. Mock the
store **wrapper**, never `DataStore` itself (rules §5.4).

```kotlin
class XxxUseCaseSyncZzzTest {

    private val mockRepository = mockk<XxxRepository>()
    private val mockStore = mockk<ZzzStore>(relaxed = true)   // relaxed OK: writes verified explicitly below
    private lateinit var useCase: XxxUseCase

    @BeforeEach
    fun setUp() {
        useCase = XxxUseCase(mockRepository, mockStore)
    }

    @Test
    fun `syncZzz short-circuits when nothing to sync`() = runTest {
        coEvery { mockStore.getToken() } returns null

        val result = useCase.syncZzz()

        assertEquals(true, (result as Resource.Success).data)
        coVerify(exactly = 0) { mockRepository.updateToken(any()) }   // precondition gate
    }

    @Test
    fun `syncZzz updates and marks synced on success`() = runTest {
        coEvery { mockStore.getToken() } returns "token"
        coEvery { mockStore.isSynced() } returns false
        coEvery { mockRepository.updateToken("token") } returns Resource.Success(
            ApiResponse(200, true, "OK", ZzzData("token_123"))
        )

        val result = useCase.syncZzz()

        assertEquals(true, (result as Resource.Success).data)
        coVerify(exactly = 1) { mockRepository.updateToken("token") }
        coVerify(exactly = 1) { mockStore.markSynced() }
    }

    @Test
    fun `syncZzz returns error and does not mark synced when repository fails`() = runTest {
        coEvery { mockStore.getToken() } returns "token"
        coEvery { mockStore.isSynced() } returns false
        coEvery { mockRepository.updateToken("token") } returns Resource.Error("Failed")

        val result = useCase.syncZzz()

        assertEquals("Failed", (result as Resource.Error).message)
        coVerify(exactly = 0) { mockStore.markSynced() }
    }
}
```

When call **order** matters between two dependencies, add a `coVerifyOrder { … }` test
(rules §5.2).