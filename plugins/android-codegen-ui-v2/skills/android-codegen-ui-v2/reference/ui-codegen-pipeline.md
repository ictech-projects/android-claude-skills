# Compose UI Codegen Pipeline — v2 (token-optimized)

> **Rules:** [`rules-compact.md`](./rules-compact.md) (no code) · **Examples:** [`examples/*.md`](./examples/) (load per stage) ·
> **Plan stubs:** [`../templates/ui-plan.template.yaml`](../templates/ui-plan.template.yaml) · [`../templates/ui-plan-preview.template.md`](../templates/ui-plan-preview.template.md)

Same 16-rule contract as `android-codegen-ui`, restructured so **no stage ever reads the full
2 000-line ruleset**. Two mechanisms do the work:

1. **Rules split from code.** `rules-compact.md` is the always-loaded spine (terse, no fenced code).
   Code patterns live in `examples/*.md` and load only when a stage emits that artifact — e.g. the
   camera/gallery block (`examples/permissions.md`) loads only for screens with a picker.
2. **Self-sufficient plan.** Stage 2 bakes resolved decisions **+ the rule IDs and example files each
   screen touches** into `ui-plan.yaml`. Stages 3–5 read `plan + rules-compact` only — never Figma
   again, never the whole ruleset.

**Stages 0 → 2 → ⟨HUMAN GATE⟩ → 3 → 4 → 5.** (v1's Stage 1 "Design Intake" is merged into Stage 2 —
`ui-plan.yaml` is emitted directly from the Figma read; no throwaway `ui-spec.md`.)

**Scope (R16.0):** generated code lives only under `features/presentation/`. Never `domain/`/`data/`.

| Stage | Goal | Reads (tokens) | Produces | Gate |
|---|---|---|---|---|
| **0 · Preconditions** | Confirm scaffolding the rules assume. No code. | `rules-compact` §R1/3/4/9/13 slice | GREEN/RED report | auto |
| **2 · Plan** | Read Figma → per-screen file map, UiState shape, components, icons, permissions, strings. No code. | `rules-compact` + Figma | `ui-plan.yaml` + `ui-plan-preview.md` | **HUMAN** |
| **3 · Asset & Component Prep** | Materialise components/icons/strings/manifest the screens depend on. | `plan` + `rules-compact` (+ `examples/icons`, `examples/permissions` if planned) | components, drawables, strings, manifest | auto |
| **4 · Screen Generation** | Generate each screen's files (one screen per response, ideally a subagent). | `plan` slice for that screen + `rules-compact` + the screen's `examples[]` | screen Kotlin | auto |
| **5 · Validation** | Self-check ✅/❌ per rule + build. | `rules-compact` checklist | pass/fail report | auto |

The only human checkpoint is the gate after Stage 2.

---

## The gate (after Stage 2)
Write the two plan files, then **STOP**. The developer reviews `ui-plan-preview.md`, edits
`ui-plan.yaml` to resolve every `decision:` (component_resolution, shared_composable_placement,
icon_source, state_shape) and sets `preconditions_passed: true`. Do **not** start Stage 3 until all
decisions are resolved — list any unresolved ones and wait.

---

## How to run — copy-paste prompts

> Each prompt reads `reference/rules-compact.md` **plus only the example slices it needs**. Never
> `Read` the old full guideline file — it doesn't exist in v2.

### Stage 0 — Preconditions
```
Read @reference/rules-compact.md — sections R1, R3, R4, R9, R13 only. Run STAGE 0
(Preconditions). Generate NO code.

Verify each and report ✅/❌ with the file path that proves it:
- AppTheme defines BOTH lightColorScheme and darkColorScheme (R4.1)
- MaterialTheme typography + shapes tokens defined (R3.2, R3.4)
- Spacing scale (4.dp multiples) available or to-be-created (R3.5)
- features.presentation.component package present (R13.1)
- strings.xml writable, Compose BOM present, Material 3 only (R1.1, R9.1)

End with one verdict: GREEN (proceed to Stage 2) or RED (list blockers).
```

