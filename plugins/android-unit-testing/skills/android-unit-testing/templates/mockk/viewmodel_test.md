# ViewModelTest template — MockK

Derived from this project's real tests (`LeaveViewModelBaseTest`,
`HomeViewModelLeaveBalancesTest`). Layout: **one abstract base test per ViewModel** owning
the mocks, the `MainDispatcherRule`, and ViewModel construction; plus **one concrete test
class per concern** (`XxxViewModelSubmitTest`, `XxxViewModelTabTest`, …). Dispatcher:
`MainDispatcherRule()` with its default `StandardTestDispatcher`, asserting flows through
**Turbine**. These are conventions of this reference project, not MockK requirements —
follow the detected project's layout (rules §5.0, R6).

Enumerate every `Event` subclass first — that is the minimum test count *summed across the
split files* (rules §6.2). **Replace every `Xxx` / `xxx` placeholder with actual names read
from the source files (rules §0.5).**

## 1. Abstract base test — `XxxViewModelBaseTest.kt`

Stub everything the ViewModel's `init {}` touches **before** constructing it.

```kotlin
package <base_package>.features.viewmodels.xxx

import android.content.Context
import androidx.paging.PagingData
import <base_package>.features.data.remote.repositories.xxx.dummy.XxxRepositoryDummy
import <base_package>.features.domain.usecases.xxx.XxxUseCases
import <base_package>.features.domain.validator.xxx.XxxValidator
import <base_package>.helper.MainDispatcherRule
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.extension.RegisterExtension

abstract class XxxViewModelBaseTest {

    @RegisterExtension
    val mainDispatcherRule = MainDispatcherRule()

    val xxxUseCases: XxxUseCases = mockk()
    val validator: XxxValidator = mockk()
    val context: Context = mockk()              // relaxed = true only if the VM calls it incidentally

    lateinit var viewModel: XxxViewModel

    @BeforeEach
    fun baseSetup() {
        // Stub init {} dependencies BEFORE construction, e.g. a paged flow:
        every { xxxUseCases.getPagedXxxHistory() } returns flowOf(
            PagingData.from(listOf(XxxRepositoryDummy.historyItem))
        )
        viewModel = XxxViewModel(
            context = context,
            xxxUseCases = xxxUseCases,
            validator = validator,
        )
    }
}
```

## 2. Concern files — one per event group

### Load events, with Turbine (`XxxViewModelFetchTest.kt`)

```kotlin
package <base_package>.features.viewmodels.xxx

import app.cash.turbine.test
import <base_package>.features.data.remote.repositories.xxx.dummy.XxxRepositoryDummy
import <base_package>.features.data.remote.utils.Resource
import <base_package>.helper.MockResponseFactory
import io.mockk.coEvery
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class XxxViewModelFetchTest : XxxViewModelBaseTest() {

    // region: Success
    @Test
    fun `should emit mapped items when getYyy succeeds`() = runTest {
        coEvery { xxxUseCases.getYyy() } returns MockResponseFactory.successResource(
            listOf(XxxRepositoryDummy.yyy)
        )

        viewModel.yyyState.test {
            skipItems(1)                          // skip the StateFlow's initial value
            viewModel.onEvent(XxxEvent.GetYyy)
            val result = awaitItem()
            assertEquals(1, result.size)
            cancelAndIgnoreRemainingEvents()
        }
    }
    // endregion

    // region: Error — the high-value negative assertion
    @Test
    fun `should not update state when getYyy fails`() = runTest {
        coEvery { xxxUseCases.getYyy() } returns Resource.Error("Network error")

        viewModel.yyyState.test {
            skipItems(1)
            viewModel.onEvent(XxxEvent.GetYyy)
            expectNoEvents()
            cancelAndIgnoreRemainingEvents()
        }
    }
    // endregion
}
```

### Field-update / toggle events (`XxxViewModelEventTest.kt`)

Simple final-state checks don't need Turbine:

```kotlin
class XxxViewModelEventTest : XxxViewModelBaseTest() {

    @Test
    fun `UpdateName sets name in field state`() = runTest {
        viewModel.onEvent(XxxEvent.UpdateName("Alice"))
        assertEquals("Alice", viewModel.fieldState.value.name)
    }

    @Test
    fun `DismissDialog hides the dialog`() = runTest {
        viewModel.onEvent(XxxEvent.ShowDialog)
        viewModel.onEvent(XxxEvent.DismissDialog)
        assertFalse(viewModel.uiState.value.isDialogVisible)
    }
}
```

### Submit events incl. the validation gate (`XxxViewModelSubmitTest.kt`)

```kotlin
class XxxViewModelSubmitTest : XxxViewModelBaseTest() {

    @Test
    fun `submit with invalid form does not call use case`() = runTest {
        every { validator.validate(any()) } returns listOf(NameRequired)

        viewModel.onEvent(XxxEvent.Submit)

        coVerify(exactly = 0) { xxxUseCases.submitYyy(any()) }
        assertTrue(viewModel.fieldState.value.hasErrors)
    }

    @Test
    fun `submit with valid form calls use case with mapped args`() = runTest {
        every { validator.validate(any()) } returns emptyList()
        coEvery { xxxUseCases.submitYyy(any()) } returns
            MockResponseFactory.successResource(XxxRepositoryDummy.yyy)
        viewModel.onEvent(XxxEvent.UpdateName("Alice"))

        viewModel.onEvent(XxxEvent.Submit)

        coVerify { xxxUseCases.submitYyy(match { it.name == "Alice" }) }
    }

    @Test
    fun `submit with valid form but server error sets errorMessage`() = runTest {
        every { validator.validate(any()) } returns emptyList()
        coEvery { xxxUseCases.submitYyy(any()) } returns
            Resource.Error("Unprocessable", statusCode = 422)

        viewModel.onEvent(XxxEvent.Submit)

        assertNotNull(viewModel.uiState.value.errorMessage)
    }
}
```

### Init side-effects (`XxxViewModelInitTest.kt`)

The base test already constructs the ViewModel, so `init {}` has run — assert its effects,
and `coVerify` which use cases it triggered:

```kotlin
class XxxViewModelInitTest : XxxViewModelBaseTest() {

    @Test
    fun `init collects paged history`() = runTest {
        verify(exactly = 1) { xxxUseCases.getPagedXxxHistory() }
    }
}
```

If a test needs *different* init stubs than `baseSetup()` provides, re-stub and reconstruct
the ViewModel inside that test rather than widening the base stubs.

## Turbine rules of thumb (rules §5.3a)

- `skipItems(1)` for the StateFlow initial value; adjust if `init {}` already emitted.
- `expectNoEvents()` proves "error did not corrupt state".
- End every `test { }` with `cancelAndIgnoreRemainingEvents()`.
- ViewModel tests stub use cases with `MockResponseFactory.successResource(...)` /
  `Resource.Error(...)` — they never touch MockWebServer.
- For `Flow<PagingData<T>>`, assert wiring (one emission) not page contents.