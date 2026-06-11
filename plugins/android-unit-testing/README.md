# android-unit-testing

Generate and review **JVM unit tests** for Clean Architecture + MVVM Android apps —
Repository, UseCase, ViewModel, validators, DataStore wrappers, logic utils, PagingSource —
to a **≥ 90% line-coverage** bar. It **detects** the project's mocking library, JUnit version,
and error model rather than assuming, and supports both **MockK** and **Mockito**.

## Install

```text
/plugin marketplace add anjas29/android-claude-skills
/plugin install android-unit-testing@android-skills
```

## Use

```text
/android-unit-testing:android-unit-testing LeaveViewModel     # write tests for one class
/android-unit-testing:android-unit-testing AuthRepository     # …or a repository / use case
/android-unit-testing:android-unit-testing                     # let it pick scope from context
```

It runs an **onboarding pass first** (non-skippable): detect base package, JUnit 4 vs 5,
MockK vs Mockito, the `Resource`/error model, existing harness + fixtures, then reads the
source under test before writing anything. It finishes by running the project's
`test*UnitTest` task and the coverage task (jacoco/kover) and reporting actual coverage.

## What's inside

| Part | Purpose |
|---|---|
| `SKILL.md` | Thin entry point: onboarding-first workflow + section map |
| `reference/unit-testing-rules.md` | The full ruleset (scope, universal rules, per-layer rules, 90% strategy, anti-patterns, coverage commands, worked example) |
| `templates/mockk/` · `templates/mockito/` | Copy-paste skeletons: `repository_test`, `usecase_test`, `viewmodel_test` |

## Notes

- Project-agnostic — nothing is hardcoded to a specific app; it reads `build.gradle.kts`,
  `libs.versions.toml`, and your `Resource`/`BaseRepository` to adapt.
- Pairs with **android-compose-review**: when a review flags missing tests, this writes them.