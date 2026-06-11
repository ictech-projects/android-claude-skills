# android-claude-skills — Claude Code skill marketplace (private)

A private [Claude Code](https://code.claude.com) marketplace that distributes Android
development plugins to the team, across any project.

## Plugins

Each plugin has its own page — click through for a brief and runnable commands.

| Plugin | What it does | Page |
|---|---|---|
| **android-compose-review** | Review a diff / branch / PR; routes Compose & Kotlin idioms to 13 focused skills. | [→ docs](plugins/android-compose-review/README.md) |
| **android-unit-testing** | Write/review unit tests (Repository · UseCase · ViewModel) to ≥90% coverage; MockK or Mockito. | [→ docs](plugins/android-unit-testing/README.md) |
| **android-codegen-non-ui** | Generate the data layer (API · Repository · UseCase + Room/Paging/DI) from an OpenAPI spec, Plan→Generate with a review gate. | [→ docs](plugins/android-codegen-non-ui/README.md) |
| **android-codegen-ui** | Generate Compose UI (screens + ViewModel/UiState, components, icons, permissions) from a Figma design; six-stage pipeline with a review gate. Requires Figma MCP. | [→ docs](plugins/android-codegen-ui/README.md) |

They compose: **codegen-ui** (Figma→screens) + **codegen-non-ui** (OpenAPI→data) scaffold the
layers → **unit-testing** tests them → **compose-review** reviews the diff.

## Install

One-time, per machine — add the marketplace, then install the plugins you want:

```text
/plugin marketplace add anjas29/android-claude-skills
/plugin install android-compose-review@android-skills
/plugin install android-unit-testing@android-skills
/plugin install android-codegen-non-ui@android-skills
/plugin install android-codegen-ui@android-skills
```

Private repo — works as long as your `git`/`gh` is authenticated. For headless/CI, export
`GITHUB_TOKEN`. Default install scope is your user (all your projects); add `--scope project`
on the `install` command (not on `marketplace add`) to commit the choice for teammates.

## Quick start

```text
/android-compose-review:android-compose-code-review PR92         # review a PR
/android-unit-testing:android-unit-testing LeaveViewModel         # write tests for a class
/android-codegen-non-ui:android-codegen-non-ui plan               # plan a data layer from codegen/openapi.json
/android-codegen-ui:android-codegen-ui plan                       # plan Compose screens from a Figma design
```

See each plugin's page for full usage.

## Zero-setup for a specific project

Commit this to a project's `.claude/settings.json` so teammates get a one-time install prompt
when they trust the repo:

```json
{
  "extraKnownMarketplaces": {
    "android-skills": {
      "source": { "source": "github", "repo": "anjas29/android-claude-skills" }
    }
  }
}
```

## Update

```text
/plugin marketplace update android-skills
```

Omit `version` in a plugin's `plugin.json` for commit-SHA versioning (every push updates), or
bump `version` for explicit releases.

## Maintainers

- Re-vendoring / pin bumps for the review focused skills:
  [`plugins/android-compose-review/ATTRIBUTION.md`](plugins/android-compose-review/ATTRIBUTION.md).
- After changing the review routing table, run
  `plugins/android-compose-review/scripts/verify-skills.sh`.