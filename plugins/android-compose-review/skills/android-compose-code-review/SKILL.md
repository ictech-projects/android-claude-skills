---
name: android-compose-code-review
description: Use when reviewing a diff, branch, or PR in a Jetpack Compose Android app (Clean Architecture + MVVM + Hilt). Reviews changed Kotlin/Compose code for correctness bugs and idiom violations, then routes each Compose/Kotlin concern to the bundled focused skills (compose-*, kotlin-*). Triggers on "review my changes", "review this PR", "code review", "check my branch before pushing".
argument-hint: "[base-branch | PR<number>]   e.g. staging, main, PR92"
---

# Android + Jetpack Compose code review

Orchestrator skill. It does **two jobs**:

1. Reviews the diff for correctness bugs (the part no focused skill covers).
2. **Routes** every Compose/Kotlin idiom question to the bundled focused skill that owns it — it does not re-explain stability, recomposition, side-effects, etc. Invoke the named skill when its trigger fires.

Do not duplicate the focused skills' content here. When a concern matches the routing table, invoke that skill and apply it.

## Stack (assume unless the diff proves otherwise)

- **UI:** Jetpack Compose, Material 3.
- **Architecture:** Clean Architecture (data / domain / presentation) + MVVM, Hilt DI.
- **Async:** Coroutines + Flow; `StateFlow` for UI state, lifecycle-aware collection.

### Project conventions (apply only if present)

These are this-project hooks — check each path first; skip silently if the project doesn't have it:

- **Codegen rules** — if `codegen/android-codegen-rules.md` / `codegen/android-non-ui-rules.md` exist, generated API → Repository → UseCase layers must conform to them.
- **Test rules** — if `unit_testing_rules/` (or a `*testing_rules*.md`) exists, follow its coverage bar (commonly ≥ 90% line coverage on Repository / UseCase / ViewModel). Otherwise apply the generic rule: new Repository/UseCase/ViewModel logic should have tests.
- **CLAUDE.md** — read it for any project-specific review gates before starting.

## Process

1. **Scope.** Determine the base from the skill argument:
   - `PR<n>` (e.g. `PR92`) → `gh pr diff <n>` and `gh pr view <n>`.
   - a branch name (e.g. `staging`, `main`) → `git diff <branch>...HEAD` (three-dot: changes introduced on this branch vs the merge-base).
   - no argument → default to the repo's default branch: `git diff "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || echo main)"...HEAD`.
   List changed files; classify each as UI (`@Composable`), state-holder (`ViewModel` / state holder), domain (`UseCase`), data (`Repository` / API / DAO), or DI. For a large diff (≳20 files), fan out parallel reviewers over clusters, then synthesize and dedupe.
