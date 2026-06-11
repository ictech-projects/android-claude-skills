# backup — original source rules (archive)

A point-in-time snapshot of the **original rule documents** that the marketplace plugins were
derived from. **Reference / log only** — nothing here is loaded by Claude Code (it lives outside
`plugins/`, so it is not scanned as skills). The live, maintained versions are under
[`../plugins/`](../plugins/).

- **Snapshot date:** 2026-06-11
- **Source project:** `HRISApp` (`com.ictechnology.hris`)

## Contents

| Path | Original location in HRISApp | Now lives in plugin |
|---|---|---|
| `unit_testing_rules/unit_testing_rules.md` + `templates/` | `unit_testing_rules/` | `android-unit-testing` |
| `codegen/android-codegen-rules.md` | `codegen/` | `android-codegen-non-ui` |
| `codegen/android-non-ui-rules.md` | `codegen/` | `android-codegen-non-ui` |
| `ui-code/compose-ui-agent-guidelines.md` + `ui-codegen-pipeline.{md,yaml}` + `ui-plan*.template.*` | UI codegen source | `android-codegen-ui` |
| `compose-review/android-compose-code-review.SKILL.md` | `.claude/skills/android-compose-code-review/SKILL.md` (project-local, pre-plugin) | `android-compose-review` (portable rewrite) |
| `compose-review/verify-skills.sh` | `.claude/skills/verify-skills.sh` (project-local) | `android-compose-review/scripts/` |

## Excluded on purpose

- **`codegen/document.json`** — the real Scramble/Laravel OpenAPI export (project data, not a
  rule). Deliberately not archived here or shipped in any plugin.
- **`compose-*` / `kotlin-*` skills** — third-party, vendored from
  [`chrisbanes/skills`](https://github.com/chrisbanes/skills) (Apache-2.0). Not re-copied here;
  see `../plugins/android-compose-review/ATTRIBUTION.md` for provenance and the pinned commit.

## Note

These files are an archive — fixes and updates happen in `../plugins/`, not here. Treat this
folder as read-only history.