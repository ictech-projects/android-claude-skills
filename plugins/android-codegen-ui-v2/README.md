# android-codegen-ui-v2

Generate **Jetpack Compose UI** for a Clean Architecture Android app from a **Figma** design:
screens (stateful `Screen` + stateless `ScreenContent`), `ViewModel` / `UiState` / `Event` /
`FieldState` files, reusable components, icons/drawables, string resources, and runtime-permission
wiring — obeying the same 16-rule Compose guideline set as
[`android-codegen-ui`](../android-codegen-ui/README.md).

**This is the token-optimized rewrite.** Identical output contract, but the ruleset is split from
its code examples and each stage reads only the slice it needs — cutting repeated rule tokens by
roughly **90% per screen** on gated / multi-stage runs.

Runs as a **five-stage pipeline (0, 2, 3, 4, 5) with a mandatory developer review gate** after
planning. It generates **only `features/presentation/`** — never `domain/` or `data/` (that's
[`android-codegen-non-ui`](../android-codegen-non-ui/README.md)).

> **Requires the Figma MCP server** (Stage 2 reads the design through it). Assumes Material 3,
> an `AppTheme` with light+dark schemes, and a `features.presentation.component` package.

## Why v2 is cheaper

| Optimization | Effect |
|---|---|
| **Rules split from code** — `rules-compact.md` (normative, no code) + `examples/*.md` (patterns) | 55% of v1's file was code examples; they now load only when a stage emits that artifact |
| **Per-stage slicing** — each prompt reads compact rules + only the examples it needs | A pickerless screen never loads the ~4k-token camera/gallery example |
| **Stage 1 merged into Stage 2** — `ui-plan.yaml` emitted directly from the Figma read | One fewer full pass over the design; no throwaway `ui-spec.md` |
| **Self-sufficient plan** — `rule_ids` + `examples[]` baked into each screen | Stages 3–5 run from `plan + rules-compact` alone — no Figma re-read, no full ruleset |
| **Conditional screenshot** | `get_screenshot` only for layout-ambiguous frames |
| **Per-screen subagent generation** | Ruleset never accumulates in the orchestrator; cost stays flat as screen count grows |

For a minimal splash screen (1 text, 1 icon, 1 loader), rule/doc tokens drop from ~124k (v1,
re-read-per-stage) to ~8k — because the full ruleset is never injected and the camera/gallery
example is never loaded.

## Install

```text
/plugin marketplace add ictech-projects/android-claude-skills
/plugin install android-codegen-ui-v2@android-skills
```

## Use

**1. Plan** (Stages 0–2) — checks preconditions, reads the Figma design, writes a plan, then **stops**:

```text
/android-codegen-ui-v2:android-codegen-ui-v2 plan
```
Give it the **Figma file URL + frames** to generate. Produces `codegen/ui-plan.yaml` +
`codegen/ui-plan-preview.md` (each screen entry carries `rule_ids` + `examples[]`).

**2. Review & edit** `codegen/ui-plan.yaml` — resolve every `decision`
(`component_resolution`, `shared_composable_placement`, `icon_source`, `state_shape`) and set
`preconditions_passed: true`. The gate blocks generation while any decision is unset.

**3. Generate** (Stages 3–4) — materialises components/icons/strings/permissions, then writes each
screen's Kotlin in one shot (one screen per response; ideally one subagent per screen):

```text
/android-codegen-ui-v2:android-codegen-ui-v2 generate
```

**4. Validate** (Stage 5) — self-checks against the rules and builds:

```text
/android-codegen-ui-v2:android-codegen-ui-v2 validate
```

Finer-grained entry point: `preconditions` (Stage 0 only).

## What's inside

| Part | Purpose |
|---|---|
| `SKILL.md` | Thin entry point: stages, the Plan gate, Figma intake, scope guard |
| `reference/rules-compact.md` | The 16-rule ruleset as terse normative lines — **no code** (the always-loaded spine) |
| `reference/examples/*.md` | Code patterns, loaded on demand: `composable`, `viewmodel`, `icons`, `permissions`, `package` |
| `reference/ui-codegen-pipeline.md` | The staged pipeline + copy-paste run-prompts (already sliced) |
| `templates/ui-plan.template.yaml` · `ui-plan-preview.template.md` | Stage-2 output shapes with the `rule_ids`/`examples` self-sufficiency fields |

## Notes

- Same 16-rule contract and output as `android-codegen-ui` — prefer v2 for multi-screen runs and
  gated workflows where stages re-read context.
- The only human checkpoint is the gate after Stage 2 — everything before it is cheap and
  reversible; everything after generates against a frozen, reviewed plan.
- Chains with the others: **android-codegen-non-ui** builds the data layer the UI imports →
  **android-unit-testing** tests the ViewModels → **android-compose-review** reviews the diff.
