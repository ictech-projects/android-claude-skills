# android-claude-skills — Claude Code skill marketplace (private)

A private [Claude Code](https://code.claude.com) marketplace that distributes Android
development plugins to the whole team, across any project.

### Plugins

**`android-compose-review`** — code-review orchestrator:
- **`android-compose-code-review`** — reviews a diff/branch/PR for correctness bugs and
  routes Compose/Kotlin idioms to the focused skills below.
- **13 focused skills** — `compose-*` and `kotlin-*`, vendored from
  [`chrisbanes/skills`](https://github.com/chrisbanes/skills) (Apache-2.0; see
  `plugins/android-compose-review/ATTRIBUTION.md`).
- **`scripts/verify-skills.sh`** — CI gate asserting the bundle stays intact.

**`android-unit-testing`** — test generation/review:
- **`android-unit-testing`** — writes/reviews unit tests for Repository / UseCase / ViewModel
  to ≥90% coverage; detects MockK vs Mockito, JUnit version, and error model. Bundles the full
  ruleset (`reference/`) and MockK/Mockito templates (`templates/`).

**`android-codegen-non-ui`** — data-layer generator:
- **`android-codegen-non-ui`** — generates the non-UI data layer (Retrofit API → Repository →
  UseCase, + Room/Paging/DI) from a Scramble/Laravel OpenAPI JSON. Two-stage **Plan → Generate**
  pipeline with a mandatory developer review gate. Assumes `com.ictechnology.core`.

## Install (per teammate)

```text
/plugin marketplace add anjas29/android-claude-skills
/plugin install android-compose-review@android-skills
/plugin install android-unit-testing@android-skills
/plugin install android-codegen-non-ui@android-skills
```

Works for this **private** repo as long as your `git`/`gh` is authenticated to the org.
For headless/CI use, export `GITHUB_TOKEN` so the marketplace can be fetched non-interactively.

## Zero-setup for a specific project

To make a project offer the install automatically when a teammate trusts the repo,
commit this to that project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "android-skills": {
      "source": { "source": "github", "repo": "anjas29/android-claude-skills" }
    }
  }
}
```

## Use

In any Android project, after install:

```text
/android-compose-review:android-compose-code-review            # review vs default branch
/android-compose-review:android-compose-code-review staging    # review vs staging
/android-compose-review:android-compose-code-review PR92        # review GitHub PR #92
```

The orchestrator auto-invokes the focused skills as needed. The focused skills are also
usable directly, e.g. `/android-compose-review:compose-stability-diagnostics`.

Write tests with the testing plugin:

```text
/android-unit-testing:android-unit-testing LeaveViewModel    # write tests for a class
/android-unit-testing:android-unit-testing                    # let it pick scope from context
```

Generate a data layer from an OpenAPI spec (place it at `codegen/openapi.json` first):

```text
/android-codegen-non-ui:android-codegen-non-ui plan          # Stage 1–2: plan.yaml + preview, then STOP
# review/edit codegen/plan.yaml (fill shared_models decisions + base_package)
/android-codegen-non-ui:android-codegen-non-ui generate      # Stage 3: write Kotlin into src/
```

## Update

```text
/plugin marketplace update android-skills
```

Omit `version` in `plugin.json` for commit-SHA versioning (every push updates), or bump
the `version` field for explicit releases.

## Maintainers

- Re-vendoring / pin bumps for the focused skills: see
  `plugins/android-compose-review/ATTRIBUTION.md`.
- After changing the routing table, run `plugins/android-compose-review/scripts/verify-skills.sh`.