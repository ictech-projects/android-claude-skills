---
name: android-unit-testing
description: Use when writing, completing, or reviewing unit tests for a Clean Architecture + MVVM Android app — Repository, UseCase, ViewModel, validators, DataStore wrappers, logic utils, or PagingSource. Targets ≥90% line coverage. Detects the project's mocking library (MockK or Mockito), JUnit version, and error model rather than assuming. Triggers on "write tests for", "add unit tests", "increase coverage", "test this ViewModel/Repository/UseCase".
argument-hint: "[class or feature to test]   e.g. LeaveViewModel, AuthRepository"
---

# Android unit testing (Clean Architecture + MVVM)

Generates and reviews JVM unit tests for the layers where business logic lives, to a
**≥ 90% line-coverage** bar on every `Repository`, `UseCase`, and `ViewModel`. The full
rules are project-agnostic and support **both MockK and Mockito** — the library, JUnit
version, error model, and file conventions are **detected from the project**, never assumed.

The complete ruleset is in [`reference/unit-testing-rules.md`](reference/unit-testing-rules.md)
(§ numbers below point into it). Copy-pasteable test skeletons are in
[`templates/`](templates/) — **`templates/mockk/`** and **`templates/mockito/`**, each with
`repository_test.md`, `usecase_test.md`, `viewmodel_test.md`.

> Note: the reference doc historically calls the template path `codegen/templates/<library>/`.
> In this skill the templates live at **`templates/<library>/`** (relative to this SKILL.md).

## Onboarding — do this first (mandatory, non-skippable)

Never write a test before completing these. Details in reference §0.

1. **Base package** — read `app/build.gradle.kts` → `applicationId`; root every package/import there. (§0.1)
2. **JUnit version** — detect 4 vs 5 from `gradle/libs.versions.toml` / `build.gradle.kts`; never mix `@Before`+`@BeforeEach`. Ask if neither is present. (§0.2)
3. **Mocking library** — detect MockK vs Mockito; pick the matching `templates/<library>/`. Ask if both or neither (recommend MockK for Kotlin). (§0.2b)
4. **Error model** — inspect the project's `Resource`/result wrapper + `BaseRepository`: typed `AppError` subtypes vs data-carrying `message`/`statusCode`. Assert against the *actual* mapping. (§0.2c)
5. **Harness files** — find/read (or create from §4) `BaseRepositoryTest`, `MockResponseFactory`, `MainDispatcherRule`, `TestAssertHelper`. Reuse what exists; propose additions and wait for confirmation. (§0.3)
6. **Fixture convention** — detect `Source.kt` functions vs `dummy/XxxDummy.kt` objects; follow the existing one, don't introduce the other. (§0.4)
7. **Read the source under test** — every public method, branch, `Event` subclass, `init {}` side-effect; replace all `Xxx` placeholders with real names before writing. (§0.5)
8. **Audit existing tests** — if a `*Test.kt` exists, read it, list covered branches, and ask whether to complete vs rewrite. Don't silently overwrite. (§0.6)
9. **Discover the Gradle task** — `./gradlew tasks --group verification`; use the real `test*UnitTest` task and note jacoco vs kover. (§0.7)

## Scope

**In scope:** Repository, UseCase, ViewModel, Validators, DataStore/prefs wrappers, logic
utils, custom `PagingSource`. **Out of scope:** Compose UI tests, screenshot tests, E2E,
Room DAO queries, pure-passthrough navigation/theming. Full table in reference §1.

## Process

1. Complete onboarding above.
2. Pick the layer and open the matching template (`templates/<library>/<layer>_test.md`).
3. Apply the **universal rules** (§3): one behavior per test, given/when/then, no logic in
   tests, deterministic time/dispatchers, fixtures over literals.
4. Apply the **layer rules** (§5): Repository (success+error per method, mapping, cache,
   request body), UseCase (pass-through + error), ViewModel (one test per `Event` + `init`,
   validation gates, state transitions via a state-collection helper).
5. Hit the bar using the **90% strategy** (§6) and avoid the **anti-patterns** (§7).
6. **Verify**: run the project's `test*UnitTest` task, then the coverage task (jacoco/kover,
   §9). Report actual coverage; don't claim done until tests pass and the bar is met.

## Reference map

| Need | Section in `reference/unit-testing-rules.md` |
|---|---|
| Onboarding / detection | §0 |
| Scope (what to test) | §1 |
| Toolchain: JUnit4 vs 5, MockK vs Mockito setup | §2 |
| Universal rules + library cheat-sheet | §3 |
| Harness/helper file templates | §4 |
| Per-layer rules (Repository / UseCase / ViewModel / DataStore / Paging) | §5 |
| Hitting 90% | §6 |
| Anti-patterns | §7 |
| Templates index | §8 |
| Coverage commands (jacoco / kover) | §9 |
| Worked example (Leave feature) | §10 |

## Relationship to code review

The `android-compose-review` plugin's review skill flags **missing tests** on new
Repository/UseCase/ViewModel logic. When it does, use this skill to write them to standard.