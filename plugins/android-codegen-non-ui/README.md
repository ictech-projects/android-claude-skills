# android-codegen-non-ui

Generate the **non-UI data layer** for a Clean Architecture Android app from a backend
**OpenAPI JSON** (exported by **Scramble** from a Laravel API): Retrofit API interfaces,
Request/Response models, Repositories, UseCases — plus Room entities/DAOs, PagingSources,
and Hilt DI modules where the spec flags them.

Runs as a **two-stage pipeline with a mandatory developer review gate** — it never generates
code from an unreviewed plan.

> Assumes the **`com.ictechnology.core`** library (Resource, AppError, NetworkConfigIFace,
> TokenProvider, …). It checks for that dependency before generating.

## Install

```text
/plugin marketplace add ictech-projects/android-claude-skills
/plugin install android-codegen-non-ui@android-skills
```

## Use

**1. Provide the spec** — export the OpenAPI JSON from the backend and save it at:

```text
codegen/openapi.json
```

**2. Plan** (Stages 1–2) — parses the spec and writes a plan, then **stops**:

```text
/android-codegen-non-ui:android-codegen-non-ui plan
```

Produces `codegen/plan.yaml` + `codegen/plan-preview.md`.

**3. Review & edit** `codegen/plan.yaml` — set `meta.base_package`, and resolve every
`shared_models[].decision` (`shared` | `separate`). The gate blocks generation while any is `null`.

**4. Generate** (Stage 3) — writes Kotlin into `src/` strictly per the plan:

```text
/android-codegen-non-ui:android-codegen-non-ui generate
```

Existing files are never overwritten without asking.

## What's inside

| Part | Purpose |
|---|---|
| `SKILL.md` | Thin entry point: the Plan → review → Generate pipeline + the gate |
| `reference/codegen-rules.md` | Pipeline: stages, `plan.yaml`/`plan-preview.md` structure, shared-model & flag detection, per-layer generation rules, prompt templates |
| `reference/non-ui-rules.md` | Kotlin conventions each generated layer must follow (API, Request, Response, Repository, UseCase, DI, Room, Paging) |

## Notes

- The real OpenAPI/Scramble export is **not** bundled — you supply `codegen/openapi.json` per project.
- Chains with the other plugins: **android-unit-testing** tests the generated Repository/UseCase
  to ≥90%, then **android-compose-review** reviews the diff.