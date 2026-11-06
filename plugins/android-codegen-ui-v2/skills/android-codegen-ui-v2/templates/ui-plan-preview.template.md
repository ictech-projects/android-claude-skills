# UI Codegen Plan Preview — STUB (v2)

> Machine-readable plan: [`ui-plan.template.yaml`](./ui-plan.template.yaml) · Pipeline: [`../reference/ui-codegen-pipeline.md`](../reference/ui-codegen-pipeline.md)
> Screens: **2** (example) · Pending decisions: **6**

**Stage 0 preconditions:** `AppTheme` (light+dark), typography/shapes tokens, the
`features.presentation.component` package, and `strings.xml` confirmed present — **do not regenerate**
the theme. Material 3 only.

> ⚠️ **This is a STUB.** The `splash` + `leave` screens below are illustrative examples mirroring
> `ui-plan.yaml`. Stage 2 replaces them with the screens extracted from your design.

---

## Section 1 — Folder Tree

> Paths relative to `app/src/main/java/com/ictechnology/app/`.

```
features/presentation/
├── screen/
│   ├── splash/                         # minimal, pickerless (1 text, 1 icon, 1 loader)
│   │   ├── SplashScreen.kt             # Screen + ScreenContent      (R7.1)
│   │   ├── SplashViewModel.kt          # ViewModel class ONLY        (R12.0)
│   │   ├── SplashUiState.kt            # UiState + SplashDialog        (R12.4)
│   │   └── SplashEvent.kt              # (no FieldState — has_form: false)
│   └── leave/                          # form + enums + document upload (picker)
│       ├── LeaveScreen.kt
│       ├── LeaveViewModel.kt
│       ├── LeaveUiState.kt
│       ├── LeaveEvent.kt
│       ├── LeaveRequestFieldState.kt   # form field state            (R12.5)
│       ├── LeaveDurationType.kt        # enum — one per file         (R12.2)
│       └── LeaveTab.kt
└── component/
    ├── loading/AppLoadingComponent.kt  # EXISTS — reuse              (R13.1)
    ├── picker/AppDatePickerField.kt    # ⚠️ CREATE (pending)         (R13.2)
    ├── picker/AppImagePickerField.kt   # ⚠️ CREATE (pending)         (R13.2)
    └── LeaveTypeBottomSheet.kt         # feature-shared              (R16.6)

app/src/main/
├── res/drawable/
│   ├── ic_splash_logo.xml              # NEW — SVG→VectorDrawable (P1, pending)
│   ├── ic_leave_calendar.xml           # NEW — SVG→VectorDrawable (P1, pending)
│   └── ic_leave_attachment.xml         # NEW — SVG→VectorDrawable (P1, pending)
├── res/values/strings.xml              # + new keys (Section 4)
├── res/xml/file_provider_paths.xml     # NEW — FileProvider paths (leave only, R15.3)
└── AndroidManifest.xml                 # + CAMERA / READ_MEDIA_* / FileProvider (leave only)
```

---

## Section 2 — Shared Asset Analysis

```
COMPONENTS
  AppLoadingComponent    exists in package   → reuse
  AppButton              exists in package   → reuse
  AppTextField           exists in package   → reuse
  AppDatePickerField     NOT in package      → create_new              [pending]
  AppImagePickerField    NOT in package      → create_new              [pending]

FEATURE COMPONENT (reused by >1 screen → presentation/component, R16.6)
  LeaveTypeBottomSheet   used_by: leave, leave_edit                    [pending]

ICONS
  ic_common_back_arrow   P3 app_existing     → reuse                   [confirm]
```

---

## Section 3 — Decisions Summary (Stage 3 gate)

```
GLOBAL
  state_shape_default    data_class | sealed_class   → data_class  ✓ set
  spacing_scale          exists | create             → pending

SHARED
  AppDatePickerField     create_new                  → pending
  AppImagePickerField    create_new                  → pending
  LeaveTypeBottomSheet   placement                   → pending
  ic_common_back_arrow   P3 reuse                    → confirm
  ic_splash_logo         P1 SVG→VectorDrawable       → pending
  ic_leave_calendar      P1 SVG→VectorDrawable       → pending
  ic_leave_attachment    P1 SVG→VectorDrawable       → pending
──────────────────────────────────────────────────────────────────
Stage 3 will not run until every decision above is set in ui-plan.yaml.
```

---

## Section 4 — New String Keys (R9.2)

```
splash_label_tagline
leave_button_submit
leave_placeholder_reason
leave_label_duration
```

---

## Section 5 — Per-Screen Summary

| Screen | Folder | has_form | state_shape | Files | Picker | examples[] loaded at Stage 4 |
|---|---|---|---|---|---|---|
| splash | `screen/splash/` | no | data_class | 4 | — | composable, viewmodel, icons, package |
| leave | `screen/leave/` | yes | data_class | 7 | document (R15.1) | composable, viewmodel, icons, permissions, package |
