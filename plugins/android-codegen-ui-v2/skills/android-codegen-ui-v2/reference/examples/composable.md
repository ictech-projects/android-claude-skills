# Examples — Composables (R2–R7, R13 usage)

Load this when generating a `Screen`/`ScreenContent` or a reusable component. Rules are in
`rules-compact.md`; this file is patterns only.

## Stateless Content + stateful Screen (R2.2, R7.1)

```kotlin
// ✅ Stateless Content — state DOWN, events UP, modifier last & defaulted
@Composable
fun LoginScreenContent(
    state            : LoginUiState,
    onEmailChange    : (String) -> Unit,
    onPasswordChange : (String) -> Unit,
    onLoginClick     : () -> Unit,
    modifier         : Modifier = Modifier
) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        // pure UI — no business logic, no remember driving logic
    }
}

// ✅ Stateful Screen — ViewModel + navigation live here (R7.2)
@Composable
fun LoginScreen(
    onNavigateToHome: () -> Unit,
    viewModel       : LoginViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    LaunchedEffect(state) { if (state is LoginUiState.Success) onNavigateToHome() }
    LoginScreenContent(
        state            = state,
        onEmailChange    = { viewModel.onEvent(LoginEvent.EmailInput(it)) },
        onPasswordChange = { viewModel.onEvent(LoginEvent.PasswordInput(it)) },
        onLoginClick     = { viewModel.onEvent(LoginEvent.Submit) }
    )
}
```

```kotlin
// ❌ WRONG — state owned inside Content
@Composable
fun LoginScreenContent() {
    var email by remember { mutableStateOf("") }   // ❌ never own state in Content
}
```

## Parameter ordering (R2.3)

```kotlin
@Composable
fun UserCard(
    name       : String,                 // 1. data
    avatarUrl  : String,
    isOnline   : Boolean,
    onClick    : () -> Unit,              // 2. callbacks
    onLongClick: () -> Unit = {},
    modifier   : Modifier = Modifier      // 3. modifier last + default
)
```

## Theme tokens (R3.2–R3.5) — never hardcode

```kotlin
Text(text = title, style = MaterialTheme.typography.titleLarge)      // ✅ not fontSize = 22.sp
Surface(color = MaterialTheme.colorScheme.surface) { }               // ✅ not Color(0xFF…)
Card(shape = MaterialTheme.shapes.medium) { }                        // ✅ not RoundedCornerShape(8.dp)

object Spacing { val xs = 4.dp; val sm = 8.dp; val md = 16.dp; val lg = 24.dp; val xl = 32.dp }
```

## Surface root for dark mode (R4.2)

```kotlin
@Composable
fun HomeScreenContent(state: HomeUiState, modifier: Modifier = Modifier) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        // content — inherits dark/light background automatically
    }
}
```

## Previews (R5)

```kotlin
@Preview(name = "Light", showBackground = true)
@Preview(name = "Dark",  showBackground = true, uiMode = UI_MODE_NIGHT_YES)
@Composable
private fun LoginScreenContentPreview() {          // private, AppTheme, realistic data
    AppTheme {
        LoginScreenContent(
            state = LoginUiState.Idle, onEmailChange = {}, onPasswordChange = {}, onLoginClick = {}
        )
    }
}

// Lists/cards — PreviewParameter provider
class UserCardPreviewProvider : PreviewParameterProvider<UserCardState> {
    override val values = sequenceOf(
        UserCardState(name = "Budi Santoso", isOnline = true),
        UserCardState(name = "Sari Dewi",    isOnline = false),
    )
}

// Full screens — device previews (R5.3)
@Preview(name = "Phone",  device = Devices.PIXEL_7,      showSystemUi = true)
@Preview(name = "Tablet", device = Devices.PIXEL_TABLET, showSystemUi = true)
@Composable
private fun HomeScreenPreview() { AppTheme { HomeScreenContent(state = fakeSuccess) } }
```

## Accessibility (R6)

```kotlin
Icon(imageVector = Icons.Default.Favorite,
     contentDescription = stringResource(R.string.accessibility_favourite_button))   // ✅

Image(painter = painterResource(R.drawable.bg_banner), contentDescription = null)    // ✅ decorative

Box(modifier = Modifier
    .clickable(onClick = onToggle, role = Role.Switch)
    .semantics { contentDescription = if (isEnabled) "Disable notifications" else "Enable notifications" })

IconButton(onClick = onClose, modifier = Modifier.size(48.dp)) {                     // ✅ 48dp target
    Icon(Icons.Default.Close, contentDescription = stringResource(R.string.accessibility_close))
}
```

## No business logic in composables (R8.4)

```kotlin
// ❌ formatting/logic in UI
@Composable fun PriceText(price: Double) {
    val text = if (price > 1000) "%.2fK".format(price/1000) else "%.2f".format(price)  // ❌
    Text(text)
}
// ✅ ViewModel formats; UI just renders
@Composable fun PriceText(formattedPrice: String, modifier: Modifier = Modifier) {
    Text(text = formattedPrice, modifier = modifier)
}
```

## In-app component usage (R13.1, R13.3) — never raw M3 in a screen

```kotlin
import com.ictechnology.app.features.presentation.component.button.AppButton
import com.ictechnology.app.features.presentation.component.textfield.CommonTextField
import com.ictechnology.app.features.presentation.component.dialog.NormalDialog
import com.ictechnology.app.features.presentation.component.loading.LoadingComponent

AppButton(
    modifier = Modifier.fillMaxWidth(),
    style    = UiStyle.Primary,
    label    = stringResource(R.string.common_button_submit),
    enable   = !state.isLoading,
    onClickListener = { onEvent(LeaveEvent.Submit) }
)

if (state.isLoading) LoadingComponent(message = stringResource(R.string.common_loading))

when (val dialog = state.leaveDialog) {                       // dialogs driven by UiState (R11.6)
    is LeaveDialog.Message      -> NormalDialog(title = dialog.title, message = dialog.message,
        confirmLabel = stringResource(R.string.common_ok), uiStyle = UiStyle.Primary,
        onConfirm = { onEvent(LeaveEvent.DismissDialog) }, icon = {})
    LeaveDialog.None            -> Unit
}
```

## New component (R13.4)
Stateless, `UiStyle`-driven, light+dark `@Preview` under `component/preview/`, KDoc, correct
package (`…features.presentation.component.<subpackage>`) — then import & use it.
