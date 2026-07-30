# Compose UI Rules — Compact (R1–R16)

> Normative ruleset, **no code**. Code patterns live in `examples/*.md` — load an example
> file only when a stage emits that kind of artifact. Every rule keeps its original ID so
> `file:line` self-checks and the plan's `rule:` fields stay valid.
>
> Load-map (which examples a stage needs):
> - Composables (Screen/Content) → `examples/composable.md`
> - ViewModel / UiState / Event / FieldState → `examples/viewmodel.md`
> - Icons / images → `examples/icons.md`
> - Camera / gallery / file picker → `examples/permissions.md`  ← load ONLY if a picker is present
> - Package layout / file-path headers → `examples/package.md`

---

## R1 — Jetpack Compose + official guidelines
- **R1.1** All UI in Jetpack Compose. No XML layouts, no `View` code, no `AndroidView` unless explicitly asked. Use the latest stable Compose BOM.
- **R1.2** Only documented, non-deprecated APIs. `material3`, never `material` (M2).
- **R1.3** Source priority: official Compose docs → Now in Android → compose-samples → M3 for Compose.

## R2 — Stateless composable architecture
- **R2.1** Every composable is stateless unless told otherwise: all data via params, interactions via lambda callbacks, no internal `remember`/`mutableStateOf`/`LaunchedEffect` driving business logic. Pure render fn.
- **R2.2** State is hoisted to the caller. `Screen` (stateful, has ViewModel) delegates to `ScreenContent` (stateless).
- **R2.3** Param order: data first → callbacks (`on…`) → `modifier: Modifier = Modifier` **always last, always defaulted**.
- **R2.4** Every screen has a `UiState` — `data class` (simple) or `sealed class` (distinct modes: Idle/Loading/Success/Error).

## R3 — Material 3 design system
- **R3.1** M3 components from `androidx.compose.material3` only. Never `androidx.compose.material`. Prefer built-in M3 before custom.
- **R3.2** Typography via `MaterialTheme.typography.*` — never raw `fontSize`.
- **R3.3** Colour via `MaterialTheme.colorScheme.*` — never raw `Color(0xFF…)` in layout code.
- **R3.4** Shape via `MaterialTheme.shapes.*` — never raw `RoundedCornerShape`.
- **R3.5** Spacing on a 4.dp scale; use/define a `Spacing` object.

## R4 — Dark mode
- **R4.1** `AppTheme` defines **both** `lightColorScheme` and `darkColorScheme`. Every screen is compatible with it.
- **R4.2** No non-dark-aware hardcoded colours. Test light+dark previews. `Surface` at the root of every screen applies background.

## R5 — Previews
- **R5.1** Every composable has ≥1 `@Preview`. Screens: ≥2 (light + dark, dark via `uiMode = UI_MODE_NIGHT_YES`).
- **R5.2** Preview fns are `private`, wrapped in `AppTheme { }`, pass realistic fake data (never empty strings), `showBackground = true`. Lists/cards use `@PreviewParameter` + provider.
- **R5.3** Full screens also get device previews (`Devices.PIXEL_7`, `PIXEL_TABLET`, `showSystemUi = true`).

## R6 — Accessibility
- **R6.1** Every `Icon`/`Image`/non-text interactive element has `contentDescription` from `stringResource()`. Decorative images set `contentDescription = null` explicitly (not `""`).
- **R6.2** Custom interactive elements use `Modifier.semantics { }` + `Role`.
- **R6.3** Interactive targets ≥ 48.dp × 48.dp.
- **R6.4** Forms define explicit focus traversal (`FocusRequester`); logical reading order.

## R7 — Screen vs Content split
- **R7.1** Every screen = `…Screen` (stateful: ViewModel + navigation, not unit-tested) + `…ScreenContent` (stateless pure UI, unit-tested).
- **R7.2** Navigation lives in `Screen` only, passed in as lambda params; never inside `Content`. Side effects (e.g. navigate on Success) via `LaunchedEffect` in `Screen`.

## R8 — Code quality
- **R8.1** Naming: composable = PascalCase noun; preview = PascalCase + `Preview`, `private`; state = `…UiState`; callback = camelCase `on…`; modifier param named `modifier`; string res = snake_case with screen prefix.
- **R8.2** No wildcard imports. Group: Android → Compose → Kotlin → Project.
- **R8.3** Composable body ≤ 60 lines; extract sub-composables beyond that.
- **R8.4** No business logic in composables (no `if/else` business rules, transforms, API calls) — logic lives in ViewModel/UseCase; UI renders already-computed values.

## R9 — Strings localization
- **R9.1** All user-facing text via `stringResource(R.string.*)`. Never raw literals in `Text()`, `contentDescription`, `placeholder`.
- **R9.2** Key naming: `<screen>_<component>_<description>` (e.g. `login_label_email`).

