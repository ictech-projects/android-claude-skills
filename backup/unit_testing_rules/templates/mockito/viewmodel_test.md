# ViewModelTest template — Mockito

Layout: one test class per ViewModel. Dispatcher: `UnconfinedTestDispatcher` as Main, so
`viewModelScope` coroutines run eagerly and `uiState.value` reflects them immediately.

Copy-paste, rename, fill in. **Replace every `Xxx` / `xxx` placeholder with actual names
read from the source files (rules §0.5) before writing the test.** Enumerate every `Event`
subclass first — that is the minimum test count (rules §6.2).

## JUnit 4 setup

```kotlin
class XxxViewModelTest : BaseTest() {
    private val loadUseCase:   LoadXxxUseCase   = mock()
    private val submitUseCase: SubmitXxxUseCase = mock()
    private val validator:     XxxValidator     = mock()

    @Before override fun setup()    { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After  override fun tearDown() { Dispatchers.resetMain() }

    private fun newViewModel() = XxxViewModel(
        loadUseCase, submitUseCase, validator, mockAuthSessionManager, testDispatcher
    )
}
```

## JUnit 5 setup

```kotlin
class XxxViewModelTest : BaseTest() {
    @JvmField @RegisterExtension
    val mainDispatcherRule = MainDispatcherRule(UnconfinedTestDispatcher())

    private val loadUseCase:   LoadXxxUseCase   = mock()
    private val submitUseCase: SubmitXxxUseCase = mock()
    private val validator:     XxxValidator     = mock()

    private fun newViewModel() = XxxViewModel(
        loadUseCase, submitUseCase, validator, mockAuthSessionManager, testDispatcher
    )
}
```

## Test body (JUnit4 imports shown)

```kotlin
package <base_package>.features.presentation.screens.xxx

import <base_package>.base.BaseTest
import <base_package>.core.models.AppError
import <base_package>.core.models.Resource
import <base_package>.features.data.remote.repository.xxx.expectedXxx
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.kotlin.*

class XxxViewModelTest : BaseTest() {
    private val loadUseCase:   LoadXxxUseCase   = mock()
    private val submitUseCase: SubmitXxxUseCase = mock()
    private val validator:     XxxValidator     = mock()

    @Before override fun setup()    { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After  override fun tearDown() { Dispatchers.resetMain() }

    private fun newViewModel() = XxxViewModel(
        loadUseCase, submitUseCase, validator, mockAuthSessionManager, testDispatcher
    )

    // --- Init ---

    @Test fun `init loads xxx automatically`() = runTest {
        whenever(loadUseCase()).thenReturn(Resource.Success(expectedXxx()))
        val vm = newViewModel()
        assertEquals(expectedXxx(), vm.uiState.value.items)
    }

    // --- Load events ---

    @Test fun `LoadXxx success populates state`() = runTest {
        whenever(loadUseCase()).thenReturn(Resource.Success(expectedXxx()))
        val vm = newViewModel()

        vm.onEvent(XxxEvent.LoadXxx)

        assertEquals(expectedXxx(), vm.uiState.value.items)
        assertFalse(vm.uiState.value.isLoading)
    }

    @Test fun `LoadXxx error sets errorMessage`() = runTest {
        whenever(loadUseCase())
            .thenReturn(Resource.Error(AppError.Http(500, "boom", emptyMap())))
        val vm = newViewModel()

        vm.onEvent(XxxEvent.LoadXxx)

        assertNotNull(vm.uiState.value.errorMessage)
    }

    // --- Field updates ---

    @Test fun `UpdateName sets name in field state`() = runTest {
        val vm = newViewModel()
        vm.onEvent(XxxEvent.UpdateName("Alice"))
        assertEquals("Alice", vm.fieldState.value.name)
    }

    // --- Submit events ---

    @Test fun `Submit with invalid form does not call use case`() = runTest {
        whenever(validator.validate(any())).thenReturn(listOf(NameRequired))
        val vm = newViewModel()

        vm.onEvent(XxxEvent.Submit)

        verify(submitUseCase, never()).invoke(any())
        assertTrue(vm.fieldState.value.hasErrors)
    }

    @Test fun `Submit with valid form calls use case with mapped args`() = runTest {
        whenever(validator.validate(any())).thenReturn(emptyList())
        whenever(submitUseCase(any())).thenReturn(Resource.Success(expectedXxx()))
        val vm = newViewModel()
        vm.onEvent(XxxEvent.UpdateName("Alice"))

        vm.onEvent(XxxEvent.Submit)

        verify(submitUseCase).invoke(argThat { name == "Alice" })
    }

    @Test fun `Submit with valid form but server error sets errorMessage`() = runTest {
        whenever(validator.validate(any())).thenReturn(emptyList())
        whenever(submitUseCase(any()))
            .thenReturn(Resource.Error(AppError.Http(422, "Unprocessable", emptyMap())))
        val vm = newViewModel()

        vm.onEvent(XxxEvent.Submit)

        assertNotNull(vm.uiState.value.errorMessage)
    }

    // Add one test per remaining Event subclass found in XxxEvent.kt
}
```