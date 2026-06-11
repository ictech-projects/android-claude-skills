# android-codegen-ui

Generate **Jetpack Compose UI** for a Clean Architecture Android app from a **Figma** design:
screens (stateful `Screen` + stateless `ScreenContent`), `ViewModel` / `UiState` / `Event` /
`FieldState` files, reusable components, icons/drawables, string resources, and runtime-permission
wiring — all obeying a 16-rule Compose guideline set.

Runs as a **six-stage pipeline (0–5) with a mandatory developer review gate** after planning.
It generates **only `features/presentation/`** — never `domain/` or `data/` (that's
[`android-codegen-non-ui`](../android-codegen-non-ui/README.md)).

> **Requires the Figma MCP server** (Stage 1 reads the design through it). Assumes Material 3,
> an `AppTheme` with light+dark schemes, and a `features.presentation.component` package.

## Install

```text
/plugin marketplace add ictech-projects/android-claude-skills
/plugin install android-codegen-ui@android-skills
```

## Use

**1. Plan** (Stages 0–2) — checks preconditions, reads the Figma design, writes a plan, then **stops**:

```text
/android-codegen-ui:android-codegen-ui plan
```
Give it the **Figma file URL + frames** to generate. Produces `codegen/ui-plan.yaml` +
`codegen/ui-plan-preview.md`.

**2. Review & edit** `codegen/ui-plan.yaml` — resolve every `decision`
(`component_resolution`, `shared_composable_placement`, `icon_source`, `state_shape`) and set
`preconditions_passed: true`. The gate blocks generation while any decision is unset.

**3. Generate** (Stages 3–4) — materialises components/icons/strings/permissions, then writes
each screen's Kotlin in one shot:

```text
/android-codegen-ui:android-codegen-ui generate
```

**4. Validate** (Stage 5) — self-checks against the rules and builds:

```text
/android-codegen-ui:android-codegen-ui validate
```

Finer-grained entry points: `preconditions` (Stage 0 only) and `intake` (Stages 0–1 → `ui-spec.md`).

## What's inside

| Part | Purpose |
|---|---|
| `SKILL.md` | Thin entry point: stages 0–5, the Plan gate, Figma intake, Rule-16 scope guard |
| `reference/ui-codegen-pipeline.md` · `.yaml` | The staged pipeline (human + machine-readable) |
| `reference/compose-ui-agent-guidelines.md` | The full 16-rule Compose UI ruleset |
| `templates/ui-plan.template.yaml` · `ui-plan-preview.template.md` | Stage-2 output shapes |

## Notes

- The only human checkpoint is the gate after Stage 2 — everything before it is cheap and
  reversible; everything after generates against a frozen, reviewed plan.
- Chains with the others: **android-codegen-non-ui** builds the data layer the UI imports →
  **android-unit-testing** tests the ViewModels → **android-compose-review** reviews the diff.