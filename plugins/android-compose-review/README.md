# android-compose-review

Code-review orchestrator for **Jetpack Compose** Android apps (Clean Architecture + MVVM +
Hilt). It reviews a diff / branch / PR for correctness bugs, then routes each Compose/Kotlin
idiom to one of **13 bundled focused skills** (`compose-*`, `kotlin-*`) instead of guessing.

## Install

```text
/plugin marketplace add ictech-projects/android-claude-skills
/plugin install android-compose-review@android-skills
```

## Use

```text
/android-compose-review:android-compose-code-review              # review vs the repo's default branch
/android-compose-review:android-compose-code-review staging      # review vs a specific base branch
/android-compose-review:android-compose-code-review PR92         # review a GitHub PR by number
```

The orchestrator auto-invokes the right focused skill per file. You can also call one directly:

```text
/android-compose-review:compose-stability-diagnostics
/android-compose-review:compose-side-effects
/android-compose-review:kotlin-flow-state-event-modeling
```

## What you get back

Findings grouped by severity (🔴 blocking · 🟠 important · 🟡 nit · 🔵 suggestion · 🌟 praise),
each citing `file:line` and its source skill, ending with a verdict. Large diffs are fanned out
across parallel reviewers and de-duped.

## What's inside

| Part | Purpose |
|---|---|
| `android-compose-code-review` | The orchestrator: correctness pass + routing + missing-skill fallback |
| 13 × `compose-*` / `kotlin-*` | Focused review skills (recomposition, stability, side-effects, state, flow, …) |
| `scripts/verify-skills.sh` | CI gate — fails if any routed skill is missing. Run it in CI. |

## Notes

- The 13 focused skills are vendored from [`chrisbanes/skills`](https://github.com/chrisbanes/skills)
  (Apache-2.0). See [`ATTRIBUTION.md`](ATTRIBUTION.md) for the pinned commit and re-vendoring steps.
- Project hooks (codegen rules, test rules, `CLAUDE.md`) are applied **only if present** in the
  repo being reviewed, so the skill works in any Android project.
