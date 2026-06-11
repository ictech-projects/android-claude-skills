---
name: android-compose-code-review
description: Use when reviewing a diff, branch, or PR in this Jetpack Compose Android app (Clean Architecture + MVVM + Hilt). Reviews changed Kotlin/Compose code for correctness bugs and idiom violations, then routes each Compose/Kotlin concern to the vendored focused skills (compose-*, kotlin-*) rather than re-deriving them. Triggers on "review my changes", "review this PR", "code review", "check my branch before pushing".
---

# Android + Jetpack Compose code review

Orchestrator skill. It does **two jobs**:

1. Reviews the diff for correctness bugs (the part no focused skill covers).
2. **Routes** every Compose/Kotlin idiom question to the vendored focused skill that owns it — it does not re-explain stability, recomposition, side-effects, etc. Load the linked skill when its trigger fires.

Do not duplicate the focused skills' content here. When a concern matches the routing table, open that skill and apply it.

## Stack (assume unless the diff proves otherwise)

- **UI:** Jetpack Compose, Material 3.
- **Architecture:** Clean Architecture (data / domain / presentation) + MVVM, Hilt DI.
- **Async:** Coroutines + Flow; `StateFlow` for UI state, lifecycle-aware collection.
- **Generated layers** (API → Repository → UseCase) follow `codegen/android-codegen-rules.md` and `codegen/android-non-ui-rules.md`.
- **Tests** follow `unit_testing_rules/unit_testing_rules.md` (≥ 90% line coverage on Repository / UseCase / ViewModel).

## Process

