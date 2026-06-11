# Compose UI Code-Generation Pipeline

> **Rules source of truth:** [`compose-ui-agent-guidelines.md`](./compose-ui-agent-guidelines.md)
> **Machine-readable stage defs:** [`ui-codegen-pipeline.yaml`](./ui-codegen-pipeline.yaml)
> **Plan stubs:** [`ui-plan.template.yaml`](./ui-plan.template.yaml) · [`ui-plan-preview.template.md`](./ui-plan-preview.template.md)

This pipeline turns a design (Figma / spec) into Jetpack Compose screens that obey
every rule in `compose-ui-agent-guidelines.md`. It mirrors the non-UI codegen pipeline
(`plan.yaml` + `plan-preview.md`): a staged flow with **one human gate** after planning,
driving two artifacts — `ui-plan.yaml` (machine-readable) and `ui-plan-preview.md`
(human-readable).

**Scope (Rule 16):** generated code lives only under `features/presentation/`.
`domain/` and `data/` layers are **out of scope** — reference UseCases/Repositories by
import, never generate them.

---

## Stages at a glance

| Stage | Goal | Reads | Produces | Gate |
|---|---|---|---|---|
| **0 · Preconditions** | Confirm the scaffolding the rules assume exists. No code. | project tree | gate report | auto |
| **1 · Design Intake** | Extract screens, components, states, fields, actions, icons, permission triggers | Figma URL / design spec | `ui-spec.md` | auto |
| **2 · Plan** | Per-screen file map, UiState shape, component inventory, icon table, permission plan, string keys | `ui-spec.md` + guidelines | `ui-plan.yaml` + `ui-plan-preview.md` | **HUMAN** |
| **3 · Asset & Component Prep** | Materialise everything screens depend on *before* writing screen Kotlin | `ui-plan.yaml` | components, drawables, strings, manifest | auto |
| **4 · Screen Generation** | Generate each screen's files in one shot | `ui-plan.yaml` | `Screen/ViewModel/UiState/Event/FieldState/enums` | auto |
| **5 · Validation** | Self-check against rules + compile | generated code | pass/fail report | auto |

The only human checkpoint is the **gate after Stage 2** — everything before it is cheap
and reversible; everything after it is generated against a frozen, reviewed plan.

---

## Stage 0 — Preconditions

**Goal:** confirm the scaffolding the rules assume actually exists, before reading any
design. Produces a gate report only — **no code is generated**.

| Check | Rule |
|---|---|
| `AppTheme` exists with **both** `lightColorScheme` and `darkColorScheme` | R4.1 |
| `MaterialTheme` typography + shapes tokens defined | R3.2, R3.4 |
| `features.presentation.component` package present | R13.1 |
| Spacing scale (multiples of 4.dp) available or to-be-created | R3.5 |
| `strings.xml` writable, Compose BOM present, **Material 3 only** | R1.1, R9.1 |

Verdict: **GREEN** (proceed) or **RED** (list blockers).

---

## Stage 1 — Design Intake

**Goal:** read the design and extract a structured `ui-spec.md`. If given a Figma URL,
use the Figma MCP (`get_metadata`, `get_design_context`, `get_screenshot`,
`get_variable_defs`).

Extract, per screen:

| Extracted | Maps to | Rule |
|---|---|---|
| Screen name | `snake_case` folder | R16.3 |
| Data shown on screen | `UiState` fields | R2.4 |
| Input fields / forms | `FieldState` fields | R12.5 |
| Taps / user actions | `Event` subtypes | R11.3 |
| Components used | `features.presentation.component` mapping | R13 |
| Icons referenced | icon-resolution candidates | R14.1 |
| Images (static vs remote URL) | drawable vs Coil | R14.5 |
| Image / file picker present | **permission-flow trigger** | R15.1 |

---

## Stage 2 — Plan (human gate)

**Goal:** produce `ui-plan.yaml` + `ui-plan-preview.md`, then **stop** for review.
No code generated.

**Per-screen file map** (Rule 16.4 / Rule 12.2 — one class per file, always):

```
features/presentation/screen/{feature}/
  {Feature}Screen.kt        ← Screen (stateful) + ScreenContent (stateless)   R7.1
  {Feature}ViewModel.kt     ← ViewModel class ONLY                            R12.0
  {Feature}UiState.kt       ← UiState data class + Dialog sealed class        R12.4
  {Feature}Event.kt         ← Event sealed class                              R12.6
  {Feature}FieldState.kt    ← only if the screen has a form                   R12.5
  {Feature}{Enum}.kt        ← one file per enum
```

**Component inventory** (Rule 13) — classify each component:

| Class | Action |
|---|---|
| `exists` | import & use it from `features.presentation.component` |
| `create_new` | build a new stateless component in `features.presentation.component` with light+dark `@Preview` (R13.2 / R13.4) |