## R10 — Agent behaviour
- **R10.1** Always: generate both `Screen`+`ScreenContent`; light+dark preview per Content; theme tokens for colour/type/shape; `contentDescription` on every icon/image; `stringResource()` for all text; `modifier` last param; a `UiState` per screen; `Surface` root with `colorScheme.background`.
- **R10.2** Never: XML layouts; M2 components; hardcoded colours/sizes/strings; `remember { mutableStateOf() }` in `Content`; VM calls/DI inside `Content`; `Context` in a composable; composables without `@Preview`; `AndroidView` unless asked.
- **R10.3** Output order per screen: `UiState` → `ScreenContent` → `Screen` → previews (light+dark) → sub-composables → `strings.xml` entries.

## R11 — ViewModel structure  (examples/viewmodel.md)
- **R11.1** `@HiltViewModel` + `@Inject constructor(...)`. Inject `Context` via `@param:ApplicationContext` (never Activity). Inject dispatcher via `@param:IoDispatcher` (never hardcode `Dispatchers.IO`). Group with `/*region*/`.
- **R11.2** Internal state: `private` `MutableStateFlow`. Exposed: `.asStateFlow()` `val` (never `var`, never expose mutable). One-shot events via `private MutableSharedFlow` → exposed `SharedFlow`.
- **R11.3** ⛔ **STRICT** — `onEvent(event: <Feature>Event)` is the **only** public UI entry point. Body wrapped in `viewModelScope.launch { when(event){…} }`. Every sealed subtype has an explicit branch; **no `else`**. UI-only events (nav, launch picker/camera, deep link) appear in the `when` as `Unit //Handle on UI`. Individual public action fns (`onSubmitClicked()`, `onDateChanged()`, …) are **forbidden**.
- **R11.3.4** Only these public fns may accompany `onEvent()`: `initEditScreen(id)`, `setSelectedFile(uri)`, `selectItem(item)`, `setDialog(dialog)`, `resetFormState()`, `byPassLockScreen()` (and close equivalents). Anything else → convert to an `Event`.
- **R11.4** Update state only via `_state.update { it.copy(...) }`. Never `_state.value = …`, never full-object reassignment.
- **R11.5** Async only in `viewModelScope.launch { }`; heavy I/O in `withContext(ioDispatcher){ }`. No `GlobalScope`/raw scopes. `@OptIn(ExperimentalCoroutinesApi::class)` only with documented reason.
- **R11.6** All loading/error/success/confirmation dialogs via a single `Dialog` sealed class in `UiState`, driven by `setDialog(...)`; set `Loading` at async start → resolve to `Default`/`Success`/`Error`.
- **R11.7** Input validation delegated to an injected `Validator` (returns `null` on success or typed error). No inline validation in the VM.
- **R11.8** UseCases return `Resource<T>`/`Result<T>`. Handle `Success`/`Error` in a `when` (no `if/else`, no `try/catch`). Errors via `error.asString(context)` — never hardcoded.

## R12 — UiState in its own file  (examples/viewmodel.md)
- **R12.0** ⛔ **STRICT** — `<Feature>ViewModel.kt` contains **only** the ViewModel class. Nothing else.
- **R12.1** Forbidden inside the VM file: `UiState`, `Dialog`, `Event`, `FieldState`, any `enum`. Their presence = invalid output, regenerate.
- **R12.2** One class per file. Layout per screen: `…ViewModel.kt` (class only), `…UiState.kt` (UiState + Dialog), `…Event.kt` (Event), `…FieldState.kt` (if form), `<Enum>.kt` (one enum each).
- **R12.4** `…UiState.kt` = `UiState` data class **+** the `Dialog` sealed class (same file, same concern).
- **R12.5** `…FieldState.kt` = form field-state data class only (only if `has_form`).
- **R12.6** `…Event.kt` = `Event` sealed class only.
- **R12.7** Self-check before emitting VM code: VM file has only the class; no data/sealed/enum in it; UiState/FieldState/Event/enums each in own file; all share one package; VM imports them.

## R13 — In-app reusable components  (examples/composable.md)
- **R13.1** ⛔ **STRICT** — source every UI component from `com.ictechnology.app.features.presentation.component.<subpackage>` (`button`, `textfield`, `dialog`, `picker`, `appbar`, `loading`, `tab`, `paging`, …). Never raw M3 in a feature screen.
- **R13.2** If a needed component is genuinely absent, **create it** in the matching subpackage — never fall back to raw M3.
- **R13.3** Use the component's **actual** signature — verify against its source file before generating (loading driven by `UiState`; dialogs driven by the `Dialog` sealed class).
- **R13.4** New component: file under `component/<subpackage>/<Name>.kt`, correct package, fully stateless, styling via `UiStyle`, light+dark `@Preview` under `component/preview/`, KDoc — then use it.

