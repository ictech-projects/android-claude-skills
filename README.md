# android-claude-skills — Claude Code skill marketplace (private)

A private [Claude Code](https://code.claude.com) marketplace that distributes the
**`android-compose-review`** plugin to the whole team, across any Android project.

The plugin bundles:
- **`android-compose-code-review`** — a thin review orchestrator: it reviews a diff/branch/PR
  for correctness bugs and routes Compose/Kotlin idioms to the focused skills below.
- **13 focused skills** — `compose-*` and `kotlin-*`, vendored from
  [`chrisbanes/skills`](https://github.com/chrisbanes/skills) (Apache-2.0; see
  `plugins/android-compose-review/ATTRIBUTION.md`).
- **`scripts/verify-skills.sh`** — CI gate asserting the bundle stays intact.

## Install (per teammate)

```text
/plugin marketplace add anjas29/android-claude-skills
/plugin install android-compose-review@android-skills
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