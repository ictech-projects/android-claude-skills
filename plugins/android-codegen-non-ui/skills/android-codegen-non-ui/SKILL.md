---
name: android-codegen-non-ui
description: Use when generating the non-UI data layer for a Clean Architecture Android app from a backend OpenAPI spec — Retrofit API interfaces, Request/Response classes, Repositories, UseCases, plus Room entities/DAOs, PagingSources, and Hilt DI modules. Input is a Scramble (Laravel) OpenAPI JSON. Two-stage pipeline with a mandatory developer review gate between planning and generation. Assumes the com.ictechnology.core library. Triggers on "generate the data layer", "scaffold API/repository/usecase from openapi", "run codegen".
argument-hint: "[stage: plan | generate]   default: plan"
---

# Android non-UI codegen (OpenAPI → API · Repository · UseCase)

Deterministic, template-driven generator for the data/domain layers. It turns a backend
**OpenAPI JSON** (exported by Scramble from a Laravel API) into Kotlin: Retrofit APIs,
Request/Response models, Repositories, UseCases, and — where flagged — Room entities/DAOs,
PagingSources, and Hilt DI modules.

This is a **low-freedom, follow-the-rules** task. The authoritative rules are bundled here;
follow them literally, do not improvise structure:

- [`reference/codegen-rules.md`](reference/codegen-rules.md) — the pipeline: stages, `plan.yaml` /
  `plan-preview.md` structure, shared-model detection, flag rules, per-layer generation rules,
  prompt templates. (§ numbers below point into it.)
- [`reference/non-ui-rules.md`](reference/non-ui-rules.md) — the Kotlin coding conventions each
  generated layer must follow (API, Request, Response, Resource/AppError, BaseRepository,
  Repository, PagingSource, UseCase, DI module, Room). **Assumes `com.ictechnology.core`** —
  verify that dependency is present first (non-ui §0 Network Bootstrap).

> Path note: the rules refer to `codegen/android-codegen-rules.md` and `codegen/android-non-ui-rules.md`.
> In this skill those two files live at **`reference/codegen-rules.md`** and
> **`reference/non-ui-rules.md`**. The developer-supplied input still lives in the project at
> **`codegen/openapi.json`**.

## Input (developer provides)

| File | Location | What it is |
|---|---|---|
| OpenAPI JSON | `codegen/openapi.json` | Scramble export from the Laravel backend |

If `codegen/openapi.json` is missing, stop and ask the developer to export it. Do not invent a spec.

## The pipeline — and the gate that must not be skipped

Parse → **Plan** → ⟨developer review⟩ → **Generate**. Never run Generate without an approved plan.

### Stage 1 — Parse (codegen §4)
Read `codegen/openapi.json` + both reference files. Extract every endpoint from `paths`
(operationId, `tags[0]`, method, path, request/response schema, security, query/path params).
Apply flag detection (§10) and shared-model detection (§9).

### Stage 2 — Plan (codegen §5) — produces exactly two files, no code
- `codegen/plan.yaml` — machine-readable plan (every endpoint; structure in §7).
- `codegen/plan-preview.md` — human-readable folder tree + shared-model analysis (§8).
- Leave every `shared_models[].decision` as `null` — **the developer fills these in**.
- The developer also sets `meta.base_package` (and `base_url`) before Stage 3.
- Then print:
  ```
  Stage 2 complete.
  → codegen/plan.yaml
  → codegen/plan-preview.md
  Review both files, fill in all shared_models decisions, then trigger Stage 3.
  ```
- **STOP here.** Wait for the developer to review/edit and explicitly request Stage 3.

### Stage 3 — Generate (codegen §6) — writes Kotlin into `src/`
- Read `plan.yaml` first. **If any `shared_models[].decision` is still `null`, stop and list
  them — do not generate anything** until all are resolved (and `base_package` is set).
- Generate strictly to the paths declared in `plan.yaml`, in the order in §6 (shared models →
  responses → requests → Room entity/DAO → DatabaseManager → APIs by tag → repositories by tag →
  PagingSources → UseCases → DI modules per tag).
- If a target file already exists, **ask before overwriting**.
- Every generated file must obey the conventions in `reference/non-ui-rules.md` for its layer.

## Argument

- `plan` (default) — run Stages 1–2 and stop at the gate.
- `generate` — run Stage 3 from the (reviewed) `codegen/plan.yaml`.

## Reference map

| Need | Section |
|---|---|
| Pipeline overview / input / output files | codegen §1–§3 |
| Stage 1 Parse / Stage 2 Plan / Stage 3 Generate | codegen §4 / §5 / §6 |
| `plan.yaml` structure & `plan-preview.md` structure | codegen §7 / §8 |
| Shared-model detection / flag rules | codegen §9 / §10 |
| Per-layer generation rules / prompt templates | codegen §11 / §12 |
| `com.ictechnology.core` bootstrap check | non-ui §0 |
| Layer conventions (API/Request/Response/Repository/UseCase/DI/Room/Paging) | non-ui §3–§12 |

## Relationship to the other plugins

After generating a layer, use **`android-unit-testing`** to test the new Repository/UseCase to
≥90% coverage, and **`android-compose-review`** to review the generated diff.