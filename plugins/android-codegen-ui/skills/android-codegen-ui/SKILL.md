---
name: android-codegen-ui
description: Use when generating Jetpack Compose UI from a design (Figma) for a Clean Architecture Android app — screens with stateful/stateless split, ViewModel/UiState/Event/FieldState files, reusable components, icons/drawables, string resources, and runtime-permission wiring. Six-stage pipeline with a mandatory developer review gate after planning. Generates ONLY features/presentation — never domain/data. Requires the Figma MCP server. Triggers on "generate the screen/UI from this Figma", "build the Compose UI from the design", "run UI codegen".
argument-hint: "[stage: preconditions | intake | plan | generate | validate]   default: plan"
---

# Android Compose UI codegen (Figma → screens)

Deterministic, template-driven generator for the **UI layer**. It turns a Figma design into
Jetpack Compose screens that obey every rule in
[`reference/compose-ui-agent-guidelines.md`](reference/compose-ui-agent-guidelines.md) (16 rules:
stateless composables, M3 + theme tokens, dark mode, previews, a11y, screen/content split,
ViewModel structure, `UiState` in its own file, reusable components, asset management, runtime
permissions, package-structure scope).

This is a **low-freedom, follow-the-rules** task. Authoritative sources, bundled here:

- [`reference/ui-codegen-pipeline.md`](reference/ui-codegen-pipeline.md) — the staged pipeline (human-readable).
- [`reference/ui-codegen-pipeline.yaml`](reference/ui-codegen-pipeline.yaml) — machine-readable stage defs.
- [`reference/compose-ui-agent-guidelines.md`](reference/compose-ui-agent-guidelines.md) — the ruleset (R1–R16).
- [`templates/ui-plan.template.yaml`](templates/ui-plan.template.yaml) · [`templates/ui-plan-preview.template.md`](templates/ui-plan-preview.template.md) — Stage-2 output shapes.

## Preconditions

- **Figma MCP server connected.** Stage 1 reads the design via Figma MCP tools
  (`get_metadata`, `get_design_context`, `get_screenshot`, `get_variable_defs`,
  `get_code_connect_map`). Exact tool names depend on how Figma MCP is installed
  (e.g. `mcp__…figma…__get_metadata`). If it isn't available, stop and say so — do not
  guess the design.
- **Input:** a Figma file URL + the frames/screens to generate.
- **Assumes** Material 3, an `AppTheme` with light+dark schemes, and a
  `features.presentation.component` package (see Stage 0).

## Scope guard — Rule 16 (do not violate)

Generated code lives **only** under `features/presentation/`. `domain/` and `data/` layers are
**out of scope** — reference UseCases/Repositories by import, never generate them. Never write
`**/repository`, `**/usecase`, `features/domain`, or `features/data`. (That's the
`android-codegen-non-ui` plugin's job.) Stage 5 explicitly checks this.

## The pipeline — and the gate that must not be skipped

Stages **0 → 1 → 2 → ⟨HUMAN GATE⟩ → 3 → 4 → 5**. Only Stage 2's output is human-reviewed;
everything after generates against the **frozen, reviewed** `ui-plan.yaml`.

| Stage | Goal | Produces | Gate |
|---|---|---|---|
| **0 · Preconditions** | Confirm `AppTheme` (light+dark), M3 typography/shapes, `presentation.component`, spacing scale, `strings.xml` writable. No code. | GREEN/RED report | auto |
| **1 · Design Intake** | Read Figma → extract per-screen data, fields, actions, components, icons, images, permission triggers. | `ui-spec.md` | auto |
| **2 · Plan** | Per-screen file map, `UiState` shape, component inventory (`exists`/`create_new`), icon table, permission plan, string keys. **No code.** | `codegen/ui-plan.yaml` + `codegen/ui-plan-preview.md` | **HUMAN** |
| **3 · Asset & Component Prep** | Materialise dependencies first: create `create_new` components (light+dark `@Preview`), export icons → VectorDrawable, add permissions + `FileProvider`, add string keys. | components, drawables, strings, manifest | auto |
| **4 · Screen Generation** | Generate each screen's files in one response: `Screen` (stateful) + `ScreenContent` (stateless), `ViewModel`, `UiState`, `Event`, `FieldState`, enums — one class per file. | screen Kotlin | auto |
| **5 · Validation** | Self-check ✅/❌ per rule with `file:line`, then build. | pass/fail report | auto |

### The gate (after Stage 2)
After writing the two plan files, **STOP**. The developer reviews `ui-plan-preview.md`, edits
`ui-plan.yaml` to resolve every `decision` (component_resolution, shared_composable_placement,
icon_source, state_shape) and sets `preconditions_passed: true`. Do **not** start Stage 3 until
all decisions are resolved — list any unresolved ones and wait.

## Argument

- `preconditions` — run Stage 0 only.
- `intake` — Stages 0–1 (produce `ui-spec.md`).
- `plan` (default) — Stages 0–2, then stop at the human gate.
- `generate` — Stages 3–4 from the reviewed `codegen/ui-plan.yaml`.
- `validate` — Stage 5 self-check + build.

## Rule map (reference/compose-ui-agent-guidelines.md)

| Concern | Rule |
|---|---|
| Compose + official guidelines, M3 only | R1, R3 |
| Stateless composable architecture, `modifier` last/defaulted | R2 |
| Dark mode (light+dark schemes) | R4 |
| `@Preview` (light + dark) | R5 |
| Accessibility (TalkBack, roles, 48dp) | R6 |
| Screen vs Content composable separation | R7 |
| Code quality | R8 |
| Strings localization | R9 |
| ViewModel structure (`@HiltViewModel`, single `onEvent()`, `update{}`) | R11 |
| `UiState` in a separate file (strict) | R12 |
| In-app reusable components | R13 |
| Icon & image asset management | R14 |
| Runtime permissions (camera/gallery) | R15 |
| Package-structure scope (UI only) | R16 |

> Path note: the bundled docs refer to `codegen/compose-ui-agent-guidelines.md` etc. In this
> skill those live under `reference/`; the developer's plan artifacts are written to the
> project's `codegen/ui-plan.yaml` + `codegen/ui-plan-preview.md`.

## Relationship to the other plugins

Pairs with **`android-codegen-non-ui`** (it generates the `domain/`+`data/` layers this UI
imports). After generation, use **`android-unit-testing`** to test the ViewModels and
**`android-compose-review`** to review the diff.