1. **Scope.** Get the diff: `git diff master...HEAD` (branch review) or `gh pr diff <n>` (PR). List changed files; classify each as UI (`@Composable`), state-holder (`ViewModel` / state holder), domain (`UseCase`), data (`Repository` / API / DAO), or DI.
2. **Correctness pass** (this skill's own job — see checklist below). Read each changed file fully, not just the hunk.
3. **Compose best-practices pass.** For each changed file, match it against the routing table and apply the relevant focused skill(s). Multiple may apply to one file — apply in parallel. If a routed skill is missing, follow the **Missing-skill fallback** below — never silently skip the concern.
4. **Test & convention pass.** New Repository/UseCase/ViewModel logic without tests is a finding (`unit_testing_rules`). Generated layers that deviate from `codegen` rules are findings.
5. **Report.** Group findings by severity. Cite `file:line`. For each, name the skill or rule it came from.

## Severity labels

| Label | Meaning |
|---|---|
| 🔴 `blocking` | Bug, crash, data loss, security issue, or broken architecture boundary. Must fix before merge. |
| 🟠 `important` | Real defect risk or idiom violation that will bite later (e.g. unstable params on a hot composable). Fix strongly advised. |
| 🟡 `nit` | Minor style / readability; optional. |
| 🔵 `suggestion` | Refactor / simplification opportunity. |
| 🌟 `praise` | Something done well — call it out. |

## Routing table — Compose/Kotlin concerns → focused skill

| If the diff shows… | Apply |
|---|---|
| Recomposition cost, hot composables, `composables.txt` / compiler reports | [`compose-recomposition-performance`](../compose-recomposition-performance/SKILL.md) (router) |
| Unstable params, skippability, `@Stable`/`@Immutable`, collection params | [`compose-stability-diagnostics`](../compose-stability-diagnostics/SKILL.md) |
| Scroll/animation/gesture `State` read in composition, value-form layout/draw modifiers, cross-phase back-writes | [`compose-state-deferred-reads`](../compose-state-deferred-reads/SKILL.md) |
| `LaunchedEffect` / `DisposableEffect` / `rememberCoroutineScope` / `rememberUpdatedState` / `snapshotFlow` / snackbar / navigation effects | [`compose-side-effects`](../compose-side-effects/SKILL.md) |
| Bare `var` in a composable, `remember { mutableStateOf() }`, `mutableStateListOf`, `@ReadOnlyComposable` | [`compose-state-authoring`](../compose-state-authoring/SKILL.md) |
| Where state should live: local vs hoisted vs state holder vs ViewModel | [`compose-state-hoisting`](../compose-state-hoisting/SKILL.md) |
| Screen composable taking a ViewModel, collecting state/effects, wiring callbacks while also rendering | [`compose-state-holder-ui-split`](../compose-state-holder-ui-split/SKILL.md) |
| `Modifier` param, modifier chain order, hardcoded root layout, single-conditional wrappers | [`compose-modifier-and-layout-style`](../compose-modifier-and-layout-style/SKILL.md) |
| Reusable component with proliferating content params / boolean shape flags | [`compose-slot-api-pattern`](../compose-slot-api-pattern/SKILL.md) |
| `AnimatedVisibility`, `animate*AsState`, `Transition`, `AnimatedContent`, `Crossfade` | [`compose-animations`](../compose-animations/SKILL.md) |
| `@Preview`, screenshot tests, semantics assertions, UI test for a state-driven composable | [`compose-ui-testing-patterns`](../compose-ui-testing-patterns/SKILL.md) |
| Stored `CoroutineScope`, launch from `init`/non-suspend API, `runBlocking`, broad catch around suspend | [`kotlin-coroutines-structured-concurrency`](../kotlin-coroutines-structured-concurrency/SKILL.md) |
| `StateFlow` / `SharedFlow` / `Channel` / `stateIn` / `SharingStarted` / one-shot events / `.value` | [`kotlin-flow-state-event-modeling`](../kotlin-flow-state-event-modeling/SKILL.md) |

If evidence spans multiple rows, apply each matching skill.

## Missing-skill fallback

The routing table assumes the vendored `compose-*` / `kotlin-*` skills are present under `.claude/skills/`. They are committed to this repo (pinned — see `.claude/skills/ATTRIBUTION.md`), so normally all 13 resolve. But if a row's skill is **not present** (deleted, not vendored, or this skill was copied to another project), do **not** silently drop that concern. Instead:

1. **Detect.** Before applying a routed skill, confirm its `SKILL.md` exists at the linked path. Treat a broken link as missing.
2. **Fall back.** Run the one-line inline check for that concern from the table below — enough to catch the obvious cases, even without the deep skill.
3. **Warn — always.** Add a line to a `⚠️ Degraded coverage` section in the report naming the missing skill and the concern checked at reduced depth. A silent skip reads as "clean" and is the failure mode this section exists to prevent.

| Missing skill | Inline fallback check (reduced depth) |
|---|---|
| `compose-recomposition-performance` | Flag expensive work in a composable body not wrapped in `remember`; flag `@Composable` functions recomposing on every frame-rate state read. |
| `compose-stability-diagnostics` | Flag `List`/`Set`/`Map`/lambda-bearing data classes passed as composable params without `@Immutable`/`@Stable` or an immutable collection type. |
| `compose-state-deferred-reads` | Flag scroll/animation/gesture `State` read directly in composition; flag value-form `offset(x,y)` / `background()` where a lambda form would defer the read. |
| `compose-side-effects` | Flag `LaunchedEffect`/`DisposableEffect` with wrong or missing keys; flag side work in the composable body that belongs in an effect; flag missing cleanup. |
| `compose-state-authoring` | Flag bare `var` in a `@Composable`; flag `mutableStateOf` not wrapped in `remember`. |
| `compose-state-hoisting` | Flag state held too high and passed down, or business logic living in the composable instead of a holder/ViewModel. |
| `compose-state-holder-ui-split` | Flag a screen composable that both collects state/effects from a ViewModel and renders layout — should split into stateful + stateless. |
| `compose-modifier-and-layout-style` | Flag missing `Modifier` param on a reusable composable; flag suspicious modifier order (e.g. `clickable` before `clip`/`padding`). |
| `compose-slot-api-pattern` | Flag a reusable component accumulating primitive content params + boolean shape flags instead of a `content: @Composable () -> Unit` slot. |
| `compose-animations` | Flag manual frame/`Animatable` loops where `animate*AsState`/`AnimatedContent`/`Crossfade` fit; flag animations not driven off state. |
| `compose-ui-testing-patterns` | Flag new state-driven composables with no `@Preview` and no semantics-based test. |
| `kotlin-coroutines-structured-concurrency` | Flag stored `CoroutineScope`, `runBlocking` on a UI/main path, launches from `init`, and broad `catch` around suspend calls. |
| `kotlin-flow-state-event-modeling` | Flag one-shot events modeled as `StateFlow`; flag raw `.value` mutation where `update {}` is correct; flag missing `stateIn`/`SharingStarted`. |

### How to restore a missing skill

The skills are vendored (copied) from [`chrisbanes/skills`](https://github.com/chrisbanes/skills), pinned in `ATTRIBUTION.md`. To bring one back:

```bash
# 1. Clone the upstream at the pinned commit (see ATTRIBUTION.md for the current pin)
git clone https://github.com/chrisbanes/skills /tmp/cb-skills
cd /tmp/cb-skills && git checkout 0d0e411   # ← use the pin recorded in ATTRIBUTION.md

# 2. Re-read the skill's SKILL.md (vet it), then copy it into the project
cp -R /tmp/cb-skills/skills/<skill-name> \
      "<project>/.claude/skills/<skill-name>"

# 3. Commit it so it travels with every clone / CI checkout
```

To add a **brand-new** review concern (not from chrisbanes), create `.claude/skills/<name>/SKILL.md` with `name` + `description` frontmatter, then add a routing-table row above and a matching inline-fallback row here. Keep this skill a thin router — put the depth in the focused skill, not here.

## Correctness checklist (this skill owns — no focused skill covers it)

The focused skills handle *idiom*. This pass handles *will it work*:

- **Null / empty / error states.** Network responses, nullable API fields, empty lists, loading vs error vs empty UI all handled.
- **Coroutine cancellation & error propagation.** Failures surface to UI state; no swallowed exceptions; no work leaked past cancellation.
- **Lifecycle.** UI state collected with `collectAsStateWithLifecycle()` (not raw `collectAsState`) so collection stops in background.
- **Architecture boundaries.** No Android/framework types in domain; no business logic in composables; ViewModel exposes immutable state; data layer maps DTO → domain.
- **Data correctness (this branch's theme).** Type mismatches between API DTO, domain model, and UI — wrong numeric/date/enum types, lossy conversions, locale-sensitive parsing. (Branch `sprint-fix-data-type` is about exactly this — scrutinize every cross-layer field mapping.)
- **Resource & state leaks.** Listeners/observers/coroutines cleaned up; no captured stale `this`.
- **Off-by-one / boundary / concurrency** logic in UseCase/Repository.
- **Tests exist** for new Repository/UseCase/ViewModel branches (`unit_testing_rules`).

## Output format

```
## Review: <branch or PR>

<N> files reviewed · <M> findings (<x> blocking, <y> important)

### 🔴 Blocking
- `path/Foo.kt:42` — <issue>. <why>. [correctness | <skill-name>]
  Fix: <one line>

### 🟠 Important
- ...

### 🟡 Nits / 🔵 Suggestions
- ...

### 🌟 Praise
- ...

### ⚠️ Degraded coverage   ← omit this section entirely if all routed skills were present
- `compose-stability-diagnostics` not found — stability checked at reduced depth via inline fallback.

**Verdict:** <approve | approve-with-nits | request-changes>
```

Keep findings concrete and cite `file:line`. Prefer a few high-confidence findings over a long uncertain list, unless the user asked for an exhaustive review.