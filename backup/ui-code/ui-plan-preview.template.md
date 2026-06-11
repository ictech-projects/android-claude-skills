# UI Codegen Plan Preview — STUB

> Machine-readable plan: [`ui-plan.template.yaml`](./ui-plan.template.yaml) · Pipeline: [`ui-codegen-pipeline.md`](./ui-codegen-pipeline.md)
> Screens: **2** (example) · Pending decisions: **7**

**Stage 0 preconditions:** `AppTheme` (light+dark), typography/shapes tokens, the
`features.presentation.component` package, and `strings.xml` confirmed present — **do not regenerate** the theme. Material 3 only.

> ⚠️ **This is a STUB.** The `leave` and `profile` screens below are illustrative examples
> mirroring `ui-plan.yaml`. Stage 1 replaces them with the screens extracted from your design.

---

## Section 1 — Folder Tree

> Paths shown relative to `app/src/main/java/com/ictechnology/app/`.

```
features/presentation/
├── screen/                             # one subfolder per screen (R16.1, R16.2)
│   ├── leave/                          # form + enums + document upload
│   │   ├── LeaveScreen.kt              # Screen + ScreenContent      (R7.1)
│   │   ├── LeaveViewModel.kt           # ViewModel class ONLY        (R12.0)
│   │   ├── LeaveUiState.kt             # UiState + LeaveDialog        (R12.4)
│   │   ├── LeaveEvent.kt               # Event sealed class          (R12.6)
│   │   ├── LeaveRequestFieldState.kt   # form field state            (R12.5)
│   │   ├── LeaveDurationType.kt        # enum — one per file         (R12.2)
│   │   └── LeaveTab.kt                 # enum — one per file
│   └── profile/                        # avatar, no form fields
│       ├── ProfileScreen.kt
│       ├── ProfileViewModel.kt
│       ├── ProfileUiState.kt           # UiState + ProfileDialog
│       └── ProfileEvent.kt             # (no FieldState — has_form: false)
└── component/                          # in-app reusable + feature-shared (R13, R16.6)
    ├── button/AppButton.kt             # EXISTS — reuse                    (R13.1)
    ├── textfield/AppTextField.kt       # EXISTS — reuse                    (R13.1)
    ├── picker/AppDatePickerField.kt    # ⚠️ CREATE in package (pending)    (R13.2)
    ├── picker/AppImagePickerField.kt   # ⚠️ CREATE in package (pending)    (R13.2)
    └── LeaveTypeBottomSheet.kt         # feature-shared — used by leave + leave_edit (R16.6)

app/src/main/
├── res/drawable/
│   ├── ic_common_back_arrow.xml        # EXISTS — reuse (P3)
│   ├── ic_leave_calendar.xml           # NEW — SVG→VectorDrawable (P1, pending)
│   ├── ic_leave_attachment.xml         # NEW — SVG→VectorDrawable (P1, pending)
│   └── ic_profile_edit.xml             # NEW — SVG→VectorDrawable (P1, pending)
├── res/values/strings.xml             # + new keys (see Section 4)
├── res/xml/file_paths.xml             # NEW — FileProvider paths (R15.3)
└── AndroidManifest.xml                # + CAMERA / READ_MEDIA_* / FileProvider
```

---

## Section 2 — Shared Asset Analysis

```
SHARED ASSETS — REVIEW REQUIRED
════════════════════════════════════════════════════════

COMPONENTS
  AppButton              exists in package   → reuse
  AppTextField           exists in package   → reuse
  AppDatePickerField     NOT in package      → create_new                          [pending]
  AppImagePickerField    NOT in package      → create_new                          [pending]

FEATURE COMPONENT (reused by >1 screen → presentation/component, R16.6)
  LeaveTypeBottomSheet   used_by: leave, leave_edit
                         → screen_local | presentation/component | features_component  [pending]

ICONS
  ic_common_back_arrow   P3 app_existing     → reuse                               [confirm]

════════════════════════════════════════════════════════
Total shared decisions pending: 4
```

### Placement guidance (R16.6)

| Reused by | Lives in |
|---|---|
| One screen only | that screen's folder |
| Multiple screens in this feature | `presentation/component/` |
| Multiple features across the app | `features.presentation.component` (in-app library — see Rule 13) |

---

## Section 3 — Decisions Summary (Stage 3 gate)

```
DECISIONS — REVIEW REQUIRED
──────────────────────────────────────────────────────────────────────
GLOBAL
  state_shape_default        data_class | sealed_class        → data_class  ✓ set
  spacing_scale              exists | create                  → pending

SHARED COMPONENTS
  AppDatePickerField         create_new                       → pending
  AppImagePickerField        create_new                       → pending
  LeaveTypeBottomSheet       placement                        → pending

ICONS
  ic_common_back_arrow       P3 reuse                         → confirm
  ic_leave_calendar          P1 SVG→VectorDrawable            → pending
  ic_leave_attachment        P1 SVG→VectorDrawable            → pending
  ic_profile_edit            P1 SVG→VectorDrawable            → pending
──────────────────────────────────────────────────────────────────────
Stage 3 will not run until every decision above is set in ui-plan.yaml.
```

---

## Section 4 — New String Keys (R9.2)

Naming: `<screen>_<component>_<desc>`

```
leave_button_submit
leave_placeholder_reason
leave_label_duration
profile_label_photo
```

---

## Section 5 — Per-Screen Summary

| Screen | Folder | has_form | state_shape | Files | Permission trigger |
|---|---|---|---|---|---|
| leave | `screen/leave/` | yes | data_class | 7 | document picker (R15.1) |
| profile | `screen/profile/` | no | data_class | 4 | avatar picker (R15.1) |
