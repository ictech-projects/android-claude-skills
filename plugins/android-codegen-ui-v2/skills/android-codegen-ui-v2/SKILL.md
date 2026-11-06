---
name: android-codegen-ui-v2
description: Use when generating Jetpack Compose UI from a Figma design for a Clean Architecture Android app — screens with stateful/stateless split, ViewModel/UiState/Event/FieldState files, reusable components, icons/drawables, string resources, and runtime-permission wiring. Token-optimized rewrite of android-codegen-ui — same 16-rule contract, but rules are split from code examples and each stage reads only its slice, cutting repeated rule tokens ~90% per screen. Five-stage pipeline (0,2,3,4,5) with a mandatory developer review gate after planning. Generates ONLY features/presentation — never domain/data. Requires the Figma MCP server. Triggers on "generate the screen/UI from this Figma", "build the Compose UI from the design", "run UI codegen v2".
argument-hint: "[stage: preconditions | plan | generate | validate]   default: plan"
---

# Android Compose UI codegen v2 (Figma → screens, token-optimized)

Deterministic, template-driven generator for the **UI layer** — same rules and output as
`android-codegen-ui`, re-engineered so **no stage ever reads the full 2 000-line ruleset**.

## What changed vs v1 (and why it's cheaper)

1. **Rules split from code.** [`reference/rules-compact.md`](reference/rules-compact.md) holds all 16
   rules as terse normative lines (**no fenced code**). The code patterns — 55% of v1's file bulk —
   live in [`reference/examples/*.md`](reference/examples/) and load **only when a stage emits that
   artifact**. A pickerless screen never loads the ~4k-token camera/gallery example.
2. **Per-stage slicing.** Each run-prompt reads `rules-compact` + only the example files it needs.
3. **Stage 1 merged into Stage 2.** `ui-plan.yaml` is emitted **directly** from the Figma read — no
   throwaway `ui-spec.md`, one fewer full pass over the design.
4. **Self-sufficient plan.** Stage 2 bakes `rule_ids` + `examples[]` into each screen entry, so
   Stages 3–5 run from `plan + rules-compact` alone — never Figma again, never the full ruleset.
5. **Conditional screenshot.** `get_screenshot` is called only for layout-ambiguous frames.
6. **Per-screen subagent generation.** Stage 4 ideally runs one screen per isolated subagent, so the
   ruleset never accumulates in the orchestrator and cost stays flat as screen count grows.

Authoritative sources, bundled here:

- [`reference/rules-compact.md`](reference/rules-compact.md) — the ruleset spine (R1–R16, no code).
- [`reference/examples/`](reference/examples/) — code patterns: `composable.md`, `viewmodel.md`, `icons.md`, `permissions.md`, `package.md`.
- [`reference/ui-codegen-pipeline.md`](reference/ui-codegen-pipeline.md) — staged pipeline + copy-paste run-prompts.
- [`templates/ui-plan.template.yaml`](templates/ui-plan.template.yaml) · [`templates/ui-plan-preview.template.md`](templates/ui-plan-preview.template.md) — Stage-2 output shapes.

## Preconditions

- **Figma MCP server connected.** Stage 2 reads the design via Figma MCP tools (`get_metadata`,
  `get_design_context`, `get_variable_defs`, and `get_screenshot` only when a frame is
  layout-ambiguous). Exact tool names depend on install (e.g. `mcp__…figma…__get_metadata`). If it
  isn't available, stop and say so — do not guess the design.
- **Input:** a Figma file URL + the frames/screens to generate.
- **Assumes** Material 3, an `AppTheme` with light+dark schemes, and a
  `features.presentation.component` package (see Stage 0).

## Scope guard — R16.0 (do not violate)

