# Examples — ViewModel / UiState / Event / FieldState (R11, R12)

Load when generating any ViewModel-side file. Canonical style: `LeaveViewModel.kt`.
One class per file — see the file split at the bottom.

## ViewModel declaration + state exposure (R11.1, R11.2)

```kotlin
// File: features/presentation/screen/leave/LeaveViewModel.kt
package com.ictechnology.app.features.presentation.screen.leave

@HiltViewModel
class LeaveViewModel @Inject constructor(
    @param:ApplicationContext private val context      : Context,
    @param:IoDispatcher       private val ioDispatcher : CoroutineDispatcher,
    private val submitUseCase : SubmitLeaveRequestUseCase,
    private val validator     : LeaveRequestValidator,
) : ViewModel() {

    /*region: Screen State*/
    private val _uiState = MutableStateFlow(LeaveUiState())
    val uiState = _uiState.asStateFlow()                 // read-only to UI; never expose mutable

    private val _fieldState = MutableStateFlow(LeaveRequestFieldState())
    val fieldState = _fieldState.asStateFlow()
    /*endregion*/

    fun onEvent(event: LeaveEvent) { /* see below */ }
    // ← NO UiState/Event/FieldState/enum declarations in this file (R12.0)
}
```

## onEvent — single entry point (R11.3, STRICT)

```kotlin
fun onEvent(leaveEvent: LeaveEvent) {
    viewModelScope.launch {                              // MUST wrap in launch
        when (leaveEvent) {                             // exhaustive, NO else
            // Field inputs — update FieldState inline
            is LeaveEvent.StartDateInput   -> _fieldState.update { it.copy(startDate = leaveEvent.startDate) }
            is LeaveEvent.LeaveReasonInput -> _fieldState.update { it.copy(leaveReason = leaveEvent.reason) }

            // Async actions — delegate to private fns
            LeaveEvent.Submit              -> submitLeaveRequest()
            LeaveEvent.FetchLeaveBalance   -> fetchLeaveBalance()

            // Dialog control — update UiState inline
            LeaveEvent.DismissDialog       -> _uiState.update { it.copy(leaveDialog = LeaveDialog.Default) }

            // UI-only — listed here, handled in Screen composable
            LeaveEvent.FileUploadClick     -> Unit //Handle on UI
            is LeaveEvent.DocumentDownload -> Unit //Handle on UI
        }
    }
}
```

```kotlin
// ❌ FORBIDDEN — public per-action fns / no launch wrapper / else catch-all
fun onSubmitClicked() { }                                // ❌ must be LeaveEvent.Submit
fun onEvent(e: LeaveEvent) { when (e) { else -> {} } }   // ❌ no launch, ❌ else
```

Permitted public fns beyond `onEvent()` (R11.3.4): `initEditScreen(id)`, `setSelectedFile(uri)`,
`selectItem(item)`, `setDialog(dialog)`, `resetFormState()`, `byPassLockScreen()`.

## State update, coroutines, dialog, validation, Resource (R11.4–R11.8)

```kotlin
_fieldState.update { it.copy(startDate = event.startDate) }        // R11.4 — never _state.value = …

private fun submitLeaveRequest() {
    viewModelScope.launch {
        setLeaveDialog(LeaveDialog.Loading)                         // R11.6
        val document = withContext(ioDispatcher) {                  // R11.5 heavy I/O off main
            fieldState.value.selectedFileUri?.toMultipart(context, "document")
        }
        val error = validator.validate(/* fields */)                // R11.7 delegate to validator
        if (error != null) { setLeaveDialog(LeaveDialog.Error(message = context.getString(error.toMessageRes()))); return@launch }

        when (val result = submitUseCase(request, document)) {      // R11.8 Resource when, no try/catch
            is Resource.Success -> setLeaveDialog(LeaveDialog.Success(title = "", message = ""))
            is Resource.Error   -> setLeaveDialog(LeaveDialog.Error(message = result.error.asString(context)))
        }
    }
}

fun setLeaveDialog(dialog: LeaveDialog) { _uiState.update { it.copy(leaveDialog = dialog) } }
```

## File split — one class per file (R12.2, R12.4–R12.6)

```kotlin
// File: LeaveUiState.kt  — UiState + Dialog (R12.4)
package com.ictechnology.app.features.presentation.screen.leave
data class LeaveUiState(
    val leaveDialog : LeaveDialog = LeaveDialog.Default,
    val selectedTab : LeaveTab    = LeaveTab.REQUEST,
)
sealed class LeaveDialog {
    object Default : LeaveDialog(); object Loading : LeaveDialog()
    data class Success(val title: String, val message: String) : LeaveDialog()
    data class Error  (val title: String, val message: String) : LeaveDialog()
}
```

```kotlin
// File: LeaveEvent.kt  — Event only (R12.6)
package com.ictechnology.app.features.presentation.screen.leave
sealed class LeaveEvent {
    data class StartDateInput(val startDate: String)   : LeaveEvent()
    data class LeaveReasonInput(val reason: String)    : LeaveEvent()
    object Submit                                      : LeaveEvent()
    object DismissDialog                               : LeaveEvent()
    object FileUploadClick                             : LeaveEvent() // Handle on UI
}
```

```kotlin
// File: LeaveRequestFieldState.kt  — form field state only, if has_form (R12.5)
package com.ictechnology.app.features.presentation.screen.leave
data class LeaveRequestFieldState(
    val startDate       : String = "",
    val leaveReason     : String = "",
    val selectedFileUri : Uri?   = null,
)
```

Enums each get their own file: `LeaveTab.kt`, `LeaveDurationType.kt`.

## Self-check before emitting VM code (R12.7)
VM file = class only · no data/sealed/enum inside it · UiState/FieldState/Event/enums each in own
file · all share one package · VM imports them. Any miss → regenerate.