**Icon table** (Rule 14.1) — resolve each icon to a priority:

1. **VectorDrawable from design** (SVG → XML) — *preferred*
2. **Material Icons** — utility-only fallback (back, close, search…)
3. **app custom icon set** — existing drawable in `app/src/main/res/drawable/`
4. **Coil `AsyncImage`** — dynamic API URL

**Decisions to resolve at the gate:**

| Key | Question | Rule |
|---|---|---|
| `component_resolution` | For each component: **exists** in `features.presentation.component`, or **create new**? | R13 |
| `shared_composable_placement` | Screen-local vs feature `presentation/component/` vs `features.presentation.component`? | R16.6 |
| `icon_source` | Confirm resolved priority for each ambiguous icon (esp. P1 vs P2) | R14.1 |
| `state_shape` | **sealed** `UiState` vs single **data-class** `UiState` per screen | R2.4 |

---

## Stage 3 — Asset & Component Prep

**Goal:** materialise everything the screens depend on, so Stage 4 writes screen Kotlin
against already-present components, icons, strings and permissions.

- **Create** each `create_new` component in `features.presentation.component` — stateless, `modifier` last, light+dark `@Preview`, KDoc (R13.2 / R13.4).
- **Icons (priority 1):** export SVG from Figma → convert to VectorDrawable →
  `app/src/main/res/drawable/ic_<feature>_<desc>.xml` (R14.2, naming R14.6).
- **Permissions:** add `CAMERA`, `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`,
  `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`), `FileProvider`, and `res/xml/file_paths.xml` (R15.3).
- **Strings:** add all planned keys to `strings.xml` (R9, naming R9.2).

---

## Stage 4 — Screen Generation

**Goal:** generate one screen at a time. Every file carries a file-path comment + the
correct package (singular `screen/`, R16.5), and **all files for a screen ship in one
response** (R16.9).

Each screen obeys:

- **Composable rules** — stateless `Content`, state hoisted, `modifier` last & defaulted, M3 + theme tokens, light+dark `@Preview`, `Surface` (R2, R3, R5).
- **ViewModel rules** — `@HiltViewModel`, single `onEvent()` entry, `update{}`, `Resource` `when` (R11; class ONLY, R12.0).
- **File-structure rules** — one class per file; `UiState`/`Event`/`FieldState` separated (R12.2).
- **Package-structure rules** — under `presentation/screen/{feature}/`, `snake_case`, flat (R16).
- **Component rules** — `features.presentation.component` components used; no raw M3 in a screen; icon priority order respected (R13.1, R14.1).
- **A11y rules** — `contentDescription`, semantic roles, 48dp targets (R6).
- **No business logic in composables**; no hardcoded strings (R8.4, R9).

---

## Stage 5 — Validation

**Goal:** self-check generated code against the rules, then build.

Report ✅/❌ per item with `file:line`:

- One class per file; `UiState`/`Event`/`FieldState` in separate files (R12.2, R12.7)
- ViewModel: `onEvent()`-only, no extra public mutators (R11.3)
- Package matches folder, singular `screen/`/`component/` (R16.5)
- No raw M3 where a `features.presentation.component` equivalent exists (R13.1)
- Stateless `Content`, state hoisted, `modifier` last & defaulted (R2)
- Light+dark `@Preview` (R5); a11y present (R6); no hardcoded strings (R9)
- No `domain/`/`data/`/`repository/`/`usecase/` files generated (R16.7)

Then run the project build and report the result.

---

## How to run — copy-paste prompts

### Stage 0 — Preconditions
```
Read @codegen/compose-ui-agent-guidelines.md. Run STAGE 0 (Preconditions) only —
produce a gate report, generate NO code.

Verify each and report ✅/❌ with the file path that proves it:
- AppTheme defines BOTH lightColorScheme and darkColorScheme (R4.1)
- MaterialTheme typography + shapes tokens defined (R3.2, R3.4)
- Spacing scale (4.dp multiples) available or to-be-created (R3.5)
- features.presentation.component package present (R13.1)
- strings.xml writable, Compose BOM present, Material 3 only (R1.1, R9.1)

End with a single verdict: GREEN (proceed to Stage 1) or RED (list blockers).
```

### Stage 1 — Design Intake
```
Read @codegen/compose-ui-agent-guidelines.md. Run STAGE 1 (Design Intake) only.
Design source: <FIGMA_URL or paste design spec>.
(If a Figma URL: use the Figma MCP — get_metadata, get_design_context,
get_screenshot, get_variable_defs.)

For EACH screen, extract into codegen/ui-spec.md:
- screen name → snake_case folder (R16.3)
- data shown → UiState field candidates (R2.4)
- input fields / forms → FieldState candidates (R12.5); has_form true/false
- taps / actions → Event candidates (R11.3)
- components used → name each (button, text field, dialog, picker, app bar…) (R13)
- icons / images → candidate + likely priority 1–4 (R14.1)
- image/file picker present? → permission-flow trigger (R15.1)

Output codegen/ui-spec.md only. Do NOT plan files or generate code yet.
```