2. **Correctness pass** (this skill's own job — see checklist below). Read each changed file fully, not just the hunk.
3. **Compose best-practices pass.** For each changed file, match it against the routing table and invoke the relevant focused skill(s). Multiple may apply to one file — apply in parallel. If a routed skill is unavailable, follow the **Missing-skill fallback** below — never silently skip the concern.
4. **Test & convention pass.** See "Project conventions" above. New Repository/UseCase/ViewModel logic without tests is a finding.
5. **Report.** Group findings by severity. Cite `file:line`. For each, name the skill or rule it came from. Verify high-confidence/blocking findings against source before reporting; prefer concrete findings over speculation.

## Severity labels

| Label | Meaning |
|---|---|
| 🔴 `blocking` | Bug, crash, data loss, security issue, or broken architecture boundary. Must fix before merge. |
| 🟠 `important` | Real defect risk or idiom violation that will bite later (e.g. unstable params on a hot composable). Fix strongly advised. |
| 🟡 `nit` | Minor style / readability; optional. |
| 🔵 `suggestion` | Refactor / simplification opportunity. |
| 🌟 `praise` | Something done well — call it out. |

## Routing table — Compose/Kotlin concerns → focused skill

Invoke the named skill (bundled in this plugin) when the diff shows the concern:

| If the diff shows… | Invoke |
|---|---|
| Recomposition cost, hot composables, `composables.txt` / compiler reports | `/android-compose-review:compose-recomposition-performance` (router) |
| Unstable params, skippability, `@Stable`/`@Immutable`, collection params | `/android-compose-review:compose-stability-diagnostics` |
| Scroll/animation/gesture `State` read in composition, value-form layout/draw modifiers, cross-phase back-writes | `/android-compose-review:compose-state-deferred-reads` |
| `LaunchedEffect` / `DisposableEffect` / `rememberCoroutineScope` / `rememberUpdatedState` / `snapshotFlow` / snackbar / navigation effects | `/android-compose-review:compose-side-effects` |
| Bare `var` in a composable, `remember { mutableStateOf() }`, `mutableStateListOf`, `@ReadOnlyComposable` | `/android-compose-review:compose-state-authoring` |
| Where state should live: local vs hoisted vs state holder vs ViewModel | `/android-compose-review:compose-state-hoisting` |
| Screen composable taking a ViewModel, collecting state/effects, wiring callbacks while also rendering | `/android-compose-review:compose-state-holder-ui-split` |
| `Modifier` param, modifier chain order, hardcoded root layout, single-conditional wrappers | `/android-compose-review:compose-modifier-and-layout-style` |
| Reusable component with proliferating content params / boolean shape flags | `/android-compose-review:compose-slot-api-pattern` |
| `AnimatedVisibility`, `animate*AsState`, `Transition`, `AnimatedContent`, `Crossfade` | `/android-compose-review:compose-animations` |
| `@Preview`, screenshot tests, semantics assertions, UI test for a state-driven composable | `/android-compose-review:compose-ui-testing-patterns` |
| Stored `CoroutineScope`, launch from `init`/non-suspend API, `runBlocking`, broad catch around suspend | `/android-compose-review:kotlin-coroutines-structured-concurrency` |
| `StateFlow` / `SharedFlow` / `Channel` / `stateIn` / `SharingStarted` / one-shot events / `.value` | `/android-compose-review:kotlin-flow-state-event-modeling` |

If evidence spans multiple rows, apply each matching skill.

## Missing-skill fallback

These skills are bundled in this plugin, so normally all 13 resolve. But if a routed skill is **unavailable** (plugin partially installed, or this skill copied somewhere without its siblings), do **not** silently drop the concern. Instead:

1. **Detect.** If invoking the named skill fails / it isn't listed as available, treat it as missing.
2. **Fall back.** Run the one-line inline check for that concern from the table below — enough to catch the obvious cases.
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

### Verifying the bundle

To confirm all 13 routed skills are present in this plugin install, run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-skills.sh"
```

It exits non-zero and names any missing skill. Add it to CI to keep the bundle intact.

## Correctness checklist (this skill owns — no focused skill covers it)

The focused skills handle *idiom*. This pass handles *will it work*:

- **Null / empty / error states.** Network responses, nullable API fields, empty lists, loading vs error vs empty UI all handled.
- **Coroutine cancellation & error propagation.** Failures surface to UI state; no swallowed exceptions; no work leaked past cancellation; no leaked `Timer`/thread/listener that outlives the ViewModel.
- **Lifecycle.** UI state collected with `collectAsStateWithLifecycle()` (not raw `collectAsState`) so collection stops in background.
- **Architecture boundaries.** No Android/framework types in domain; no business logic in composables; ViewModel exposes immutable state; data layer maps DTO → domain; serializer annotations (Gson/kotlinx) don't leak into domain entities.
- **Data-type correctness.** Type mismatches between API DTO, domain model, and UI — wrong numeric/date/enum types, lossy conversions, locale/timezone-sensitive parsing (`SimpleDateFormat`/`String.format` without an explicit `Locale`), `toInt()` vs `toIntOrNull()`. Scrutinize every cross-layer field mapping.
- **Security (auth/network code).** No secrets logged; tokens stored securely; HTTPS/base-URL validation; interceptor order; no server-controlled cleartext URLs.
- **Resource & state leaks.** Listeners/observers/coroutines/timers cleaned up; no captured stale `this`.
- **Off-by-one / boundary / concurrency** logic in UseCase/Repository.
- **Tests exist** for new Repository/UseCase/ViewModel branches (see Project conventions).

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
- `compose-stability-diagnostics` not available — stability checked at reduced depth via inline fallback.

**Verdict:** <approve | approve-with-nits | request-changes>
```

Keep findings concrete and cite `file:line`. Prefer a few high-confidence findings over a long uncertain list, unless the user asked for an exhaustive review.