Generated code lives **only** under `features/presentation/`. `domain/` and `data/` are **out of
scope** — reference UseCases/Repositories by import, never generate them. Never write
`**/repository`, `**/usecase`, `features/domain`, or `features/data`. (That's the
`android-codegen-non-ui` plugin's job.) Stage 5 explicitly checks this.

## The pipeline — and the gate that must not be skipped

Stages **0 → 2 → ⟨HUMAN GATE⟩ → 3 → 4 → 5**. Only Stage 2's output is human-reviewed; everything
after generates against the **frozen, reviewed** `ui-plan.yaml`.

| Stage | Goal | Reads | Produces | Gate |
|---|---|---|---|---|
| **0 · Preconditions** | Confirm `AppTheme` (light+dark), M3 typography/shapes, `presentation.component`, spacing scale, `strings.xml`. No code. | `rules-compact` §R1/3/4/9/13 | GREEN/RED report | auto |
| **2 · Plan** | Read Figma → per-screen file map, `UiState` shape, component inventory, icon table, permission plan, string keys, `rule_ids`+`examples`. **No code.** | `rules-compact` + Figma | `codegen/ui-plan.yaml` + `codegen/ui-plan-preview.md` | **HUMAN** |
| **3 · Asset & Component Prep** | Materialise `create_new` components (light+dark `@Preview`), export icons → VectorDrawable, add permissions + `FileProvider`, add string keys. | `plan` + `rules-compact` (+ needed examples) | components, drawables, strings, manifest | auto |
| **4 · Screen Generation** | Generate each screen's files in one response: `Screen`+`ScreenContent`, `ViewModel`, `UiState`, `Event`, `FieldState`, enums — one class per file. | `plan` slice + `rules-compact` + screen's `examples[]` | screen Kotlin | auto |
| **5 · Validation** | Self-check ✅/❌ per rule with `file:line`, then build. | `rules-compact` checklist | pass/fail report | auto |

### The gate (after Stage 2)
After writing the two plan files, **STOP**. The developer reviews `ui-plan-preview.md`, edits
`ui-plan.yaml` to resolve every `decision` (component_resolution, shared_composable_placement,
icon_source, state_shape) and sets `preconditions_passed: true`. Do **not** start Stage 3 until all
decisions are resolved — list any unresolved ones and wait.

## Argument

- `preconditions` — run Stage 0 only.
- `plan` (default) — Stages 0–2, then stop at the human gate.
- `generate` — Stages 3–4 from the reviewed `codegen/ui-plan.yaml`.
- `validate` — Stage 5 self-check + build.

Copy-paste prompts for each stage live in
[`reference/ui-codegen-pipeline.md`](reference/ui-codegen-pipeline.md) — they already read the
compact rules + the right example slices. **Never read a full monolithic guideline file; there
isn't one in v2.**

## Rule map (reference/rules-compact.md)

| Concern | Rule | Example file |
|---|---|---|
| Compose + official guidelines, M3 only | R1, R3 | composable |
| Stateless composable, `modifier` last/defaulted | R2 | composable |
| Dark mode (light+dark schemes) | R4 | composable |
| `@Preview` (light + dark) | R5 | composable |
| Accessibility (TalkBack, roles, 48dp) | R6 | composable |
| Screen vs Content separation | R7 | composable |
| Code quality | R8 | composable |
| Strings localization | R9 | — |
| ViewModel structure (`@HiltViewModel`, single `onEvent()`, `update{}`) | R11 | viewmodel |
| `UiState` in its own file (strict) | R12 | viewmodel |
| In-app reusable components | R13 | composable |
| Icon & image asset management | R14 | icons |
| Runtime permissions (camera/gallery) | R15 | permissions |
| Package-structure scope (UI only) | R16 | package |

> Path note: the developer's plan artifacts are written to the project's `codegen/ui-plan.yaml` +
> `codegen/ui-plan-preview.md`; the ruleset/examples/templates ship under this skill's `reference/`
> and `templates/`.

## Relationship to the other plugins

Pairs with **`android-codegen-non-ui`** (it generates the `domain/`+`data/` layers this UI imports).
After generation, use **`android-unit-testing`** to test the ViewModels and
**`android-compose-review`** to review the diff.

`android-codegen-ui` (v1) remains available and produces identical output — v2 is the same contract
optimized for token cost. Prefer v2 for multi-screen runs and gated workflows where stages re-read
context.
