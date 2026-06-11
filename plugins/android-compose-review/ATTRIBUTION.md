# Vendored skills — attribution

The Compose and Kotlin skills in this directory are vendored (copied verbatim) from:

- **Source:** [chrisbanes/skills](https://github.com/chrisbanes/skills) — Skills for Kotlin, Jetpack Compose, and Android development by Chris Banes (Android engineer, Google).
- **License:** Apache License 2.0 (see source repo `LICENSE`).
- **Pinned commit:** `0d0e411`
- **Vendored on:** 2026-06-10

## Why vendored (not installed via marketplace)

A pinned copy lives in the repo so the skills:
1. travel with the project for every teammate / CI clone without requiring the `android` CLI or `/plugin marketplace add`, and
2. cannot change underneath us — we re-vet before bumping the pin.

## Curated subset

We vendored 13 of the 17 upstream skills — the ones relevant to this app's stack
(Jetpack Compose + MVVM/Clean Architecture + Hilt, mobile-only).

**Intentionally NOT vendored:**
- `kotlin-multiplatform-expect-actual` — this is not a KMP project.
- `kotlin-types-value-class` — niche; revisit if we adopt value classes for Compose stability.
- `compose-focus-navigation` — TV / D-pad / hardware-keyboard focus; not a mobile HRIS concern.
- `shepherd` — a PR-babysitting agent, not a code-review skill.

## Updating the pin

```bash
git clone --depth 1 https://github.com/chrisbanes/skills /tmp/cb-skills
# re-read the changed SKILL.md files (vetting), then re-copy the curated subset
# and update the pinned commit + date above.
```

See `review_rules/review_code_rules.md` for how these skills back the PR review gates.