### Stage 2 — Plan (stops at the gate)
```
Read @codegen/compose-ui-agent-guidelines.md and codegen/ui-spec.md. Run STAGE 2 (Plan).

Produce TWO artifacts, then STOP for my review — generate no screen code:
1. codegen/ui-plan.yaml (mirror the style of codegen/ui-plan.template.yaml):
   - per screen: folder + package (R16.5, singular `screen/`), file map (R16.4),
     state_shape data_class|sealed (R2.4), has_form, enums (one file each, R12.2)
   - components[]: each {name, subpackage, status: exists|create_new} (R13)
   - icons[]: each {name, priority: 1_vector_from_design|2_material_icon|
     3_app_existing|4_coil_remote, file} (R14.1)
   - permissions plan if any picker present (R15)
   - string keys <screen>_<component>_<desc> (R9.2)
   - shared composable placement: screen-local | presentation/component |
     features.presentation.component (R16.6)
2. codegen/ui-plan-preview.md (human-readable: folder tree + decisions summary).

Mark every open choice as `decision: pending`. List all pending decisions at the
end and ask me to resolve them. Do NOT proceed to Stage 3.
```

### Stage 3 — Asset & Component Prep
```
Read @codegen/compose-ui-agent-guidelines.md and codegen/ui-plan.yaml (all decisions
resolved). Run STAGE 3 (Asset & Component Prep). Do NOT write screen files yet.

- For each component status=create_new: create it under
  features.presentation.component.<subpackage> — stateless, modifier last,
  UiStyle-driven, KDoc, light+dark @Preview (R13.2, R13.4, R5).
- Icons priority 1: convert SVG→VectorDrawable into app/src/main/res/drawable/
  named ic_<feature>_<desc>.xml (R14.2, R14.6).
- If any picker: add CAMERA/READ_MEDIA_* perms, FileProvider, res/xml/file_paths.xml (R15.3).
- Add all planned string keys to strings.xml (R9).

Report what you created/modified. Stop before screen generation.
```

### Stage 4 — Screen Generation (run per screen)
```
Read @codegen/compose-ui-agent-guidelines.md and codegen/ui-plan.yaml. Run STAGE 4
for screen: <SCREEN_NAME> only.

Generate ALL files for this screen in one response (R16.9), each with a file-path
comment + correct package (singular screen/, R16.5):
- <Feature>Screen.kt — Screen (stateful) + ScreenContent (stateless), split (R7.1, R2)
- <Feature>ViewModel.kt — @HiltViewModel, single onEvent() entry, update{}, Resource
  when (R11; class ONLY, R12.0)
- <Feature>UiState.kt — UiState + Dialog sealed class (R12.4)
- <Feature>Event.kt — Event sealed class (R12.6)
- <Feature>FieldState.kt — only if has_form (R12.5)
- one file per enum (R12.2)

Use components from features.presentation.component (no raw M3 in the screen, R13.1),
M3 + theme tokens (R3), dark-mode safe (R4), previews light+dark (R5), a11y
contentDescription/roles/48dp targets (R6), no hardcoded strings (R9), no business
logic in composables (R8.4).
```

### Stage 5 — Validation
```
Read @codegen/compose-ui-agent-guidelines.md. Run STAGE 5 (Validation) on the files
generated for <SCREEN_NAME> (or all generated screens).

Check and report ✅/❌ per item with file:line:
- One class per file; UiState/Event/FieldState in separate files (R12.2, R12.7)
- ViewModel: onEvent()-only, no extra public mutators (R11.3)
- Package matches folder, singular screen/component (R16.5)
- No raw M3 where a features.presentation.component equivalent exists (R13.1)
- Stateless Content, state hoisted, modifier param last+defaulted (R2)
- Light+dark @Preview present (R5); a11y present (R6); no hardcoded strings (R9)
- No domain/data/repository/usecase files generated (R16.7)

Then run the project build and report the result. List any fix needed; don't auto-fix
unless I say so.
```

---

## Tips

- **Golden screen first.** After the Stage 2 gate, run Stage 4 on one representative
  screen (form + picker), review, lock conventions, then batch the rest.
- **`ui-plan.yaml` is the single source of truth and the resume point** — every stage
  reads it, so any stage is re-runnable in isolation.
- **Keep Stage 3 strictly before Stage 4** — screens must compile against already-present
  components/strings/icons.
- **One screen per Stage-4 prompt** — tighter context, higher fidelity, easier review.
