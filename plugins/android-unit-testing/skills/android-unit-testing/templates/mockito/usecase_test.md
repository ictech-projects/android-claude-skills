# UseCaseTest template — Mockito

No base class needed — use cases only need a mocked repository.

Copy-paste, rename, fill in. **Replace every `Xxx` / `xxx` placeholder with actual names
read from the source files (rules §0.5) before writing the test.**

```kotlin
package <base_package>.features.domain.usecases.xxx

import <base_package>.core.models.AppError
import <base_package>.core.models.Resource
import <base_package>.features.data.remote.repository.xxx.XxxRepository
import <base_package>.features.data.remote.repository.xxx.expectedXxx
import <base_package>.helper.assertHttpError
import <base_package>.helper.assertSuccess
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import org.mockito.kotlin.*

class GetXxxUseCaseTest {
    private val repo: XxxRepository = mock()
    private val useCase = GetXxxUseCase(repo)

    @Test fun `success passes through from repository`() = runTest {
        val expected = Resource.Success(expectedXxx())
        whenever(repo.getXxx()).thenReturn(expected)

        val result = useCase()

        assertEquals(expected, result)
        verify(repo).getXxx()
    }

    @Test fun `error passes through from repository`() = runTest {
        whenever(repo.getXxx())
            .thenReturn(Resource.Error(AppError.Http(500, "Server Error", emptyMap())))

        val result = useCase()

        result.assertHttpError(500)
    }
}
```

Use cases that orchestrate multiple repositories also need (rules §5.2): call-order
verification with `inOrder(repoA, repoB)`, a test that the second call uses data from the
first result, and a test that the second call is skipped when the first fails.