## R14 — Icon & image assets  (examples/icons.md)
- **R14.1** Icon source priority (always try 1 first): **P1** SVG/PNG from design → VectorDrawable (preferred, pixel-perfect brand). **P2** Material Icons Extended (utility only, no design asset). **P3** existing app drawable. **P4** remote URL via Coil `AsyncImage`.
- **R14.2** P1: export SVG → convert to VectorDrawable → `app/src/main/res/drawable/ic_<feature>_<desc>.xml` → `painterResource`.
- **R14.3** P2 only for standard utility icons with no design asset (back, close, search, more, share, settings, check, visibility, add, delete). A design-provided version of any of these → P1 still applies.
- **R14.4** P3: reused icons already in `res/drawable/` — check before converting a new SVG.
- **R14.5** P4: Coil `AsyncImage` for API-returned URLs, with placeholder + error fallback (a P1/P3 asset).
- **R14.6** Naming `ic_<feature>_<description>.xml`; shared/utility → `ic_common_<name>.xml`.
- **R14.7** Decision flow: design asset? → P1. Else standard utility? → P2. Else exists in drawables? → P3. Else dynamic URL? → P4.
- **R14.8** All priorities: `tint = MaterialTheme.colorScheme.*` (never hardcode); default `Modifier.size(24.dp)` unless design differs; meaningful `contentDescription` from `stringResource()`; decorative → `contentDescription = null` explicitly.

## R15 — Runtime permissions (camera/gallery)  (examples/permissions.md — load ONLY if a picker is present)
- **R15.1** ⛔ **Trigger** — if the design has any image/photo/file selection (avatar/photo upload, attachment/document field, camera button, `AppImagePickerField`/`AppFileUploadField`, or anything labelled upload/attach/photo/camera/gallery/choose file) → generate the full camera+gallery permission flow. Not optional.
- **R15.2** Permissions: camera → `CAMERA`; gallery/image → `READ_MEDIA_IMAGES` (API 33+) / `READ_EXTERNAL_STORAGE` (≤32); file → add `READ_MEDIA_VIDEO`/`_AUDIO` (33+).
- **R15.3** Manifest always declares `CAMERA`, `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`), and a `FileProvider` (`${applicationId}.provider`) + `res/xml/file_provider_paths.xml`.
- **R15.4** Dependency: `accompanist-permissions`.
- **R15.5** Permission requesting happens in the **`Screen`** composable only. Camera via `TakePicture` contract + `FileProvider` URI (never `ACTION_IMAGE_CAPTURE`). Gallery via `GetContent("image/*")`. API-guard the storage permission.
- **R15.6** Camera/gallery choice via `AppImagePickerField` (bottom sheet) from the component package (create per R13.2 if absent).
- **R15.7** File URI delivered to the VM via a dedicated public `setSelectedFile(uri)` (not through `onEvent`).
- **R15.8** Handle `shouldShowRationale` (rationale dialog) and permanent denial (settings-redirect dialog) — never silently fail.
- **R15.9** Always generate the permission string resources (`permission_camera_*`, `permission_storage_*`, `permission_open_settings`, `permission_cancel`).
- **R15.10** Other permissions (notifications, location, audio, contacts, bluetooth) follow the same shape: request in `Screen`, report result via `onEvent()`/`setDialog()`.

## R16 — Package structure (UI scope)  (examples/package.md)
- **R16.0** ⛔ Generated code lives **only** under `features/presentation/`. `domain/` and `data/` are out of scope — reference UseCases/Repositories by import, never generate them.
- **R16.1** Root: `features/presentation/{screen/, component/}`. Package root `com.ictechnology.app.features.presentation`.
- **R16.2** Each screen has its own flat subfolder under `screen/` — all its files (Screen, VM, UiState, Event, FieldState, enums) directly inside, no nested subfolders.
- **R16.3** Screen folders are `snake_case`, descriptive (`leave`, `leave_detail`, `profile`, `splash`, …).
- **R16.4** Per-folder files: `{Feature}Screen.kt`, `{Feature}ViewModel.kt`, `{Feature}UiState.kt`, `{Feature}Event.kt`, `{Feature}FieldState.kt` (if form), `{Feature}{Enum}.kt` (one each).
- **R16.5** Every file declares the package matching its folder path (singular `screen/`, `component/`); all files in a folder share it.
- **R16.6** `component/` placement: one screen → that screen's folder; multiple screens in a feature → `presentation/component/`; multiple features → `features.presentation.component` (Rule 13).
- **R16.7** Never under `presentation/`: `domain/`, `data/`, `repository/`, `usecase/`, mappers, or any data-layer file. Reference by import only.
- **R16.9** Output: file-path comment at top of every file; correct package; **all files for a screen in one response**; never merge files from different screens.

---

## Stage-5 validation checklist (condensed)
Report ✅/❌ with `file:line`:
- One class per file; UiState/Event/FieldState in separate files (R12.2, R12.7).
- VM: `onEvent()`-only public entry, no extra public mutators, `when` exhaustive no-`else` (R11.3).
- Package matches folder, singular `screen/`/`component/` (R16.5).
- No raw M3 where a component-package equivalent exists (R13.1).
- Stateless `Content`, state hoisted, `modifier` last+defaulted (R2).
- Light+dark `@Preview` (R5); a11y contentDescription/roles/48dp (R6); no hardcoded strings (R9); theme tokens only (R3); `Surface` root (R4).
- No `domain/`/`data/`/`repository/`/`usecase/` files generated (R16.7).
- If a picker exists: manifest perms + FileProvider + `file_provider_paths.xml`, `TakePicture`+`GetContent`, rationale + permanent-denial handled, `setSelectedFile()` (R15).
