# Android Codegen Rules
# OpenAPI JSON → Retrofit + Repository + UseCase

> Version: 2.0
> Platform: Android, Kotlin
> Pattern: Retrofit API → Repository → UseCase
> Trigger: Manual prompt to Claude Code
> Applies to: Any project using this pipeline

---

## Table of Contents

1. [Pipeline Overview](#1-pipeline-overview)
2. [Input Requirements](#2-input-requirements)
3. [Output Files](#3-output-files)
4. [Stage 1 — Parse](#4-stage-1--parse)
5. [Stage 2 — Plan](#5-stage-2--plan)
6. [Stage 3 — Generate](#6-stage-3--generate)
7. [plan.yaml Structure & Rules](#7-planyaml-structure--rules)
8. [plan-preview.md Structure](#8-plan-previewmd-structure)
9. [Shared Model Rules](#9-shared-model-rules)
10. [Flag Rules](#10-flag-rules)
11. [Generation Rules per Layer](#11-generation-rules-per-layer)
12. [Prompt Templates](#12-prompt-templates)

---

## 1. Pipeline Overview

```
INPUT                       STAGE 1             STAGE 2               STAGE 3
───────────────────────     ─────────────       ──────────────────    ─────────────────
openapi.json            →   Parse spec      →   Generate:         →   Generate code:
android-codegen-rules.md    Extract all         plan.yaml             API interfaces
android-non-ui-rules.md     endpoints           plan-preview.md       Request classes
                            Detect flags                              Response classes
                            Check shared                              Repositories
                            models                                    PagingSources
                                                                      UseCases
                                                                      DI Modules
                                                                      DAOs (if room-cache)
                                                                      Entities (if room-cache)
```

- All stages run **locally** via Claude Code
- Each stage is triggered by a **manual prompt**
- Stage 3 only runs after developer reviews and confirms Stage 2 output
- No incremental re-runs — re-generation is full and manual

---

## 2. Input Requirements

The following files must exist in the repo before running any stage:

| File | Location | Provided by |
|---|---|---|
| OpenAPI JSON export | `codegen/openapi.json` | Developer (download from backend) |
| Codegen rules (this file) | `codegen/android-codegen-rules.md` | Developer |
| Android non-UI rules | `codegen/android-non-ui-rules.md` | Developer |

Claude Code reads all three files at Stage 1 before doing anything else.

---

## 3. Output Files

Stage 2 always produces exactly **two files**, nothing else:

| File | Location | Purpose |
|---|---|---|
| `plan.yaml` | `codegen/plan.yaml` | Machine-readable plan, edited by developer, consumed by Stage 3 |
| `plan-preview.md` | `codegen/plan-preview.md` | Human-readable review: folder tree + shared model analysis |

Stage 3 produces the final Kotlin source files into the project `src/` directory based on paths declared in `plan.yaml`.

---

## 4. Stage 1 — Parse

Claude Code must perform the following steps in order:

1. Read `codegen/openapi.json`
2. Read `codegen/android-codegen-rules.md` (this file)
3. Read `codegen/android-non-ui-rules.md`
4. Extract all endpoints from `paths`
5. For each endpoint, extract:
    - `operationId`
    - `tags[0]` as the tag
    - HTTP method
    - Path string
    - Request body schema (if any)
    - Response schema for the success status code
    - Security (empty array = public)
    - Query parameters
    - Path parameters
6. Apply flag detection rules (see Section 10)
7. Apply shared model detection rules (see Section 9)
8. Proceed to Stage 2

---

## 5. Stage 2 — Plan

Claude Code generates `plan.yaml` and `plan-preview.md` simultaneously.

### Rules:
- Every endpoint in the spec gets an entry in `plan.yaml`
- No code is written in this stage
- Shared model suggestions are inserted into both files
- The `decision` field in `shared_models` is always left as `null` — developer fills it in
- After generation, Claude Code prints:
  ```
  Stage 2 complete.
  → codegen/plan.yaml
  → codegen/plan-preview.md
  Review both files, fill in all shared_models decisions, then trigger Stage 3.
  ```

---

## 6. Stage 3 — Generate

Claude Code reads `plan.yaml`, `android-codegen-rules.md`, and `android-non-ui-rules.md` then generates all Kotlin files.

### Rules:
- Reads `shared_models` block first — if any `decision: null` exists, stop and list them. Do not proceed until all are resolved.
- Generates files strictly based on paths declared in `plan.yaml` output blocks
- If a file already exists at the target path, ask before overwriting
- Generation order:
    1. Shared models (request + response)
    2. Response data classes
    3. Request data classes
    4. Room Entity classes (only for `room-cache` endpoints)
    5. DAO interfaces (only for `room-cache` endpoints)
    6. DatabaseManager update (add entity + DAO, only for `room-cache` endpoints)
    7. Retrofit API interfaces (grouped by tag)
    8. Repositories (grouped by tag)
    9. PagingSource classes (only for `paginated` endpoints)
    10. UseCases (one per endpoint)
    11. DI Module files (one per tag)

---

## 7. plan.yaml Structure & Rules

### Full Structure

```yaml
meta:
  base_package: com.yourapp        # developer sets this before Stage 3
  base_url: https://api.example.com

shared_models:
  - name: LeaveRequestBody.kt
    path: data/remote/request/LeaveRequestBody.kt
    type: request                   # request | response
    used_by:
      - leaveRequest.store
      - leaveRequest.update
    similarity: identical           # identical | subset
    subset_of: null                 # operationId of the larger response, if subset
    decision: null                  # developer fills: shared | separate

endpoints:
  - operationId: auth.login
    tag: Auth
    method: POST
    path: /auth/login
    flags:
      - public
      - requiresTenantHeader
    pagination: null
    room_cache: null
    request:
      body_type: json               # json | multipart | null
      file: data/remote/request/LoginRequest.kt
      fields:
        - name: email
          type: String
          nullable: false
          serialized_name: email
        - name: password
          type: String
          nullable: false
          serialized_name: password
    response:
      file: data/remote/response/auth/LoginData.kt
      is_anyof: true
      fields:
        - name: employee
          type: EmployeeBasicResponse
          nullable: true
          serialized_name: employee
        - name: token
          type: String
          nullable: true
          serialized_name: token
        - name: tempToken
          type: String
          nullable: true
          serialized_name: temp_token
        - name: mustChangePassword
          type: Boolean
          nullable: false
          serialized_name: must_change_password
        - name: mustSetup2fa
          type: Boolean
          nullable: false
          serialized_name: must_setup_2fa
        - name: requires2fa
          type: Boolean
          nullable: false
          serialized_name: requires_2fa
        - name: available2faMethods
          type: Available2faMethodsResponse
          nullable: true
          serialized_name: available_2fa_methods
    output:
      api:
        file: data/remote/api/AuthApi.kt
        function: login
      repository:
        file: data/remote/repository/auth/AuthRepository.kt
        function: login
      usecase:
        file: domain/usecases/auth/LoginUseCase.kt
      di:
        file: di/auth/AuthModule.kt

  - operationId: leave.balances
    tag: Leave
    method: GET
    path: /leave-balances
    flags:
      - room-cache
    pagination: null
    room_cache:
      entity_class: LeaveBalance
      table_name: leave_balance_tbl
      dao_file: data/local/database/dao/LeaveBalanceDao.kt
      entity_file: domain/entities/leaves/LeaveBalance.kt
      cached_function: getLeaveBalancesCached
    request:
      body_type: null
      file: null
      fields: []
    response:
      file: data/remote/response/leave/LeaveBalanceResponse.kt
      is_anyof: false
      fields:
        - name: leaveType
          type: LeaveTypeBasicResponse
          nullable: true
          serialized_name: leave_type
        - name: totalDays
          type: Double
          nullable: false
          serialized_name: total_days
        - name: remainingDays
          type: Double
          nullable: false
          serialized_name: remaining_days
    output:
      api:
        file: data/remote/api/LeaveApi.kt
        function: getLeaveBalances
      repository:
        file: data/remote/repository/leave/LeaveRepository.kt
        function: getLeaveBalances
      usecase:
        file: domain/usecases/leave/GetLeaveBalancesUseCase.kt
      di:
        file: di/leave/LeaveModule.kt

  - operationId: leave.index
    tag: Leave
    method: GET
    path: /leave-requests
    flags:
      - paginated
    pagination:
      type: offset
      query_params:
        - name: page
          type: Int
          nullable: false
        - name: per_page
          type: Int
          nullable: false
    room_cache: null
    request:
      body_type: null
      file: null
      fields:
        - name: status
          type: String
          nullable: true
          serialized_name: status
    response:
      file: data/remote/response/leave/LeaveHistoryPaginatedResponse.kt
      is_anyof: false
      fields:
        - name: leaves
          type: List<LeaveHistory>
          nullable: false
          serialized_name: leaves
        - name: pagination
          type: PaginationResponse
          nullable: false
          serialized_name: pagination
    output:
      api:
        file: data/remote/api/LeaveApi.kt
        function: getLeaveHistory
      repository:
        file: data/remote/repository/leave/LeaveRepository.kt
        function: getLeaveHistory
      paging_source:
        file: data/remote/repository/leave/LeaveHistoryPagingSource.kt
        paged_function: getLeaveHistoryPaged
      usecase:
        file: domain/usecases/leave/GetLeaveHistoryUseCase.kt
      di:
        file: di/leave/LeaveModule.kt

  - operationId: leave.store
    tag: Leave
    method: POST
    path: /leave-requests
    flags:
      - multipart
    pagination: null
    room_cache: null
    request:
      body_type: multipart
      file: data/remote/request/leave/LeaveRequest.kt
      fields:
        - name: startLeave
          type: String
          nullable: false
          serialized_name: start_date
        - name: endLeave
          type: String
          nullable: false
          serialized_name: end_date
        - name: leaveTypeId
          type: Int
          nullable: false
          serialized_name: leave_type_id
        - name: leaveReason
          type: String
          nullable: false
          serialized_name: reason
        - name: startTime
          type: String
          nullable: true
          serialized_name: start_time
        - name: endTime
          type: String
          nullable: true
          serialized_name: end_time
      multipart_file_field: document     # name of the file part
    response:
      file: data/remote/response/leave/LeaveHistoryResponse.kt
      is_anyof: false
      fields:
        - name: id
          type: Int
          nullable: false
          serialized_name: id
        - name: status
          type: String
          nullable: false
          serialized_name: status
    output:
      api:
        file: data/remote/api/LeaveApi.kt
        function: submitLeaveRequest
      repository:
        file: data/remote/repository/leave/LeaveRepository.kt
        function: submitLeaveRequest
      usecase:
        file: domain/usecases/leave/SubmitLeaveRequestUseCase.kt
      di:
        file: di/leave/LeaveModule.kt
```

### Field Rules

| Field | Rule |
|---|---|
| `operationId` | Taken directly from spec |
| `tag` | First tag from spec `tags[0]` |
| `method` | Uppercase: GET, POST, DELETE, PATCH |
| `path` | Exact path string from spec |
| `flags` | See Section 10 — auto-detected, developer may edit |
| `pagination` | Only present when `paginated` flag exists, else `null` |
| `room_cache` | Only present when `room-cache` flag exists, else `null` |
| `request.body_type` | `json` if `application/json`, `multipart` if `multipart/form-data`, `null` if no body |
| `request.file` | `null` if GET with only query params |
| `request.fields` | For GET: query params. For POST/multipart: body fields (excluding file part) |
| `request.multipart_file_field` | Only present when `multipart` flag — name of the `@Part` file field |
| `response.is_anyof` | `true` if spec uses `anyOf` on success response |
| `response.fields` | All fields from success response schema |
| `output.api.file` | Grouped by tag — all endpoints with same tag share one file |
| `output.repository.file` | Grouped by tag — all endpoints with same tag share one file |
| `output.paging_source` | Only present when `paginated` flag exists |
| `output.usecase` | Always one file per endpoint — never grouped |
| `output.di` | Grouped by tag — all endpoints with same tag share one module file |

### Field Type Mapping

| OpenAPI type | Kotlin type |
|---|---|
| `string` | `String` |
| `integer` | `Int` |
| `number` | `Double` |
| `boolean` | `Boolean` |
| `string` + `null` | `String?` (nullable: true) |
| `string` semantically boolean (e.g. `is_late`, `is_hourly`) | `String` — note added in preview |
| `anyOf [type, null]` | nullable version of that type |
| `array` of schema | `List<SchemaType>` |
| `anyOf [string, integer(0)]` | `String` — note: use FlexibleIntDeserializer |
| inline object | extracted as named data class |

---

## 8. plan-preview.md Structure

The preview file has exactly three sections:

### Section 1 — Folder Tree

Full generated file structure. Files with pending shared model decisions marked with `⚠️`.

```
data/
├── local/
│   └── database/
│       └── dao/
│           └── LeaveBalanceDao.kt       # room-cache
├── remote/
│   ├── api/
│   │   ├── AuthApi.kt                   # login, logout, changePassword
│   │   ├── AttendanceApi.kt             # clockIn, clockOut, getToday
│   │   └── LeaveApi.kt                  # getBalances, getHistory, submit, cancel
│   ├── request/
│   │   ├── LoginRequest.kt
│   │   ├── ClockInRequest.kt
│   │   └── leave/
│   │       └── LeaveRequest.kt          # shared ⚠️ pending decision
│   ├── response/
│   │   ├── auth/
│   │   │   └── LoginData.kt
│   │   ├── attendance/
│   │   │   └── AttendanceResponse.kt
│   │   └── leave/
│   │       ├── LeaveBalanceResponse.kt
│   │       └── LeaveHistoryPaginatedResponse.kt
│   └── repository/
│       ├── auth/
│       │   └── AuthRepository.kt
│       ├── attendance/
│       │   └── AttendanceRepository.kt
│       └── leave/
│           ├── LeaveRepository.kt
│           └── LeaveHistoryPagingSource.kt
di/
├── auth/
│   └── AuthModule.kt
└── leave/
    └── LeaveModule.kt
domain/
├── entities/
│   └── leaves/
│       └── LeaveBalance.kt              # room-cache entity
└── usecases/
    ├── auth/
    │   ├── LoginUseCase.kt
    │   └── LogoutUseCase.kt
    └── leave/
        ├── GetLeaveBalancesUseCase.kt
        ├── GetLeaveHistoryUseCase.kt
        └── SubmitLeaveRequestUseCase.kt
```

### Section 2 — Shared Model Analysis

```
SHARED MODELS — REVIEW REQUIRED
════════════════════════════════════════════════════════

[1] IDENTICAL — REQUEST
    StoreLeaveRequestRequest  ==  UpdateLeaveRequestRequest
    Fields: start_date, end_date, leave_type_id, reason, start_time, end_time
    → Suggestion: SHARE as LeaveRequest.kt
    → Set decision in plan.yaml shared_models[0]

────────────────────────────────────────────────────────

[2] SUBSET — RESPONSE
    LeaveBasicResponse  ⊂  LeaveRequestResponse
    LeaveRequestResponse has all fields of LeaveBasicResponse + 8 more
    → Suggestion: SHARE LeaveRequestResponse, retire LeaveBasicResponse
    → Set decision in plan.yaml shared_models[1]

────────────────────────────────────────────────────────

[3] SUBSET CHAIN — RESPONSE
    A ⊂ B ⊂ C detected:
    EmployeeBasicResponse  ⊂  EmployeeResponse
    → Suggestion: SHARE EmployeeResponse as canonical model
    → Set decision in plan.yaml shared_models[2]

════════════════════════════════════════════════════════
Total pending decisions: 3
Stage 3 will not run until all decisions are resolved.
```

### Section 3 — Flags Summary

```
FLAGS SUMMARY
──────────────────────────────────────────────────────
auth.login              public, requiresTenantHeader
auth.logout             -
attendance.clockIn      -
attendance.clockOut     -
leave.balances          room-cache
leave.index             paginated
leave.store             multipart
leave.cancel            -
entity.departments      -
──────────────────────────────────────────────────────
```

---

## 9. Shared Model Rules

### Request Similarity Rules

| Condition | Action |
|---|---|
| All fields identical (name, type, nullable) | Auto: `similarity: identical` → suggest shared |
| 1 or more fields differ | Auto: separate — no entry in `shared_models` |

### Response Similarity Rules

| Condition | Action |
|---|---|
| All fields identical | Auto: `similarity: identical` → suggest shared |
| All fields of B exist in A, A has more fields (B ⊂ A) | Auto: `similarity: subset` → suggest share A, flag in preview |
| Subset chain A ⊂ B ⊂ C | Flag full chain in preview → suggest share largest (C) |
| Otherwise | Auto: separate — no entry in `shared_models` |

### Decision Values

| Value | Meaning |
|---|---|
| `null` | Not yet decided — Stage 3 blocked |
| `shared` | Use the suggested shared file |
| `separate` | Generate separate files per endpoint |

---

## 10. Flag Rules

Flags are auto-detected by Claude Code from the spec. Developer may add or remove flags in `plan.yaml` after review.

| Flag | Detection Rule | Effect on Generation |
|---|---|---|
| `public` | Endpoint has `"security": []` in spec | Repository uses `executePublicRequest {}` instead of `executeRequest {}` |
| `paginated` | Success response contains a `pagination` object with `current_page`, `last_page`, `per_page`, `total` | Generates paginated response wrapper + PagingSource + `getXxxPaged()` in repository |
| `multipart` | Request body content type is `multipart/form-data` | `@Multipart` on API function, `@PartMap` + `@Part` for file, `toPartMap()` extension in repository |
| `requiresTenantHeader` | Endpoint has `X-Tenant-ID` in `parameters` with `in: header` | Adds `@Header("X-Tenant-ID") tenantId: String` to Retrofit function |
| `room-cache` | Developer adds manually in plan.yaml | Generates Entity, DAO, cached Flow function in repository, updates DatabaseManager |

---

## 11. Generation Rules per Layer

### 11.1 API Interface

- One interface file per tag, e.g. `LeaveApi.kt`
- All functions are `suspend`
- Return type: `Response<ApiResponse<T>>`
- Auth via OkHttp interceptor — no `@Header("Authorization")` on functions
- `public` flag → no change on function, handled in repository layer
- Multipart pattern:
  ```kotlin
  @Multipart
  @POST("leave-requests")
  suspend fun submitLeaveRequest(
      @PartMap fields: Map<String, @JvmSuppressWildcards RequestBody>,
      @Part document: MultipartBody.Part?
  ): Response<ApiResponse<LeaveHistory>>
  ```
- Non-multipart POST with JSON body:
  ```kotlin
  @POST("leave-requests/{id}/cancel")
  suspend fun cancelLeaveRequest(
      @Path("id") id: String,
      @Body request: CancelLeaveRequest
  ): Response<ApiResponse<LeaveHistory>>
  ```
- GET with query params:
  ```kotlin
  @GET("leave-requests")
  suspend fun getLeaveHistory(
      @Query("page") page: Int,
      @Query("per_page") perPage: Int
  ): Response<ApiResponse<LeaveHistoryPaginatedResponse>>
  ```

### 11.2 Request Classes

- Plain `data class` with `@SerializedName` per field
- Multipart requests: include a `toPartMap()` extension function — but this lives inside the **repository**, not the request class
- Nullable optional fields use `var` or are passed as nullable params to `toPartMap()`
- `toPartMap()` pattern:
  ```kotlin
  fun LeaveRequest.toPartMap(): Map<String, RequestBody> {
      val mediaType = "text/plain".toMediaType()
      fun String.rb() = this.toRequestBody(mediaType)
      fun Int.rb() = this.toString().toRequestBody(mediaType)
      val map = mutableMapOf<String, RequestBody>()
      map["start_date"] = startLeave.rb()
      map["end_date"] = endLeave.rb()
      map["leave_type_id"] = leaveTypeId.rb()
      map["reason"] = leaveReason.rb()
      startTime?.let { map["start_time"] = it.rb() }
      endTime?.let { map["end_time"] = it.rb() }
      return map
  }
  ```

### 11.3 Response Classes

- Plain `data class` with `@SerializedName` per field
- All fields defensive nullable unless spec guarantees non-null AND it is safe
- `is_anyof: true` → do not generate sealed class in response file; repository handles mapping via boolean flags
- Paginated responses have a named wrapper class:
  ```kotlin
  data class LeaveHistoryPaginatedResponse(
      @SerializedName("leaves") val leaves: List<LeaveHistory>,
      @SerializedName("pagination") val pagination: PaginationResponse
  )
  ```
  Note: the list field name matches the spec key (e.g. `leaves`, not generic `data`)

### 11.4 Repository

- Concrete class — no interface
- Annotated with `@Inject constructor`
- Extends `BaseRepository(deps: BaseRepositoryDependencies)`
- Constructor params order: `coroutineDispatcher`, `context` (if needed), `api`, `databaseManager` (if room-cache), `deps`
- All suspend functions wrapped with `withContext(coroutineDispatcher)`
- Authenticated endpoints use `executeRequest {}`
- Public endpoints use `executePublicRequest {}`
- Returns `Resource<T?>`
- Multipart: call `toPartMap()` inside `executeRequest {}`, pass result + file part to API
- `room-cache` additions:
  ```kotlin
  // after Resource.Success in network function:
  if (result is Resource.Success) {
      result.data?.let { items ->
          databaseManager.xxxDao.updateXxx(items)
      }
  }

  // cached flow function:
  fun getXxxCached(): Flow<List<Xxx>> {
      return databaseManager.xxxDao.getXxxFlow()
  }
  ```
- `paginated` additions:
  ```kotlin
  private var currentPagingSource: XxxPagingSource? = null

  fun getXxxPaged(perPage: Int = 20): Flow<PagingData<Xxx>> {
      return Pager(
          config = PagingConfig(
              pageSize = perPage,
              initialLoadSize = perPage,
              enablePlaceholders = false
          ),
          pagingSourceFactory = {
              XxxPagingSource(context, this, perPage).also {
                  currentPagingSource = it
              }
          }
      ).flow
  }

  fun invalidateXxxPagingSource() {
      currentPagingSource?.invalidate()
  }
  ```

### 11.5 PagingSource

- Generated only when `paginated` flag present
- One class per paginated endpoint
- Constructor: `context: Context`, `repository: XxxRepository`, `perPage: Int`
- Annotated with `@Inject constructor`
- Extends `PagingSource<Int, ItemType>()`
- Uses `Resource.Success` / `Resource.Error` from repository
- `prevKey` = null when `currentPage == 1`
- `nextKey` = null when `currentPage >= lastPage`
- On `Resource.Error`: `LoadResult.Error(Exception(result.error.asString(context)))`
- `getRefreshKey` uses `anchorPosition` with `closestPageToPosition`

### 11.6 UseCase

- Concrete class — no interface
- Annotated with `@Inject constructor`
- Single repository injected
- `suspend operator fun invoke(...)` returning `Resource<T?>`
- No transformation — pass through repository result directly
- One file per endpoint, e.g. `CancelLeaveRequestUseCase.kt`

### 11.7 DI Module

- One `@Module` file per tag, e.g. `LeaveModule.kt`
- `@InstallIn(SingletonComponent::class)`
- `object` class
- `@Provides @Singleton` for: API, Repository, all UseCases in the tag
- API provided via `apiFactory.auth(XxxApi::class.java)`
- Repository provided with all constructor params explicitly named
- Each UseCase has its own `@Provides` function

### 11.8 DAO (room-cache only)

- Interface annotated with `@Dao`
- Functions:
    - `getXxxFlow(): Flow<List<T>>` — non-suspend, `@Query SELECT *`
    - `getXxx(): List<T>` — suspend, `@Query SELECT *`
    - `insertXxx(items: List<T>)` — suspend, `@Insert(onConflict = OnConflictStrategy.REPLACE)`
    - `clearXxx()` — suspend, `@Query DELETE FROM table`
    - `updateXxx(items: List<T>)` — suspend, `@Transaction`, calls clear then insert

### 11.9 Entity (room-cache only)

- Existing response/domain class annotated with `@Entity(tableName = "xxx_tbl")`
- Primary key annotated with `@PrimaryKey`
- Embedded objects use `@Embedded` with prefix if needed
- No separate domain model — entity IS the model
- No migrations generated — version 1 only

### 11.10 DatabaseManager update (room-cache only)

- Add new entity to `@Database(entities = [...])` array
- Add abstract DAO property
- Do NOT change the version number — developer handles migrations manually

---

## 12. Prompt Templates

### Stage 1 + 2 Prompt
```
Read codegen/openapi.json, codegen/android-codegen-rules.md,
and codegen/android-non-ui-rules.md.
Run Stage 1 and Stage 2 as defined in the rules.
Generate codegen/plan.yaml and codegen/plan-preview.md.
```

### Stage 3 Prompt
```
Read codegen/plan.yaml, codegen/android-codegen-rules.md,
and codegen/android-non-ui-rules.md.
Run Stage 3 as defined in the rules.
Generate all Kotlin source files.
```