### Stage 2 — Plan  (reads Figma, emits the plan directly, stops at the gate)
```
Read @reference/rules-compact.md. Run STAGE 2 (Plan). Design source: <FIGMA_URL + frames>.
Generate NO screen code — produce the two plan artifacts and STOP.

Read the design cheaply first:
- get_metadata + get_design_context + get_variable_defs for the target frames.
- Call get_screenshot ONLY for frames whose layout is ambiguous from structure alone
  (overlap, custom composition). Skip it for simple/standard layouts. Note which frames
  you screenshotted and why.

Emit codegen/ui-plan.yaml (mirror templates/ui-plan.template.yaml) — per screen:
- folder + package (R16.5, singular screen/), file map (R16.4),
  state_shape data_class|sealed (R2.4), has_form, enums (one file each, R12.2)
- components[]: {name, subpackage, status: exists|create_new} (R13)
- icons[]: {name, priority: 1_vector_from_design|2_material_icon|3_app_existing|4_coil_remote, file} (R14.1)
- permissions plan ONLY if a picker is present (R15)
- string keys <screen>_<component>_<desc> (R9.2)
- shared_composable_placement (R16.6)
- SELF-SUFFICIENCY FIELDS (so later stages skip re-reading): for each screen add
    rule_ids: [ … the R-numbers this screen actually touches … ]
    examples:  [ … only the needed files: composable | viewmodel | icons | permissions | package … ]
  Include `permissions` in examples[] ONLY if the screen has a picker.

Also emit codegen/ui-plan-preview.md (folder tree + decisions summary).
Mark every open choice `decision: pending`, list all pending decisions, and ask me to
resolve them. Do NOT proceed to Stage 3.
```

### Stage 3 — Asset & Component Prep
```
Read @reference/rules-compact.md and codegen/ui-plan.yaml (all decisions resolved).
Also read ONLY the example files that the plan's create_new work needs:
- examples/composable.md if any component status=create_new
- examples/icons.md if any icon priority=1_vector_from_design
- examples/permissions.md if any screen has a permissions plan
Run STAGE 3. Do NOT write screen files.

- For each component status=create_new: create under features.presentation.component.<subpackage>
  — stateless, modifier last, UiStyle-driven, KDoc, light+dark @Preview (R13.2, R13.4, R5).
- Icons priority 1: SVG→VectorDrawable → app/src/main/res/drawable/ic_<feature>_<desc>.xml (R14.2, R14.6).
- If any picker: add CAMERA/READ_MEDIA_* perms, FileProvider, res/xml/file_provider_paths.xml (R15.3).
- Add all planned string keys to strings.xml (R9).

Report what you created/modified. Stop before screen generation.
```

### Stage 4 — Screen Generation  (one screen per response; prefer a subagent per screen)
```
Read @reference/rules-compact.md and the codegen/ui-plan.yaml entry for screen <SCREEN_NAME> ONLY.
Read ONLY the example files listed in that screen's `examples:` field (typically
composable + viewmodel; + icons/permissions/package only if listed).
Run STAGE 4 for <SCREEN_NAME> only.

Generate ALL files for this screen in one response (R16.9), each with a file-path comment +
correct package (singular screen/, R16.5):
- <Feature>Screen.kt — Screen (stateful) + ScreenContent (stateless), split (R7.1, R2)
- <Feature>ViewModel.kt — @HiltViewModel, single onEvent() entry, update{}, Resource when (R11; class ONLY, R12.0)
- <Feature>UiState.kt — UiState + Dialog sealed class (R12.4)
- <Feature>Event.kt — Event sealed class (R12.6)
- <Feature>FieldState.kt — only if has_form (R12.5)
- one file per enum (R12.2)

Components from features.presentation.component (no raw M3, R13.1), theme tokens (R3), dark-mode
safe (R4), light+dark @Preview (R5), a11y (R6), no hardcoded strings (R9), no business logic in
composables (R8.4).
```

### Stage 5 — Validation
```
Read @reference/rules-compact.md — the "Stage-5 validation checklist" section. Run STAGE 5 on
<SCREEN_NAME> (or all generated screens).

Report ✅/❌ per checklist item with file:line. Then run the project build and report the result.
List any fix needed; don't auto-fix unless I say so.
```

---

## Tips

- **Golden screen first.** After the gate, run Stage 4 on one representative screen, review, then
  batch the rest. Its output becomes the concrete example for the batch — you can drop generic
  example loads for later screens on the same feature.
- **Prefer a subagent per Stage-4 screen.** Each screen generates in an isolated context that reads
  only its plan slice + its `examples[]` and returns files — the full ruleset never accumulates in
  the orchestrator, so cost stays flat as screen count grows.
- **`ui-plan.yaml` is the single source of truth and resume point.** Its `rule_ids`/`examples` fields
  make every post-gate stage runnable from `plan + rules-compact` alone — no Figma re-read, no full
  ruleset.
- **Keep Stage 3 strictly before Stage 4** — screens must compile against present components/strings/icons.
- **Skip `examples/permissions.md` for pickerless screens** (splash, list, detail, dashboard) — it's
  the single largest example file.
