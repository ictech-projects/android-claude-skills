# Jetpack Compose UI Generation — AI Agent Guidelines

> **Version:** 2.4.0
> **Purpose:** This document defines the rules, standards, and constraints that an AI agent must follow when generating Jetpack Compose UI code for Android projects.
> **Reference:** [Android Official Compose Documentation](https://developer.android.com/develop/ui/compose/documentation)

---

## Rule 1 — Use Jetpack Compose with Official Android Guidelines

### 1.1 Toolkit Requirement
- All UI code **must** be written in **Jetpack Compose**.
- Do **not** generate XML layouts (`layout/*.xml`), `View`-based code, or any hybrid `AndroidView` wrappers unless explicitly requested.
- Always use the **latest stable Compose BOM** as the version reference.

```kotlin
// build.gradle.kts — always use BOM for version alignment
implementation(platform("androidx.compose:compose-bom:2024.09.00"))
implementation("androidx.compose.ui:ui")
implementation("androidx.compose.material3:material3")
implementation("androidx.compose.ui:ui-tooling-preview")
debugImplementation("androidx.compose.ui:ui-tooling")
```

### 1.2 Official API Usage
- Only use APIs and components documented in the [official Android developer guide](https://developer.android.com/develop/ui/compose).
- Do **not** use deprecated Compose APIs (e.g. `androidx.compose.material` — prefer `material3`).
- Follow naming, parameter ordering, and composable patterns as demonstrated in the [official Compose samples](https://github.com/android/compose-samples).

### 1.3 Reference Sources (in priority order)
1. [Jetpack Compose official documentation](https://developer.android.com/develop/ui/compose/documentation)
2. [Now in Android (official sample)](https://github.com/android/nowinandroid)
3. [Jetpack Compose samples](https://github.com/android/compose-samples)
4. [Material 3 for Compose](https://m3.material.io/develop/android/jetpack-compose)

---

## Rule 2 — Stateless Composable Architecture

### 2.1 Definition
Every generated composable **must be stateless** unless explicitly instructed otherwise. A stateless composable:
- Receives **all data** via function parameters.
- Communicates user interactions back via **lambda callbacks**.
- Contains **no internal `remember`, `mutableStateOf`, or `LaunchedEffect`** that drives business logic.
- Is a **pure rendering function** — given the same inputs, it always produces the same UI output.

### 2.2 Mandatory Pattern — State Hoisting
State must always be **hoisted** to the caller. Follow this structure for every screen:

```kotlin
// ✅ CORRECT — Stateless Content composable
@Composable
fun LoginScreenContent(
    state       : LoginUiState,         // state flows DOWN
    onEmailChange    : (String) -> Unit, // events flow UP
    onPasswordChange : (String) -> Unit,
    onLoginClick     : () -> Unit,
    onForgotPassword : () -> Unit,
    modifier    : Modifier = Modifier   // always last, always defaulted
) {
    // Pure UI rendering — no business logic here
}

// ✅ CORRECT — Stateful Screen composable (connected to ViewModel)
@Composable
fun LoginScreen(
    viewModel: LoginViewModel = hiltViewModel(),
    onNavigateToHome: () -> Unit
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    LoginScreenContent(
        state            = state,
        onEmailChange    = viewModel::onEmailChange,
        onPasswordChange = viewModel::onPasswordChange,
        onLoginClick     = viewModel::onLogin,
        onForgotPassword = viewModel::onForgotPassword
    )
}
```

```kotlin
// ❌ WRONG — state owned inside the composable
@Composable
fun LoginScreenContent() {
    var email by remember { mutableStateOf("") }       // ❌ never own state
    var password by remember { mutableStateOf("") }    // ❌ never own state
    // ...
}
```

### 2.3 Parameter Rules
- The **first parameters** must be data/state parameters.
- **Lambda callbacks** come after data parameters.
- `modifier: Modifier = Modifier` must always be the **last parameter** with a default value.
- Use **`UiState` sealed class** to represent the full screen state.

```kotlin
// ✅ Correct parameter ordering
@Composable
fun UserCard(
    // 1. Data parameters first
    name      : String,
    avatarUrl : String,
    isOnline  : Boolean,
    // 2. Callbacks second
    onClick   : () -> Unit,
    onLongClick: () -> Unit = {},
    // 3. Modifier always last with default
    modifier  : Modifier = Modifier
)
```

### 2.4 UiState Structure
Always define a sealed class or data class for screen state:

```kotlin
// UiState sealed class — one per screen
sealed class LoginUiState {
    object Idle    : LoginUiState()
    object Loading : LoginUiState()
    data class Success(val userName: String)  : LoginUiState()
    data class Error(val message: UiText)     : LoginUiState()
}

// Or a single data class for simpler screens
data class ProfileUiState(
    val isLoading   : Boolean = false,
    val name        : String  = "",
    val email       : String  = "",
    val avatarUrl   : String? = null,
    val errorMessage: UiText? = null
)
```

---

## Rule 3 — Follow Material 3 Design System

### 3.1 Component Library
- Always use **Material 3** components from `androidx.compose.material3`.
- Do **not** import from `androidx.compose.material` (Material 2).
- Prefer built-in M3 components before building custom ones.

```kotlin
// ✅ Material 3
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.Card
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.TopAppBar

// ❌ Material 2 — never use
import androidx.compose.material.Button
import androidx.compose.material.Text
```

### 3.2 Typography
- Always use `MaterialTheme.typography.*` tokens — never hardcode font sizes.
- Never use raw `fontSize = 16.sp` — map to the closest typography token.

```kotlin
// ✅ Correct
Text(text = title, style = MaterialTheme.typography.titleLarge)
Text(text = body,  style = MaterialTheme.typography.bodyMedium)
Text(text = label, style = MaterialTheme.typography.labelSmall)

// ❌ Wrong
Text(text = title, fontSize = 22.sp, fontWeight = FontWeight.Bold)
```

### 3.3 Colour
- Always use `MaterialTheme.colorScheme.*` tokens — never hardcode colour values.
- Never use raw `Color(0xFF...)` in composable layout code.

```kotlin
// ✅ Correct
Surface(color = MaterialTheme.colorScheme.surface) { }
Text(color = MaterialTheme.colorScheme.onSurface)
Icon(tint  = MaterialTheme.colorScheme.primary)

// ❌ Wrong
Surface(color = Color(0xFFFFFFFF)) { }
Text(color = Color.Black)
```

### 3.4 Shape
- Use `MaterialTheme.shapes.*` tokens for corners and surfaces.

```kotlin
// ✅ Correct
Card(shape = MaterialTheme.shapes.medium) { }

// ❌ Wrong
Card(shape = RoundedCornerShape(8.dp)) { }
```

### 3.5 Spacing
- Use a spacing scale consistent with Material 3 (multiples of 4.dp).
- Define a spacing object if the project requires a custom scale.

```kotlin
object Spacing {
    val xs  = 4.dp
    val sm  = 8.dp
    val md  = 16.dp
    val lg  = 24.dp
    val xl  = 32.dp
    val xxl = 48.dp
}
```

---

## Rule 4 — Dark Mode Support

### 4.1 Theme Setup
- Every generated screen must be wrapped in or compatible with a `MaterialTheme` that supports both light and dark colour schemes.
- Always define both `lightColorScheme` and `darkColorScheme`.

```kotlin
// AppTheme.kt
@Composable
fun AppTheme(
    darkTheme : Boolean = isSystemInDarkTheme(),
    content   : @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) darkColorScheme(
        primary   = Purple80,
        secondary = PurpleGrey80,
        tertiary  = Pink80
    ) else lightColorScheme(
        primary   = Purple40,
        secondary = PurpleGrey40,
        tertiary  = Pink40
    )

    MaterialTheme(
        colorScheme = colorScheme,
        typography  = AppTypography,
        content     = content
    )
}
```

### 4.2 Dark Mode Rules
- Never hardcode colours that are not dark-mode aware.
- Always test generated UI with both `darkTheme = true` and `darkTheme = false` previews.
- Use `Surface` as the root of every screen to automatically apply background colour.

```kotlin
// ✅ Always wrap in Surface
@Composable
fun HomeScreenContent(
    state   : HomeUiState,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier.fillMaxSize(),
        color    = MaterialTheme.colorScheme.background
    ) {
        // screen content
    }
}
```

---

## Rule 5 — Preview Annotations

### 5.1 Mandatory Previews
Every composable **must** have at least one `@Preview`. Screens must have **two previews minimum**: light and dark.

```kotlin
// ✅ Minimum two previews for every Content composable
@Preview(name = "Light Mode", showBackground = true)
@Preview(name = "Dark Mode",  showBackground = true, uiMode = UI_MODE_NIGHT_YES)
@Composable
private fun LoginScreenContentPreview() {
    AppTheme {
        LoginScreenContent(
            state            = LoginUiState.Idle,
            onEmailChange    = {},
            onPasswordChange = {},
            onLoginClick     = {},
            onForgotPassword = {}
        )
    }
}
```

### 5.2 Preview Rules
- Preview functions must be `private`.
- Always wrap preview in `AppTheme { }`.
- Always pass **realistic fake data** — never empty strings in previews.
- Add `showBackground = true` on all previews.
- For lists or cards, use `@PreviewParameter` with a `PreviewParameterProvider`.

```kotlin
// PreviewParameterProvider example
class UserCardPreviewProvider : PreviewParameterProvider<UserCardState> {
    override val values = sequenceOf(
        UserCardState(name = "Budi Santoso",  isOnline = true),
        UserCardState(name = "Sari Dewi",     isOnline = false),
        UserCardState(name = "Ahmad Fauzi",   isOnline = true),
    )
}

@Preview(showBackground = true)
@Composable
private fun UserCardPreview(
    @PreviewParameter(UserCardPreviewProvider::class) state: UserCardState
) {
    AppTheme { UserCard(state = state, onClick = {}) }
}
```

### 5.3 Device Previews (for screens)
For full screens, also include device-specific previews:

```kotlin
@Preview(name = "Phone",  device = Devices.PIXEL_7,      showSystemUi = true)
@Preview(name = "Tablet", device = Devices.PIXEL_TABLET,  showSystemUi = true)
@Composable
private fun HomeScreenPreview() {
    AppTheme { HomeScreenContent(state = HomeUiState.Success(items = fakeItems)) }
}
```

---

## Rule 6 — Accessibility (TalkBack & A11y)

### 6.1 Content Descriptions
- Every `Icon`, `Image`, and non-text interactive element **must** have a `contentDescription`.
- Content descriptions must come from `stringResource()` — never hardcoded strings.
- Purely decorative images must set `contentDescription = null` explicitly.

```kotlin
// ✅ Correct
Icon(
    imageVector        = Icons.Default.Favorite,
    contentDescription = stringResource(R.string.accessibility_favourite_button)
)

// ✅ Decorative — explicit null
Image(
    painter            = painterResource(R.drawable.bg_banner),
    contentDescription = null  // decorative, intentionally no description
)

// ❌ Wrong — missing content description
Icon(imageVector = Icons.Default.Favorite, contentDescription = "")
```

### 6.2 Semantic Roles
- Add `Modifier.semantics { }` for custom interactive components.
- Use `Role` for clickable elements that are not standard buttons.

```kotlin
// ✅ Custom clickable with semantic role
Box(
    modifier = Modifier
        .clickable(
            onClick = onToggle,
            role    = Role.Switch
        )
        .semantics {
            contentDescription = if (isEnabled) "Disable notifications"
                                 else "Enable notifications"
        }
)
```

### 6.3 Touch Target Size
- All interactive elements must meet the **minimum 48.dp × 48.dp** touch target.

```kotlin
// ✅ Ensure minimum touch target
IconButton(
    onClick  = onClose,
    modifier = Modifier.size(48.dp)   // minimum touch target
) {
    Icon(Icons.Default.Close, contentDescription = stringResource(R.string.accessibility_close))
}
```

### 6.4 Focus Order
- For forms and sequential UI, define explicit focus traversal using `FocusRequester`.
- Ensure logical reading order for screen readers.

---

## Rule 7 — Screen vs Content Composable Separation

### 7.1 Mandatory Split
Every screen **must** be split into two composables:

| Composable | Suffix | Purpose | Has ViewModel? | Testable? |
|---|---|---|---|---|
| Screen | `Screen` | Connects to ViewModel, handles navigation | Yes | No (integration) |
| Content | `ScreenContent` | Pure stateless UI rendering | No | Yes (unit) |

```
LoginScreen          ← connects to LoginViewModel, handles nav callbacks
  └── LoginScreenContent  ← pure UI, fully stateless, fully testable
```

### 7.2 Navigation Callbacks
- Navigation actions are handled in the `Screen` composable — never inside `Content`.
- Pass navigation as a lambda parameter to the `Screen`.

```kotlin
// ✅ Navigation handled at Screen level
@Composable
fun LoginScreen(
    onNavigateToHome    : () -> Unit,
    onNavigateToRegister: () -> Unit,
    viewModel           : LoginViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // Handle side effects (navigation) here
    LaunchedEffect(state) {
        if (state is LoginUiState.Success) onNavigateToHome()
    }

    LoginScreenContent(
        state            = state,
        onLoginClick     = viewModel::onLogin,
        onRegisterClick  = onNavigateToRegister,
        onEmailChange    = viewModel::onEmailChange,
        onPasswordChange = viewModel::onPasswordChange
    )
}
```

---

## Rule 8 — Code Quality Standards

### 8.1 Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Composable function | PascalCase, noun | `UserProfileCard` |
| Preview function | PascalCase + Preview suffix, private | `private fun UserProfileCardPreview` |
| State class | PascalCase + UiState suffix | `LoginUiState` |
| Callback parameter | camelCase, starts with `on` | `onLoginClick` |
| Modifier parameter | always named `modifier` | `modifier: Modifier = Modifier` |
| String resource | snake_case with screen prefix | `login_button_submit` |

### 8.2 Import Rules
- No wildcard imports (`import androidx.compose.material3.*`).
- Group imports: Android → Compose → Kotlin → Project.

### 8.3 Function Length
- A single composable function body must not exceed **60 lines**.
- If it grows beyond 60 lines, extract sub-composables.

### 8.4 No Business Logic in Composables
- Composables must not contain `if/else` business rules, data transformations, or API calls.
- All logic lives in the `ViewModel` or `UseCase`.

```kotlin
// ❌ Wrong — business logic in composable
@Composable
fun PriceText(price: Double) {
    val formattedPrice = if (price > 1000) {          // ❌ logic in UI
        "%.2f".format(price / 1000) + "K"
    } else {
        "%.2f".format(price)
    }
    Text(text = formattedPrice)
}

// ✅ Correct — formatting done in ViewModel, UI just renders
@Composable
fun PriceText(
    formattedPrice: String,   // already formatted by ViewModel
    modifier: Modifier = Modifier
) {
    Text(text = formattedPrice, modifier = modifier)
}
```

---

## Rule 9 — Strings Localization

### 9.1 No Hardcoded Strings
- All user-facing text **must** use `stringResource(R.string.*)`.
- Never pass raw string literals to `Text()`, `contentDescription`, or `placeholder`.

```kotlin
// ✅ Correct
Text(text = stringResource(R.string.login_button_submit))

// ❌ Wrong
Text(text = "Sign In")
```

### 9.2 String Naming
- Follow the pattern: `<screen>_<component>_<description>`
- Example: `login_label_email`, `profile_button_edit`, `error_network_timeout`

---

## Rule 10 — AI Agent Behaviour

### 10.1 What the Agent Must Always Do
- ✅ Generate **both** `Screen` and `ScreenContent` composables for every screen request.
- ✅ Generate **light + dark** `@Preview` for every `ScreenContent`.
- ✅ Use `MaterialTheme` tokens for all colours, typography, and shapes.
- ✅ Add `contentDescription` to every icon and image.
- ✅ Use `stringResource()` for all visible text.
- ✅ Include `modifier: Modifier = Modifier` as the last parameter on every composable.
- ✅ Define a `UiState` data/sealed class for every screen.
- ✅ Wrap every screen in `Surface` with `MaterialTheme.colorScheme.background`.

### 10.2 What the Agent Must Never Do
- ❌ Generate XML layout files.
- ❌ Use Material 2 (`androidx.compose.material`) components.
- ❌ Hardcode colours, font sizes, or string literals.
- ❌ Place `remember { mutableStateOf() }` in a `ScreenContent` composable.
- ❌ Call ViewModel methods or inject dependencies inside a `ScreenContent`.
- ❌ Use `Context` directly inside any composable.
- ❌ Generate composables without `@Preview`.
- ❌ Use `View`-based widgets via `AndroidView` unless explicitly asked.

### 10.3 Output Format
Every code generation response must include, in this order:
1. `UiState` definition
2. `ScreenContent` composable (stateless)
3. `Screen` composable (connected to ViewModel)
4. `@Preview` functions (light + dark minimum)
5. Any required sub-composables
6. `strings.xml` entries for all text used

---

## Quick Reference Checklist

Before finalising any generated composable, verify:

- [ ] Composable is stateless (`ScreenContent` has no `remember` or VM reference)
- [ ] `modifier: Modifier = Modifier` is the last parameter
- [ ] All colours use `MaterialTheme.colorScheme.*`
- [ ] All typography uses `MaterialTheme.typography.*`
- [ ] All shapes use `MaterialTheme.shapes.*`
- [ ] All strings use `stringResource()`
- [ ] Every icon has a `contentDescription`
- [ ] Touch targets are at least `48.dp × 48.dp`
- [ ] Light mode `@Preview` present
- [ ] Dark mode `@Preview` present
- [ ] `Screen` and `ScreenContent` are separate composables
- [ ] No business logic inside any composable
- [ ] Material 3 components used exclusively
- [ ] `Surface` wraps the root of every screen

---

---

## Rule 11 — ViewModel Structure and Code Style

> **Reference:** Based on `LeaveViewModel.kt` as the canonical code style example for this project.

### 11.1 File and Class Declaration

- Every ViewModel **must** be annotated with `@HiltViewModel` and inject dependencies via `@Inject constructor(...)`.
- Use `@param:ApplicationContext` for injecting `Context` — never inject `Activity` context.
- Use `@param:IoDispatcher` for injecting a `CoroutineDispatcher` — never hardcode `Dispatchers.IO`.
- Use `/*region:*/ ... /*endregion*/` blocks to group related state and functions for readability.

```kotlin
// ✅ Correct ViewModel declaration
@HiltViewModel
class LeaveViewModel @Inject constructor(
    @param:ApplicationContext private val context     : Context,
    @param:IoDispatcher       private val ioDispatcher: CoroutineDispatcher,
    private val submitUseCase : SubmitLeaveRequestUseCase,
    private val validator     : LeaveRequestValidator,
) : ViewModel() {

    /*region: Screen State*/
    private val _uiState = MutableStateFlow(LeaveUiState())
    val uiState = _uiState.asStateFlow()

    private val _fieldState = MutableStateFlow(LeaveRequestFieldState())
    val fieldState = _fieldState.asStateFlow()
    /*endregion*/
}
```

### 11.2 State Exposure Rules

- Internal state **must** use `MutableStateFlow` — always `private`.
- Exposed state **must** use `.asStateFlow()` — always `val`, never `var`.
- For one-shot events (navigation, toast) use `MutableSharedFlow` — always `private`.
- Never expose `MutableStateFlow` or `MutableSharedFlow` directly to the UI layer.

```kotlin
// ✅ Correct state exposure pattern
private val _uiState = MutableStateFlow(LeaveUiState())
val uiState = _uiState.asStateFlow()                    // read-only to UI

private val _pagingEvent = MutableSharedFlow<PagingEvent>()
val pagingEvent: SharedFlow<PagingEvent> = _pagingEvent // read-only to UI

// ❌ Wrong — exposes mutable state
val uiState = MutableStateFlow(LeaveUiState())          // never expose mutable
```

### 11.3 Event Handling — Single `onEvent()` Entry Point (STRICT — ZERO EXCEPTIONS)

> ⛔ **HARD RULE — NON-NEGOTIABLE.**
> The `onEvent()` function is the **only** public entry point from the UI layer into the ViewModel.
> Exposing any other `fun` that the UI calls directly (e.g. `onSubmitClicked()`, `onDateChanged()`) is **forbidden**.
> If the generated ViewModel has public functions beyond `onEvent()`, `setSelectedFile()`, `initEditScreen()`, or equivalent lifecycle helpers explicitly documented below — the output is **invalid**.

#### 11.3.1 The Rule

- Every user action, field change, button tap, and lifecycle trigger from the UI **must** arrive as a sealed `Event` through `fun onEvent(event: <Feature>Event)`.
- The `onEvent` body **must** be wrapped in `viewModelScope.launch { when (event) { ... } }`.
- Every branch in the `when` block must be explicitly handled — no `else` catch-all.
- Events that are handled entirely in the UI layer (navigation, launching file pickers, opening camera, deep links) **must** be listed in `onEvent` as `Unit //Handle on UI` — they must still appear in the `Event` sealed class and the `when` block.
- The `when` block must be **exhaustive** — every subtype of the sealed class must have a branch.

#### 11.3.2 Exact Pattern (from `LeaveViewModel.kt`)

```kotlin
// ✅ CORRECT — exact pattern from LeaveViewModel.kt
fun onEvent(leaveEvent: LeaveEvent) {
    viewModelScope.launch {
        when (leaveEvent) {
            // Field input events — update FieldState inline
            is LeaveEvent.StartDateInput -> {
                _leaveRequestFieldState.update {
                    val showDurationTypeSection = sameDateString(leaveEvent.startDate, it.endDate)
                    val durationTypeValue = it.leaveDurationType.takeIf { showDurationTypeSection }
                    it.copy(
                        startDate                    = leaveEvent.startDate,
                        showLeaveDurationTypeSection = showDurationTypeSection,
                        leaveDurationType            = durationTypeValue
                    )
                }
            }
            is LeaveEvent.LeaveReasonInput -> {
                _leaveRequestFieldState.update { it.copy(leaveReason = leaveEvent.reason) }
            }

            // Async action events — delegate to private functions
            LeaveEvent.Submit               -> submitLeaveRequest()
            LeaveEvent.FetchLeaveBalance    -> fetchLeaveBalance()
            LeaveEvent.RefreshLeaveHistory  -> refreshHistoryList()
            LeaveEvent.RetryLeaveHistory    -> retryHistoryList()

            // Dialog control events — update UiState inline
            LeaveEvent.DismissDialog -> _leaveUiState.update {
                it.copy(leaveDialog = LeaveDialog.Default)
            }
            LeaveEvent.OpenLeaveTypeBottomSheet -> {
                setLeaveDialog(LeaveDialog.LeaveOptionBottomSheet)
            }
            is LeaveEvent.ShowCancelLeaveDialog -> _leaveUiState.update {
                it.copy(leaveDialog = LeaveDialog.Confirmation(
                    ConfirmationType.CancelLeave(leaveEvent.leaveId)
                ))
            }

            // UI-only events — listed here but handled in the Screen composable
            LeaveEvent.FileUploadClick      -> Unit //Handle on UI
            is LeaveEvent.DocumentDownload  -> Unit //Handle on UI
            is LeaveEvent.EditLeaveRequest  -> Unit //Handle on UI
            is LeaveEvent.CancelEditLeaveScreen -> Unit //Handle on UI
        }
    }
}
```

#### 11.3.3 What Is Forbidden

```kotlin
// ❌ FORBIDDEN — individual public functions for UI to call directly
fun onSubmitClicked() { ... }                    // ❌ must be LeaveEvent.Submit
fun onDateChanged(date: String) { ... }          // ❌ must be LeaveEvent.StartDateInput
fun onReasonChanged(reason: String) { ... }      // ❌ must be LeaveEvent.LeaveReasonInput
fun onDismissDialog() { ... }                    // ❌ must be LeaveEvent.DismissDialog

// ❌ FORBIDDEN — onEvent without viewModelScope.launch wrapper
fun onEvent(event: LeaveEvent) {
    when (event) { ... }                         // ❌ must be inside viewModelScope.launch
}

// ❌ FORBIDDEN — else catch-all in when block
fun onEvent(event: LeaveEvent) {
    viewModelScope.launch {
        when (event) {
            is LeaveEvent.Submit -> submitLeaveRequest()
            else -> { }                          // ❌ must handle every branch explicitly
        }
    }
}
```

#### 11.3.4 Permitted Public Functions Beyond `onEvent()`

Only the following types of public functions are permitted alongside `onEvent()`:

| Function | Purpose | Example |
|---|---|---|
| `initEditScreen(id)` | Lifecycle init for edit flows | `fun initEditLeaveScreen(leaveId: Int)` |
| `setSelectedFile(uri)` | File picker result callback (called from UI after picker returns) | `fun setSelectedFile(fileUri: Uri)` |
| `selectItem(item)` | Shared selection for detail screens | `fun selectLeave(leave: LeaveHistory)` |
| `setDialog(dialog)` | Public dialog setter (used by Screen composable for permission results) | `fun setLeaveDialog(dialog: LeaveDialog)` |
| `resetFormState()` | Navigation lifecycle reset | `fun resetFormState()` |
| `byPassLockScreen()` | Session management utility | `fun byPassLock()` |

Any public function not in the above categories **must** be converted to an `Event` and routed through `onEvent()`.

### 11.4 State Update Pattern

- Always use `_state.update { it.copy(...) }` to update state — never reassign the whole object.
- Never call `_state.value = ...` directly; always use `.update { }` for thread safety.

```kotlin
// ✅ Correct — use .update { it.copy(...) }
_leaveRequestFieldState.update {
    it.copy(
        startDate              = event.startDate,
        showLeaveDurationTypeSection = showDurationTypeSection,
        leaveDurationType      = durationTypeValue
    )
}

// ❌ Wrong — full object reassignment
_leaveRequestFieldState.value = LeaveRequestFieldState(
    startDate = event.startDate
)
```

### 11.5 Coroutine Usage

- All async work must run inside `viewModelScope.launch { }`.
- Heavy I/O operations (file reading, multipart conversion) must run inside `withContext(ioDispatcher) { }`.
- Never use `GlobalScope` or create raw `CoroutineScope` instances in a ViewModel.
- Use `@OptIn(ExperimentalCoroutinesApi::class)` only when required and document why.

```kotlin
// ✅ Correct coroutine pattern
fun submitLeaveRequest() {
    viewModelScope.launch {
        setDialog(LeaveDialog.Loading)

        val document = withContext(ioDispatcher) {    // heavy I/O off main thread
            fileInfo?.uri?.toMultipart(context, "document")
        }

        when (val result = submitUseCase(request, document)) {
            is Resource.Success -> handleSuccess(result.data)
            is Resource.Error   -> handleError(result.error)
        }
    }
}

// ❌ Wrong
fun submitLeaveRequest() {
    GlobalScope.launch(Dispatchers.IO) { ... }       // never GlobalScope
}
```

### 11.6 Dialog / Loading State Management

- All loading, error, success, and confirmation dialogs must be managed via a single `Dialog` sealed class inside `UiState`.
- Provide a dedicated `setDialog(dialog: ScreenDialog)` function for updating dialog state.
- Always set `Dialog.Loading` at the start of async operations and resolve to `Default`, `Success`, or `Error` on completion.

```kotlin
// ✅ Dialog sealed class pattern (matches LeaveViewModel style)
sealed class LeaveDialog {
    object Default  : LeaveDialog()
    object Loading  : LeaveDialog()
    data class Success(val title: String, val message: String) : LeaveDialog()
    data class Error  (val title: String, val message: String) : LeaveDialog()
    data class Confirmation(val type: ConfirmationType)        : LeaveDialog()
    object LeaveOptionBottomSheet                              : LeaveDialog()
}

// ✅ Correct usage
fun setLeaveDialog(dialog: LeaveDialog) {
    _uiState.update { it.copy(leaveDialog = dialog) }
}

private fun submitLeaveRequest() {
    viewModelScope.launch {
        setLeaveDialog(LeaveDialog.Loading)           // start
        when (val result = useCase()) {
            is Resource.Success -> setLeaveDialog(LeaveDialog.Success(...))
            is Resource.Error   -> setLeaveDialog(LeaveDialog.Error(...))
        }
    }
}
```

### 11.7 Validation

- All input validation **must** be delegated to a dedicated `Validator` class injected into the ViewModel.
- Never perform inline validation logic inside a ViewModel function.
- Validator returns `null` on success or a typed error object on failure.

```kotlin
// ✅ Correct — delegate to injected validator
val validationError = validator.validate(
    startDate  = startDate,
    endDate    = endDate,
    leaveType  = leaveType,
    reason     = reason,
)

if (validationError != null) {
    setLeaveDialog(LeaveDialog.Error(message = context.getString(validationError.toMessageRes())))
    return@launch
}

// ❌ Wrong — inline validation in ViewModel
if (startDate.isNullOrBlank()) {
    setLeaveDialog(LeaveDialog.Error(message = "Start date is required"))
    return@launch
}
```

### 11.8 Resource / Result Handling

- All use case calls must return `Resource<T>` or `Result<T>` — never raw data or throwing exceptions.
- Always handle both `Resource.Success` and `Resource.Error` in a `when` expression — no `if/else`.
- Error messages must use `error.asString(context)` — never hardcode error strings in ViewModel.

```kotlin
// ✅ Correct Resource handling
when (val result = cancelLeaveRequestUseCase(leaveId, reason)) {
    is Resource.Error   -> setLeaveDialog(LeaveDialog.Error(
        title   = context.getString(R.string.cancel_leave_request),
        message = result.error.asString(context)
    ))
    is Resource.Success -> setLeaveDialog(LeaveDialog.Success(
        title   = context.getString(R.string.cancel_leave_request),
        message = context.getString(R.string.leave_request_canceled_success_message_msg)
    ))
}

// ❌ Wrong — try/catch in ViewModel
try {
    val result = cancelLeaveRequestUseCase(leaveId, reason)
    // ...
} catch (e: Exception) {
    setLeaveDialog(LeaveDialog.Error(title = "Error", message = e.message ?: "Unknown"))
}
```

---

## Rule 12 — UiState MUST Live in a Separate File (STRICT — ZERO EXCEPTIONS)

> ⛔ **HARD RULE — NON-NEGOTIABLE.**
> This rule is the most commonly violated one. The AI agent **must treat this as a compiler error**, not a style preference.
> If `UiState`, `FieldState`, `Event`, or `Dialog` appears inside a ViewModel file, the output is **invalid and must be regenerated**.

### 12.0 The Single Most Important Rule

**`<Feature>ViewModel.kt` must contain ONE thing and ONE thing only: the ViewModel class.**

Every other declaration — `UiState`, `FieldState`, `Event`, `Dialog`, enums — belongs in its own dedicated file. No exceptions. Not even for "small" or "simple" screens.

### 12.1 What Is Forbidden Inside a ViewModel File

The following declarations are **strictly forbidden** inside `<Feature>ViewModel.kt`:

```kotlin
// ❌ INVALID — UiState declared inside ViewModel file
// File: LeaveViewModel.kt

data class LeaveUiState(...)            // ❌ FORBIDDEN — must be in LeaveUiState.kt
sealed class LeaveDialog { ... }        // ❌ FORBIDDEN — must be in LeaveUiState.kt
sealed class LeaveEvent { ... }         // ❌ FORBIDDEN — must be in LeaveEvent.kt
data class LeaveRequestFieldState(...)  // ❌ FORBIDDEN — must be in LeaveRequestFieldState.kt
enum class LeaveTab { ... }             // ❌ FORBIDDEN — must be in LeaveTab.kt
enum class LeaveDurationType { ... }    // ❌ FORBIDDEN — must be in LeaveDurationType.kt

@HiltViewModel
class LeaveViewModel @Inject constructor(...) : ViewModel() {
    // ViewModel body
}
```

> If the agent outputs any of the above declarations inside a ViewModel file, **that output is wrong**. Regenerate immediately with all state classes extracted into their own files.

### 12.2 Mandatory File Structure — One Class Per File

Every feature screen **must** produce this exact file layout. No merging. No exceptions.

```
feature/
  presentation/
    screen/
      leave/
        LeaveViewModel.kt           ← ViewModel class ONLY. No state classes here.
        LeaveUiState.kt             ← LeaveUiState data class + LeaveDialog sealed class
        LeaveRequestFieldState.kt   ← LeaveRequestFieldState data class only
        LeaveEvent.kt               ← LeaveEvent sealed class only
        LeaveDurationType.kt        ← LeaveDurationType enum only
        LeaveTab.kt                 ← LeaveTab enum only
```

**File ownership rule — one class, one file, always:**

| Class Type | File Name | Contains |
|---|---|---|
| ViewModel | `<Feature>ViewModel.kt` | ViewModel class only |
| Screen UiState | `<Feature>UiState.kt` | `UiState` data class + `Dialog` sealed class |
| Form field state | `<Feature>FieldState.kt` | `FieldState` data class only |
| User events | `<Feature>Event.kt` | `Event` sealed class only |
| Enums / types | `<EnumName>.kt` | One enum or helper type per file |

### 12.3 What a ViewModel File Must Look Like

The ViewModel file must contain **only** the `@HiltViewModel` class. Zero state class declarations.

```kotlin
// ✅ CORRECT — LeaveViewModel.kt contains ONLY the ViewModel
// File: LeaveViewModel.kt

package com.example.app.features.presentation.screen.leave

// Imports from their own files — NOT declared here
import com.example.app.features.presentation.screen.leave.LeaveUiState
import com.example.app.features.presentation.screen.leave.LeaveRequestFieldState
import com.example.app.features.presentation.screen.leave.LeaveEvent
import com.example.app.features.presentation.screen.leave.LeaveDialog

@HiltViewModel
class LeaveViewModel @Inject constructor(
    @param:ApplicationContext private val context     : Context,
    @param:IoDispatcher       private val ioDispatcher: CoroutineDispatcher,
    private val submitUseCase : SubmitLeaveRequestUseCase,
    private val validator     : LeaveRequestValidator,
) : ViewModel() {

    private val _uiState = MutableStateFlow(LeaveUiState())
    val uiState = _uiState.asStateFlow()

    private val _fieldState = MutableStateFlow(LeaveRequestFieldState())
    val fieldState = _fieldState.asStateFlow()

    fun onEvent(event: LeaveEvent) { ... }

    // ← NO state class declarations anywhere in this file
}
```

### 12.4 UiState File — `LeaveUiState.kt`

```kotlin
// ✅ CORRECT — LeaveUiState.kt
// File: LeaveUiState.kt

package com.example.app.features.presentation.screen.leave

data class LeaveUiState(
    val leaveDialog           : LeaveDialog           = LeaveDialog.Default,
    val selectedTab           : LeaveTab              = LeaveTab.REQUEST,
    val leaveOptions          : List<LeaveBalance>    = emptyList(),
    val filteredLeaveOptions  : List<LeaveBalance>    = emptyList(),
    val leaveRequestFormState : LeaveRequestFormState = LeaveRequestFormState.LEAVE_REQUEST_FORM,
)

// Dialog sealed class lives alongside UiState — same file, same feature concern
sealed class LeaveDialog {
    object Default                : LeaveDialog()
    object Loading                : LeaveDialog()
    object LeaveOptionBottomSheet : LeaveDialog()
    data class Success(val title: String, val message: String) : LeaveDialog()
    data class Error  (val title: String, val message: String) : LeaveDialog()
    data class Confirmation(val type: ConfirmationType)        : LeaveDialog()
}
```

### 12.5 FieldState File — `LeaveRequestFieldState.kt`

```kotlin
// ✅ CORRECT — LeaveRequestFieldState.kt
// File: LeaveRequestFieldState.kt

package com.example.app.features.presentation.screen.leave

import android.net.Uri

data class LeaveRequestFieldState(
    val startDate                    : String             = "",
    val endDate                      : String             = "",
    val startTime                    : String             = "",
    val endTime                      : String             = "",
    val leaveType                    : LeaveType?         = null,
    val leaveReason                  : String             = "",
    val showLeaveDurationTypeSection : Boolean            = false,
    val leaveDurationType            : LeaveDurationType? = null,
    val selectedFileUri              : Uri?               = null,
    val selectedFileName             : String?            = null,
    val selectedFileSize             : String?            = null,
    val documentDownloadLink         : String?            = null,
    val documentDownloadName         : String?            = null,
    val documentDownloadSize         : String?            = null,
    val minStartDate                 : String?            = null,
)
```

### 12.6 Event File — `LeaveEvent.kt`

```kotlin
// ✅ CORRECT — LeaveEvent.kt
// File: LeaveEvent.kt

package com.example.app.features.presentation.screen.leave

sealed class LeaveEvent {
    data class StartDateInput(val startDate: String)                              : LeaveEvent()
    data class EndDateInput(val endDate: String)                                  : LeaveEvent()
    data class LeaveOptionInput(val leaveType: LeaveType)                         : LeaveEvent()
    data class LeaveReasonInput(val reason: String)                               : LeaveEvent()
    data class StartTimeInput(val startTime: String)                              : LeaveEvent()
    data class EndTimeInput(val endTime: String)                                  : LeaveEvent()
    data class SetTab(val leaveTab: LeaveTab)                                     : LeaveEvent()
    data class ShowCancelLeaveDialog(val leaveId: String)                         : LeaveEvent()
    data class CancelLeaveRequest(val leaveId: String, val reason: String)        : LeaveEvent()
    data class LeaveDurationTypeSelected(val durationType: LeaveDurationType)     : LeaveEvent()
    data class RequestFormState(val requestFormState: LeaveRequestFormState)      : LeaveEvent()
    data class EditLeaveRequest(val leaveId: Int)                                 : LeaveEvent()
    data class DocumentDownload(val url: String)                                  : LeaveEvent() // Handle on UI
    object Submit                     : LeaveEvent()
    object DismissDialog              : LeaveEvent()
    object FetchLeaveBalance          : LeaveEvent()
    object OpenLeaveTypeBottomSheet   : LeaveEvent()
    object RefreshLeaveHistory        : LeaveEvent()
    object RetryLeaveHistory          : LeaveEvent()
    object DocumentDeleteRequest      : LeaveEvent()
    object DocumentDeleteConfirmation : LeaveEvent()
    object FileUploadClick            : LeaveEvent() // Handle on UI
    object FileUploadClear            : LeaveEvent()
    object CancelEditLeaveScreen      : LeaveEvent() // Handle on UI
    object SubmitEditRequest          : LeaveEvent()
}
```

### 12.7 Agent Self-Check — Before Outputting Any ViewModel Code

Before generating or returning ViewModel-related code, the agent **must** verify all of the following. If any check fails, regenerate — do not output:

```
SELF-CHECK: ViewModel File Separation
──────────────────────────────────────────────────────────────────
[ ] LeaveViewModel.kt contains ONLY the ViewModel class
[ ] NO data class declarations inside LeaveViewModel.kt
[ ] NO sealed class declarations inside LeaveViewModel.kt
[ ] NO enum class declarations inside LeaveViewModel.kt
[ ] LeaveUiState.kt exists as a separate file
[ ] LeaveRequestFieldState.kt exists as a separate file
[ ] LeaveEvent.kt exists as a separate file
[ ] Each enum (LeaveTab, LeaveDurationType) has its own file
[ ] All files share the same package name
[ ] ViewModel imports UiState/Event from their own files
──────────────────────────────────────────────────────────────────
If ANY box above is unchecked → output is INVALID. Regenerate.
```

---

## Rule 13 — Use In-App Reusable UI Components (`features.presentation.component`)

> **Single source of truth:** `com.ictechnology.app.features.presentation.component`
> Assume every reusable UI component (button, text field, dialog, picker, app bar, loader, tabs, paging states, …) already exists in this package and its subpackages. Feature screens source all of them from here.

### 13.1 Component Library Requirement (STRICT)

- Source every UI component from `com.ictechnology.app.features.presentation.component` and its subpackages.
- Do **not** use raw Material 3 components directly in feature screens — always use the in-app equivalent.
- Browse the package's subpackages to find the right component (`button`, `textfield`, `dialog`, `picker`, `appbar`, `loading`, `tab`, `paging`, …) and import it from there.

```kotlin
// ✅ Correct — in-app components
import com.ictechnology.app.features.presentation.component.button.AppButton
import com.ictechnology.app.features.presentation.component.textfield.CommonTextField
import com.ictechnology.app.features.presentation.component.dialog.NormalDialog
import com.ictechnology.app.features.presentation.component.dialog.ConfirmationDialog
import com.ictechnology.app.features.presentation.component.loading.LoadingComponent
import com.ictechnology.app.features.presentation.component.picker.DatePickerField
import com.ictechnology.app.features.presentation.component.appbar.CommonAppBarWithTitle

// ❌ Wrong — raw M3 used directly in a feature screen
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
```

### 13.2 When a Component Is Missing

If a component the design needs genuinely does not exist in the package, **create it** in the matching subpackage (see 13.4) — never fall back to raw Material 3 in the screen.

### 13.3 Component Usage Pattern

Use the **actual** component signatures (verify against the source file in the `component` package before generating):

```kotlin
// ✅ Correct — in-app button
AppButton(
    modifier        = Modifier.fillMaxWidth(),
    style           = UiStyle.Primary,
    label           = stringResource(R.string.common_button_submit),
    enable          = !state.isLoading,
    onClickListener = { onEvent(LeaveEvent.Submit) }
)

// ✅ Correct — in-app text field
CommonTextField(
    modifier        = Modifier.fillMaxWidth(),
    value           = fieldState.leaveReason,
    placeholder     = stringResource(R.string.leave_placeholder_reason),
    keyboardOptions = KeyboardOptions.Default,
    enabled         = !state.isLoading,
    isFocused       = fieldState.isReasonFocused,
    isError         = fieldState.reasonError != null,
    onValueChange   = { onEvent(LeaveEvent.LeaveReasonInput(it)) }
)

// ✅ Correct — full-screen loading driven by UiState
if (state.isLoading) {
    LoadingComponent(message = stringResource(R.string.common_loading))
}

// ✅ Correct — dialogs driven by UiState
when (val dialog = state.leaveDialog) {
    is LeaveDialog.Message      -> NormalDialog(
        title        = dialog.title,
        message      = dialog.message,
        confirmLabel = stringResource(R.string.common_ok),
        uiStyle      = UiStyle.Primary,
        onConfirm    = { onEvent(LeaveEvent.DismissDialog) },
        icon         = { /* dialog icon */ }
    )
    is LeaveDialog.Confirmation -> ConfirmationDialog(
        title         = dialog.title,
        message       = dialog.message,
        positiveLabel = stringResource(R.string.common_confirm),
        negativeLabel = stringResource(R.string.common_cancel),
        uiStyle       = UiStyle.Primary,
        onPositive    = { onEvent(LeaveEvent.ConfirmDelete) },
        onNegative    = { onEvent(LeaveEvent.DismissDialog) },
        icon          = { /* dialog icon */ }
    )
    LeaveDialog.None            -> Unit
}
```

### 13.4 Adding a New Component

When a needed component does not exist in the package and must be created from scratch:

1. Create the file under `app/src/main/java/com/ictechnology/app/features/presentation/component/<subpackage>/<ComponentName>.kt`.
2. Set the package to `com.ictechnology.app.features.presentation.component.<subpackage>`.
3. Make it fully **stateless** — all state passed as parameters, callbacks as lambdas.
4. Drive styling via `UiStyle` rather than hard-coded colors, matching the existing components.
5. Add a `@Preview` (light **and** dark) — place previews under the `component/preview/` package to match the existing convention.
6. Document the component with a KDoc comment describing its purpose and parameters.
7. **Only then** import and use it in the feature screen.

---

## Rule 14 — Icon and Image Asset Management

### 14.1 Icon Source Priority

When a UI design references an icon or image, the AI agent must resolve it using the following priority order. **Priority 1 is always attempted first** before falling through to the next level.

| Priority | Source | When to Use |
|---|---|---|
| 1 | SVG / PNG from design file → converted to `VectorDrawable` | Designer has provided the icon asset in Figma / Zeplin — **always preferred** |
| 2 | `androidx.compose.material.icons` (Material Icons Extended) | No design asset exists AND the icon is a standard utility action |
| 3 | App custom icon set | Project-specific branded reusable icons already in `app/src/main/res/drawable/` |
| 4 | Remote URL via Coil (`AsyncImage`) | Dynamic images loaded from an API URL |

> **Rationale for this order:** Custom icons from the design file guarantee pixel-perfect brand consistency and match the designer's exact intent. Material Icons are a fallback for standard utility icons (back, close, search, share) where no custom asset has been provided — using them as a first resort risks visual drift from the approved design over time.

### 14.2 Priority 1 — SVG / VectorDrawable from Design File

This is the **default and preferred** approach for all icons specified in the UI design.

**Conversion steps:**
1. Export the icon as SVG from the design tool (Figma / Zeplin).
2. Convert to Android `VectorDrawable` XML using Android Studio's **Vector Asset Studio** (`File > New > Vector Asset > Local file (SVG, PSD)`).
3. Place the converted file in `app/src/main/res/drawable/ic_<feature>_<description>.xml`.
4. Reference via `painterResource` in the composable.

```kotlin
// ✅ Priority 1 — custom VectorDrawable from design file (preferred)
Icon(
    painter            = painterResource(id = R.drawable.ic_leave_calendar),
    contentDescription = stringResource(R.string.accessibility_leave_calendar),
    tint               = MaterialTheme.colorScheme.primary,
    modifier           = Modifier.size(24.dp)
)

Icon(
    painter            = painterResource(id = R.drawable.ic_profile_edit),
    contentDescription = stringResource(R.string.accessibility_profile_edit),
    tint               = MaterialTheme.colorScheme.onSurface,
    modifier           = Modifier.size(24.dp)
)
```

**When to apply Priority 1:**
- The icon appears in a Figma / Zeplin design spec.
- The icon has a specific visual style, stroke weight, or shape that differs from Material Icons.
- The icon is part of the app's branded icon set.
- Any icon on a feature screen that a designer has explicitly drawn.

### 14.3 Priority 2 — Material Icons Extended (Utility Fallback)

Use Material Icons **only** when a design asset has **not** been provided AND the icon represents a standard, universally understood utility action. Do not substitute a provided design icon with a Material Icon for convenience.

```kotlin
// In build.gradle.kts
implementation("androidx.compose.material:material-icons-extended")
```

```kotlin
// ✅ Priority 2 — Material Icons for standard utility actions with no design asset
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.outlined.Notifications

Icon(
    imageVector        = Icons.AutoMirrored.Filled.ArrowBack,
    contentDescription = stringResource(R.string.accessibility_back_button),
    tint               = MaterialTheme.colorScheme.onSurface
)
```

**Acceptable utility icons for Priority 2 (no design asset required):**

| Action | Material Icon |
|---|---|
| Navigate back | `Icons.AutoMirrored.Filled.ArrowBack` |
| Close / dismiss | `Icons.Default.Close` |
| Search | `Icons.Default.Search` |
| More options (3-dot) | `Icons.Default.MoreVert` |
| Share | `Icons.Default.Share` |
| Settings | `Icons.Default.Settings` |
| Check / done | `Icons.Default.Check` |
| Visibility toggle | `Icons.Default.Visibility` / `VisibilityOff` |
| Add / create | `Icons.Default.Add` |
| Delete | `Icons.Default.Delete` |

> ⚠️ **If the UI design specifies a custom version of any icon in the table above** (e.g. a branded back arrow, a styled close button), Priority 1 still applies — use the design asset, not the Material Icon.

### 14.4 Priority 3 — App Custom Icon Set

Icons that are reused across multiple features and already exist in the app belong here. Check `app/src/main/res/drawable/` before converting a new SVG — the icon may already exist.

```kotlin
// ✅ Priority 3 — reusable icon already in app drawables
Icon(
    painter            = painterResource(id = R.drawable.ic_common_avatar_placeholder),
    contentDescription = stringResource(R.string.accessibility_avatar),
    modifier           = Modifier.size(40.dp)
)
```

### 14.5 Priority 4 — Remote / Dynamic Images via Coil

Use **Coil** for all images whose URLs are returned from an API at runtime.

```kotlin
// build.gradle.kts
implementation("io.coil-kt.coil3:coil-compose:3.0.0")
```

```kotlin
// ✅ Priority 4 — remote image with placeholder and error fallback
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(avatarUrl)
        .crossfade(true)
        .placeholder(R.drawable.ic_common_avatar_placeholder)  // Priority 1/3 asset
        .error(R.drawable.ic_common_avatar_placeholder)        // Priority 1/3 asset
        .build(),
    contentDescription = stringResource(R.string.accessibility_profile_avatar),
    contentScale       = ContentScale.Crop,
    modifier           = Modifier
        .size(48.dp)
        .clip(CircleShape)
)
```

### 14.6 Icon Naming Convention

All custom `VectorDrawable` icon files **must** follow the naming convention. This applies to Priority 1 and Priority 3 icons:

```
ic_<feature>_<description>.xml

Feature = screen or domain area (leave, profile, home, common, notification)
Description = what the icon represents (calendar, attachment, edit, back_arrow)

Examples:
  ic_leave_calendar.xml          ← leave feature, calendar icon
  ic_leave_attachment.xml        ← leave feature, attachment icon
  ic_profile_edit.xml            ← profile feature, edit icon
  ic_profile_avatar_placeholder.xml
  ic_notification_bell.xml
  ic_common_back_arrow.xml       ← shared utility icon (common)
  ic_common_close.xml
  ic_common_search.xml
```

**Location:**
- Feature-specific icons → `app/src/main/res/drawable/ic_<feature>_<name>.xml`
- Shared/utility icons → `app/src/main/res/drawable/ic_common_<name>.xml`

### 14.7 Agent Decision Flow

When the UI design references any icon, the agent must follow this exact decision tree before writing any code:

```
Icon referenced in UI design
        │
        ▼
Has the designer provided an asset (SVG/PNG) in the spec?
        │
       YES ──────────────────────────────────────────────────▶ Priority 1
        │                                                    Convert SVG → VectorDrawable
        │                                                    Place in app/src/main/res/drawable/
        │                                                    Use painterResource()
        NO
        │
        ▼
Is it a standard utility icon (back, close, search, etc.)?
        │
       YES ──────────────────────────────────────────────────▶ Priority 2
        │                                                    Use Material Icons Extended
        │                                                    imageVector = Icons.Default.*
        NO
        │
        ▼
Does the icon already exist in app/src/main/res/drawable/?
        │
       YES ──────────────────────────────────────────────────▶ Priority 3
        │                                                    Use existing app asset
        │                                                    painterResource(R.drawable.ic_*)
        NO
        │
        ▼
Is the image URL dynamic (from API)?
        │
       YES ──────────────────────────────────────────────────▶ Priority 4
                                                             AsyncImage() + Coil
                                                             with placeholder (Priority 1/3)
```

### 14.8 Universal Icon Rules (Apply to All Priorities)

Regardless of which priority source is used, these rules always apply:

- Always use `tint = MaterialTheme.colorScheme.*` on `Icon()` — **never hardcode** a tint colour.
- Always specify `Modifier.size(24.dp)` as the default icon size unless the design specifies a different size.
- Always provide a non-null, meaningful `contentDescription` from `stringResource()`.
- Purely decorative icons that add no information must set `contentDescription = null` **explicitly** (not an empty string).

```kotlin
// ✅ All rules applied
Icon(
    painter            = painterResource(R.drawable.ic_leave_calendar),
    contentDescription = stringResource(R.string.accessibility_leave_calendar),
    tint               = MaterialTheme.colorScheme.primary,
    modifier           = Modifier.size(24.dp)
)

// ✅ Decorative — explicit null
Icon(
    painter            = painterResource(R.drawable.ic_decorative_divider),
    contentDescription = null,   // intentionally decorative — no screen reader value
    tint               = MaterialTheme.colorScheme.outlineVariant,
    modifier           = Modifier.size(24.dp)
)

// ❌ Wrong — hardcoded tint colour
Icon(
    imageVector        = Icons.Default.Close,
    contentDescription = "Close",          // ❌ hardcoded string
    tint               = Color(0xFF333333) // ❌ hardcoded tint
)
```

---

## Rule 15 — Runtime Permission Handling (Camera and Gallery — STRICT)

### 15.1 Trigger Condition

> ⛔ **MANDATORY:** Any time the UI design contains a component that allows the user to **select an image, take a photo, or attach a file**, the agent **must** generate the full camera and gallery runtime permission flow. This is not optional.

Detection triggers — if the design has any of:
- A profile picture / avatar upload component
- An attachment or document upload field
- A camera capture button
- An `AppImagePickerField` or `AppFileUploadField` from `features.presentation.component`
- Any `Image`, `Icon`, or button labelled with "upload", "attach", "photo", "camera", "gallery", "choose file"

→ **Generate the full camera + gallery permission flow automatically.**

### 15.2 Required Permissions by Use Case

| Use Case | Permissions Required | API Condition |
|---|---|---|
| Camera capture | `CAMERA` | All versions |
| Gallery / image pick | `READ_MEDIA_IMAGES` | API 33+ (Android 13+) |
| Gallery / image pick | `READ_EXTERNAL_STORAGE` | API 32 and below |
| File attachment (any type) | `READ_MEDIA_IMAGES` + `READ_MEDIA_VIDEO` + `READ_MEDIA_AUDIO` | API 33+ |
| File attachment (any type) | `READ_EXTERNAL_STORAGE` | API 32 and below |

### 15.3 AndroidManifest.xml Declarations (Always Include)

```xml
<!-- AndroidManifest.xml — required for camera + gallery -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Android 13+ (API 33+) granular media permissions -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

<!-- Android 12 and below -->
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- FileProvider for camera capture URI (required for takePicture contract) -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.provider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_provider_paths" />
</provider>
```

```xml
<!-- res/xml/file_provider_paths.xml -->
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-cache-path name="camera_photos" path="." />
    <cache-path name="cache_photos" path="." />
</paths>
```

### 15.4 Dependency

```kotlin
// build.gradle.kts
implementation("com.google.accompanist:accompanist-permissions:0.36.0")
```

### 15.5 Full Camera + Gallery Permission Pattern (Screen Composable)

This is the **complete mandatory pattern** to generate whenever camera or gallery access is needed:

```kotlin
// ✅ COMPLETE — camera + gallery permission pattern in Screen composable
@Composable
fun ProfileScreen(
    viewModel      : ProfileViewModel = hiltViewModel(),
    onNavigateBack : () -> Unit
) {
    val state      by viewModel.uiState.collectAsStateWithLifecycle()
    val fieldState by viewModel.fieldState.collectAsStateWithLifecycle()
    val context    = LocalContext.current

    // ── 1. Camera URI for TakePicture contract ──────────────────────────
    var cameraImageUri by remember { mutableStateOf<Uri?>(null) }

    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && cameraImageUri != null) {
            viewModel.setSelectedFile(cameraImageUri!!)  // pass URI to ViewModel
        }
    }

    // ── 2. Gallery launcher ──────────────────────────────────────────────
    val galleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { viewModel.setSelectedFile(it) }
    }

    // ── 3. Camera permission ─────────────────────────────────────────────
    val cameraPermission = rememberPermissionState(
        permission = Manifest.permission.CAMERA
    ) { isGranted ->
        if (isGranted) {
            // Permission just granted — launch camera immediately
            val uri = createCameraImageUri(context)
            cameraImageUri = uri
            cameraLauncher.launch(uri)
        } else {
            viewModel.setDialog(
                ProfileDialog.Error(
                    title   = context.getString(R.string.permission_camera_title),
                    message = context.getString(R.string.permission_camera_denied_message)
                )
            )
        }
    }

    // ── 4. Gallery / storage permission (API-level aware) ────────────────
    val storagePermission = rememberPermissionState(
        permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    ) { isGranted ->
        if (isGranted) {
            galleryLauncher.launch("image/*")
        } else {
            viewModel.setDialog(
                ProfileDialog.Error(
                    title   = context.getString(R.string.permission_storage_title),
                    message = context.getString(R.string.permission_storage_denied_message)
                )
            )
        }
    }

    // ── 5. Permission request helpers ────────────────────────────────────
    fun requestCamera() {
        when {
            cameraPermission.status.isGranted -> {
                val uri = createCameraImageUri(context)
                cameraImageUri = uri
                cameraLauncher.launch(uri)
            }
            cameraPermission.status.shouldShowRationale -> {
                viewModel.setDialog(
                    ProfileDialog.Error(
                        title   = context.getString(R.string.permission_camera_title),
                        message = context.getString(R.string.permission_camera_rationale_message)
                    )
                )
            }
            else -> cameraPermission.launchPermissionRequest()
        }
    }

    fun requestGallery() {
        when {
            storagePermission.status.isGranted -> {
                galleryLauncher.launch("image/*")
            }
            storagePermission.status.shouldShowRationale -> {
                viewModel.setDialog(
                    ProfileDialog.Error(
                        title   = context.getString(R.string.permission_storage_title),
                        message = context.getString(R.string.permission_storage_rationale_message)
                    )
                )
            }
            else -> storagePermission.launchPermissionRequest()
        }
    }

    // ── 6. Pass callbacks to stateless Content composable ────────────────
    ProfileScreenContent(
        state           = state,
        fieldState      = fieldState,
        onEvent         = viewModel::onEvent,
        onCameraClick   = ::requestCamera,
        onGalleryClick  = ::requestGallery,
    )
}

// ── Helper: create a FileProvider URI for camera capture ─────────────────
private fun createCameraImageUri(context: Context): Uri {
    val imageFile = File(context.externalCacheDir, "camera_photo_${System.currentTimeMillis()}.jpg")
    return FileProvider.getUriForFile(context, "${context.packageName}.provider", imageFile)
}
```

### 15.6 Image Source Selection Bottom Sheet

When the design allows the user to choose between camera and gallery, use `AppImagePickerField` from `features.presentation.component` which shows a bottom sheet. If it does not exist yet, create it in the package per Rule 13.2:

```kotlin
// ✅ In-app image picker component drives the choice
AppImagePickerField(
    label          = stringResource(R.string.profile_label_photo),
    imageUri       = fieldState.selectedImageUri,
    onCameraClick  = onCameraClick,    // routes to requestCamera() in Screen
    onGalleryClick = onGalleryClick,   // routes to requestGallery() in Screen
    onClearClick   = { onEvent(ProfileEvent.ClearSelectedImage) },
    modifier       = Modifier.fillMaxWidth()
)
```

### 15.7 ViewModel Side — File Received Callback

The ViewModel receives the file URI via a dedicated public setter (not through `onEvent`), matching the `LeaveViewModel.setSelectedFile()` pattern:

```kotlin
// ✅ Correct — in ViewModel (matches LeaveViewModel.kt pattern)
fun setSelectedFile(fileUri: Uri) {
    val fileName = fileUri.getFileName(context)
    val fileSize = fileUri.getFileSize(context).toReadableFileSize()

    _fieldState.update {
        it.copy(
            selectedImageUri  = fileUri,
            selectedImageName = fileName,
            selectedImageSize = fileSize
        )
    }
}
```

### 15.8 Permanent Denial — Settings Redirect

When permission is permanently denied (user tapped "Don't ask again"), show a dialog that redirects to app settings:

```kotlin
// ✅ Permanent denial — redirect to settings
fun requestCameraWithSettingsFallback(
    cameraPermission: PermissionState,
    context         : Context,
    onOpenSettings  : () -> Unit,
    onShowRationale : () -> Unit,
    onGranted       : () -> Unit
) {
    when {
        cameraPermission.status.isGranted                  -> onGranted()
        cameraPermission.status.shouldShowRationale        -> onShowRationale()
        else                                               -> onOpenSettings()  // permanently denied
    }
}

// Open settings intent
fun openAppSettings(context: Context) {
    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
        data = Uri.fromParts("package", context.packageName, null)
    }
    context.startActivity(intent)
}
```

### 15.9 Required String Resources

Always generate these string resources when camera/gallery is used:

```xml
<!-- strings.xml -->
<string name="permission_camera_title">Camera Permission Required</string>
<string name="permission_camera_rationale_message">Camera access is needed to take a photo. Please grant the permission to continue.</string>
<string name="permission_camera_denied_message">Camera permission was denied. Please enable it in app settings to use this feature.</string>
<string name="permission_storage_title">Storage Permission Required</string>
<string name="permission_storage_rationale_message">Storage access is needed to select a photo from your gallery.</string>
<string name="permission_storage_denied_message">Storage permission was denied. Please enable it in app settings to use this feature.</string>
<string name="permission_open_settings">Open Settings</string>
<string name="permission_cancel">Cancel</string>
```

### 15.10 Other Runtime Permissions (Non-Camera)

For all other runtime permissions follow the same pattern — request in `Screen`, communicate result to ViewModel via `onEvent()` or `setDialog()`:

| Permission | Trigger |
|---|---|
| `POST_NOTIFICATIONS` | Any push notification feature — request at app start |
| `ACCESS_FINE_LOCATION` | Any map or location-based feature |
| `RECORD_AUDIO` | Any voice input or audio recording feature |
| `READ_CONTACTS` | Any contact selection feature |
| `BLUETOOTH_CONNECT` | Any Bluetooth pairing feature (API 31+) |

### 15.11 Permission Rules Summary

| Rule | Requirement |
|---|---|
| Trigger detection | Auto-generate camera/gallery flow if any image/file UI component present |
| Where to request | `Screen` composable only — never ViewModel or Repository |
| Camera URI | Use `FileProvider` + `TakePicture` contract — never `ACTION_IMAGE_CAPTURE` directly |
| Gallery URI | Use `GetContent("image/*")` contract |
| API guard | `READ_MEDIA_IMAGES` for API 33+, `READ_EXTERNAL_STORAGE` (maxSdkVersion=32) for below |
| Rationale | Show rationale dialog when `shouldShowRationale == true` |
| Permanent denial | Show settings redirect dialog — never silently fail |
| ViewModel callback | File URI delivered via `setSelectedFile(uri)` public function |
| Manifest | Declare all permissions + FileProvider in `AndroidManifest.xml` |
| String resources | Always generate all permission-related string resources |

---

## Rule 16 — Package Structure (UI Code Generation Scope)

> **Scope:** This rule applies exclusively to generated UI code. `domain/` and `data/` layers are out of scope for this guideline and must not be generated unless explicitly requested.

### 16.1 Root Structure

All generated UI code lives under a single `features/presentation/` root. Nothing else.

```
features/
  presentation/
    screen/        ← one subfolder per screen / feature
    component/     ← feature-level shared composables only
```

**Package root:** `com.ictechnology.app.features.presentation`

### 16.2 Screen Package Structure

Each screen gets its **own dedicated subfolder** under `screen/`. All files belonging to that screen — the composable, ViewModel, UiState, Event, FieldState, and enums — live flat inside that one folder. No nested subfolders within a screen package.

```
features/
  presentation/
    screen/
      leave/                          ← leave request screen
        LeaveScreen.kt
        LeaveViewModel.kt
        LeaveUiState.kt
        LeaveEvent.kt
        LeaveRequestFieldState.kt
        LeaveDurationType.kt
        LeaveTab.kt
      leave_detail/                   ← leave detail screen
        LeaveDetailScreen.kt
        LeaveDetailViewModel.kt
        LeaveDetailUiState.kt
        LeaveDetailEvent.kt
      leave_edit/                     ← leave edit screen
        LeaveEditScreen.kt
        LeaveEditViewModel.kt
        LeaveEditUiState.kt
        LeaveEditEvent.kt
        LeaveEditFieldState.kt
      profile/                        ← profile screen
        ProfileScreen.kt
        ProfileViewModel.kt
        ProfileUiState.kt
        ProfileEvent.kt
        ProfileFieldState.kt
      notification/                   ← notification screen
        NotificationScreen.kt
        NotificationViewModel.kt
        NotificationUiState.kt
        NotificationEvent.kt
      home/                           ← home / dashboard screen
        HomeScreen.kt
        HomeViewModel.kt
        HomeUiState.kt
        HomeEvent.kt
    component/                       ← feature-level shared composables
        LeaveTypeBottomSheet.kt
        LeaveHistoryCard.kt
        LeaveBalanceCard.kt
```

### 16.3 Screen Folder Naming Convention

Screen folders use **snake_case** and must be descriptive of the screen's purpose:

| Screen | Folder Name |
|---|---|
| Leave request form | `leave/` |
| Leave detail view | `leave_detail/` |
| Leave edit form | `leave_edit/` |
| User profile | `profile/` |
| Notification list | `notification/` |
| Home / dashboard | `home/` |
| Login | `login/` |
| Register | `register/` |
| Settings | `settings/` |
| Splash / onboarding | `splash/` |

### 16.4 File Ownership Per Screen Folder

Every screen folder follows this exact flat file layout — no subfolders:

```
screen/{feature}/
  {Feature}Screen.kt              ← Screen + ScreenContent composables
  {Feature}ViewModel.kt           ← ViewModel class only
  {Feature}UiState.kt             ← UiState data class + Dialog sealed class
  {Feature}Event.kt               ← Event sealed class
  {Feature}FieldState.kt          ← Field state data class (if screen has a form)
  {Feature}{EnumName}.kt          ← One file per enum (if any)
```

**Examples for the `leave` screen:**

```
screen/leave/
  LeaveScreen.kt
  LeaveViewModel.kt
  LeaveUiState.kt
  LeaveEvent.kt
  LeaveRequestFieldState.kt
  LeaveDurationType.kt
  LeaveTab.kt
```

**Examples for the `profile` screen (no form → no FieldState):**

```
screen/profile/
  ProfileScreen.kt
  ProfileViewModel.kt
  ProfileUiState.kt
  ProfileEvent.kt
```

### 16.5 Package Declarations

Every file in a screen folder must declare the package matching its folder path:

```kotlin
// screen/leave/LeaveViewModel.kt
package com.ictechnology.app.features.presentation.screen.leave

// screen/leave/LeaveUiState.kt
package com.ictechnology.app.features.presentation.screen.leave

// screen/leave/LeaveEvent.kt
package com.ictechnology.app.features.presentation.screen.leave

// screen/leave_detail/LeaveDetailViewModel.kt
package com.ictechnology.app.features.presentation.screen.leave_detail

// component/LeaveHistoryCard.kt
package com.ictechnology.app.features.presentation.component
```

All files within the same screen folder share **identical package declarations** — the package name is the folder path, not the file name.

### 16.6 `component/` — Feature-Shared Composables

The `presentation/component/` folder holds composables that are **reused across more than one screen** but are app-specific (not generic design-system primitives).

```kotlin
// ✅ Belongs in features/presentation/component/
//    — used by both LeaveScreen and LeaveEditScreen
package com.ictechnology.app.features.presentation.component

@Composable
fun LeaveTypeBottomSheet(
    options   : List<LeaveBalance>,
    onSelect  : (LeaveBalance) -> Unit,
    onDismiss : () -> Unit,
    modifier  : Modifier = Modifier
) { ... }
```

**Placement decision:**

| Composable reused by | Where it lives |
|---|---|
| Only one screen | Inside that screen's folder (e.g. `screen/leave/`) |
| Multiple screens in the feature | `presentation/component/` |
| Multiple features across the app | `features/presentation/component/` (in-app shared library — see Rule 13) |

### 16.7 What Does NOT Belong in the Presentation Package

The following must **never** be generated inside `features/presentation/`:

```
❌ features/presentation/domain/        → out of scope for UI generation
❌ features/presentation/data/          → out of scope for UI generation
❌ features/presentation/repository/    → out of scope for UI generation
❌ features/presentation/usecase/       → out of scope for UI generation
❌ features/presentation/screen/leave/
       LeaveRepository.kt               → data layer file in UI package
❌ features/presentation/screen/leave/
       LeaveMapper.kt                   → data layer file in UI package
```

If the generated ViewModel requires a UseCase or Repository, **reference it by import only** — do not generate the implementation.

### 16.8 Complete Package Map (Quick Reference)

```
com.ictechnology.app
  └── features
        └── presentation
              ├── screen
              │     ├── leave
              │     │     ├── LeaveScreen.kt
              │     │     ├── LeaveViewModel.kt
              │     │     ├── LeaveUiState.kt
              │     │     ├── LeaveEvent.kt
              │     │     ├── LeaveRequestFieldState.kt
              │     │     ├── LeaveDurationType.kt
              │     │     └── LeaveTab.kt
              │     ├── leave_detail
              │     │     ├── LeaveDetailScreen.kt
              │     │     ├── LeaveDetailViewModel.kt
              │     │     ├── LeaveDetailUiState.kt
              │     │     └── LeaveDetailEvent.kt
              │     ├── profile
              │     │     ├── ProfileScreen.kt
              │     │     ├── ProfileViewModel.kt
              │     │     ├── ProfileUiState.kt
              │     │     └── ProfileEvent.kt
              │     └── notification
              │           ├── NotificationScreen.kt
              │           ├── NotificationViewModel.kt
              │           ├── NotificationUiState.kt
              │           └── NotificationEvent.kt
              └── component
                    ├── LeaveTypeBottomSheet.kt
                    ├── LeaveHistoryCard.kt
                    └── LeaveBalanceCard.kt
```

### 16.9 Agent Output Requirement

When generating any screen, the agent must:

1. **State the target file path** at the top of every generated file as a comment.
2. **Declare the correct package** matching the file path.
3. **Generate all files** for the screen in one response — `Screen.kt`, `ViewModel.kt`, `UiState.kt`, `Event.kt`, and `FieldState.kt` (if applicable).
4. **Never merge** files from different screens into the same package.

```kotlin
// ✅ Correct — file path comment + package at top of every generated file

// File: features/presentation/screen/leave/LeaveViewModel.kt
package com.ictechnology.app.features.presentation.screen.leave

@HiltViewModel
class LeaveViewModel @Inject constructor(...) : ViewModel() { ... }
```

```kotlin
// File: features/presentation/screen/leave/LeaveUiState.kt
package com.ictechnology.app.features.presentation.screen.leave

data class LeaveUiState( ... )

sealed class LeaveDialog { ... }
```

---

## Updated Quick Reference Checklist

Before finalising any generated screen, verify all of the following:

**Composable Rules**
- [ ] Composable is stateless (`ScreenContent` has no `remember` or VM reference)
- [ ] `modifier: Modifier = Modifier` is the last parameter
- [ ] All colours use `MaterialTheme.colorScheme.*`
- [ ] All typography uses `MaterialTheme.typography.*`
- [ ] All shapes use `MaterialTheme.shapes.*`
- [ ] All strings use `stringResource()`
- [ ] Every icon has a `contentDescription`
- [ ] Touch targets are at least `48.dp × 48.dp`
- [ ] Light mode `@Preview` present
- [ ] Dark mode `@Preview` present
- [ ] `Screen` and `ScreenContent` are separate composables
- [ ] No business logic inside any composable
- [ ] Material 3 components used exclusively
- [ ] `Surface` wraps the root of every screen

**ViewModel Rules**
- [ ] `@HiltViewModel` annotation present
- [ ] State exposed as `StateFlow` via `.asStateFlow()`
- [ ] `onEvent()` is the **only** public entry point for UI actions — no other public action functions
- [ ] `onEvent()` body is wrapped in `viewModelScope.launch { when (event) { ... } }`
- [ ] Every `Event` subtype has an explicit branch in the `when` block — no `else` catch-all
- [ ] UI-only events marked as `Unit //Handle on UI` in the `when` block
- [ ] State updated via `_state.update { it.copy(...) }` only
- [ ] Heavy I/O wrapped in `withContext(ioDispatcher) { }`
- [ ] Dialog state managed via `Dialog` sealed class
- [ ] Validation delegated to injected `Validator` class
- [ ] Use case results handled via `Resource.Success` / `Resource.Error` `when` expression

**File Structure Rules (STRICT — ZERO EXCEPTIONS)**
- [ ] `<Feature>ViewModel.kt` contains ONLY the ViewModel class — no state classes
- [ ] `UiState` data class is in its own `<Feature>UiState.kt` file
- [ ] `Dialog` sealed class is in `<Feature>UiState.kt` alongside `UiState`
- [ ] `Event` sealed class is in its own `<Feature>Event.kt` file
- [ ] `FieldState` data class is in its own `<Feature>FieldState.kt` file
- [ ] Each enum (e.g. `Tab`, `DurationType`) has its own dedicated `.kt` file
- [ ] All files in the same feature share the same `package` declaration
- [ ] ViewModel imports `UiState`, `Event`, `FieldState` from their own files — not declared inline

**Package Structure Rules**
- [ ] All generated files live under `features/presentation/screen/{feature}/`
- [ ] File path comment present at the top of every generated file
- [ ] Package declaration matches the file path exactly
- [ ] Screen folder name uses `snake_case`
- [ ] No subfolders created inside a screen folder — all files are flat
- [ ] Composables shared across multiple screens placed in `presentation/component/`
- [ ] No `domain/`, `data/`, `repository/`, or `usecase/` generated inside `presentation/`
- [ ] All screen files generated together in one response

**Component Rules**
- [ ] All buttons use `features.presentation.component.button.AppButton` — not raw `androidx.compose.material3.Button`
- [ ] All text fields use `features.presentation.component.textfield.CommonTextField` (or the appropriate variant)
- [ ] All dialogs driven by a `Dialog` sealed class using `features.presentation.component.dialog` components (`NormalDialog`, `ConfirmationDialog`)
- [ ] Missing components created in `features.presentation.component` — never raw M3 in a screen (Rule 13.2)
- [ ] Icons follow priority order: VectorDrawable from design file → Material Icons (utility only) → app icon set → Coil remote
- [ ] Design-provided icons exported as SVG → converted to VectorDrawable → placed in `app/src/main/res/drawable/`
- [ ] Material Icons used **only** for standard utility actions where no design asset exists
- [ ] Custom icons follow naming: `ic_<feature>_<description>.xml`
- [ ] Remote images use `AsyncImage` (Coil) with placeholder and error fallback

**Permission Rules (Camera / Gallery)**
- [ ] If any image/file UI component present → full camera + gallery permission flow generated
- [ ] `CAMERA`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE` (maxSdkVersion=32) declared in `AndroidManifest.xml`
- [ ] `FileProvider` declared in `AndroidManifest.xml` with `file_provider_paths.xml`
- [ ] Camera uses `TakePicture` contract + `FileProvider` URI — never `ACTION_IMAGE_CAPTURE` directly
- [ ] Gallery uses `GetContent("image/*")` contract
- [ ] `READ_MEDIA_IMAGES` used for API 33+, `READ_EXTERNAL_STORAGE` for API 32 and below
- [ ] `shouldShowRationale` case handled with a rationale dialog
- [ ] Permanent denial handled with settings redirect dialog
- [ ] File URI delivered to ViewModel via `setSelectedFile(uri)` public function
- [ ] All permission string resources generated in `strings.xml`

---

*This guideline is maintained by the Android Development Team. Update this document when official Android guidelines change or new team conventions are adopted.*
