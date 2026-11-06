# Examples — Package Structure (R16)

Load when laying out files or writing file-path headers. Base package
`com.ictechnology.app.features.presentation`.

## Per-screen flat folder (R16.2, R16.4)

```
features/presentation/
  screen/
    leave/                          # snake_case (R16.3)
      LeaveScreen.kt                # Screen + ScreenContent      (R7.1)
      LeaveViewModel.kt             # ViewModel class ONLY        (R12.0)
      LeaveUiState.kt               # UiState + LeaveDialog        (R12.4)
      LeaveEvent.kt                 # Event sealed class          (R12.6)
      LeaveRequestFieldState.kt     # only if has_form            (R12.5)
      LeaveDurationType.kt          # one enum per file           (R12.2)
    profile/                        # no form → no FieldState
      ProfileScreen.kt
      ProfileViewModel.kt
      ProfileUiState.kt
      ProfileEvent.kt
  component/                        # reused by >1 screen (R16.6)
    LeaveTypeBottomSheet.kt
```

## File-path header + package (R16.5, R16.9)

```kotlin
// File: features/presentation/screen/leave/LeaveViewModel.kt
package com.ictechnology.app.features.presentation.screen.leave

// File: features/presentation/screen/leave_detail/LeaveDetailUiState.kt
package com.ictechnology.app.features.presentation.screen.leave_detail

// File: features/presentation/component/LeaveHistoryCard.kt
package com.ictechnology.app.features.presentation.component
```

Every file for a screen ships in one response; all files in a folder share one package.

## Placement decision (R16.6)

| Reused by | Lives in |
|---|---|
| One screen only | that screen's folder |
| Multiple screens in this feature | `presentation/component/` |
| Multiple features across the app | `features.presentation.component` (Rule 13) |

## Out of scope — never generate under presentation/ (R16.7)

```
❌ features/presentation/domain|data|repository|usecase/…
❌ features/presentation/screen/leave/LeaveRepository.kt   (data-layer file in UI package)
❌ features/presentation/screen/leave/LeaveMapper.kt
```
Reference UseCases/Repositories by import only — the `android-codegen-non-ui` plugin owns them.
