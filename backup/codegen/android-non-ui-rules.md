# Android Non-UI Rules
# Kotlin Coding Style & Conventions — Data / Domain Layers

> Version: 1.0
> Platform: Android, Kotlin
> Scope: API, Repository, UseCase, DI — excludes UI/ViewModel layer
> Applies to: Any project using this pipeline

---

## Table of Contents

0. [Network Bootstrap — Prerequisite Check](#0-network-bootstrap--prerequisite-check)
1. [Project Structure](#1-project-structure)
2. [Kotlin Style](#2-kotlin-style)
3. [API Layer](#3-api-layer)
4. [Request Classes](#4-request-classes)
5. [Response Classes](#5-response-classes)
6. [Resource & AppError](#6-resource--apperror)
7. [BaseRepository](#7-baserepository)
8. [Repository](#8-repository)
9. [PagingSource](#9-pagingsource)
10. [UseCase](#10-usecase)
11. [DI Module](#11-di-module)
12. [Room — DAO & Entity](#12-room--dao--entity)

---

## 0. Network Bootstrap — Prerequisite Check

> **Run this BEFORE generating any Api / Repository / UseCase / DI Module.**
> The generated code depends on a shared network layer built on top of the
> `com.ictechnology.core` library (Resource, AppError, NetworkConfigIFace,
> NetworkMonitorIFace, TokenProvider). Every project using this pipeline shares the
> **same** bootstrap, so it is generated once per project and reused for every
> feature thereafter.

### 0.1 Detection

Before generating feature code, check whether the project already has the network
bootstrap. The base package is `{base_package}` (e.g. `com.ictechnology.hris`).
Look for these files — search by class name, not only by exact path, since the
package may differ between projects:

| Concern | Marker file / class | Default location |
|---|---|---|
| Dispatcher qualifiers + `AppModule` | `AppModule.kt` (`@IoDispatcher`, `@MainDispatcher`, `@DefaultDispatcher`) | `di/AppModule.kt` |
| Base repository | `BaseRepository.kt` (`abstract class BaseRepository`) | `features/data/remote/base/BaseRepository.kt` |
| Base repo deps | `BaseRepositoryDependencies.kt` | `features/data/remote/base/BaseRepositoryDependencies.kt` |
| Retrofit/OkHttp DI | `AppNetworkModule.kt` | `di/network/` |
| Deps/scope/token DI | `NetworkModule.kt` (`@ApplicationScope`, `BaseRepositoryDependencies`) | `di/network/` |
| Core-library config binding | `AppNetworkConfigModule.kt` (`@Binds` core contracts) | `di/network/` |
| Network monitor | `AndroidNetworkMonitor.kt` (implements `NetworkMonitorIFace`) | `di/network/` |
| Token provider | `AppTokenProvider.kt` (implements `TokenProvider`) | `di/network/` |

Rules:

- **If all markers are present** → do **not** regenerate or modify them. Treat the
  bootstrap as read-only and generate feature code against it (Sections 3–12).
- **If any marker is missing** → generate the missing files from the templates in
  §0.3 before generating feature code. Match the existing project's `{base_package}`.
- The classes `AppNetworkModule` *references* — the API factory, the OkHttp/Retrofit
  providers, and the network-config provider — are **project-supplied**, not templated
  here. The module itself is templated (§0.3); generate it to match those classes'
  actual names in the project. If those referenced classes are missing, flag it.
- Never duplicate a class that already exists under a different package — reuse it.
- Confirm the `com.ictechnology.core` dependency is declared (see §0.2) before
  relying on `Resource`, `AppError`, `NetworkConfigIFace`, etc.

### 0.2 `com.ictechnology.core` dependency

The bootstrap imports from the shared core library:

- `com.ictechnology.core.models.Resource`, `AppError`, `UiText`
- `com.ictechnology.core.network.contract.NetworkConfigIFace`, `NetworkMonitorIFace`
- `com.ictechnology.core.network.internal.interceptor.TokenProvider`

If the project does **not** declare this dependency, add it (Gradle module
coordinate matching the project's setup) before generating. Do **not** redefine
any of these core types locally — they come from the library.

### 0.3 Bootstrap templates (create only when missing)

Generate these only for markers that are missing in §0.1. Substitute
`{base_package}` for the project package.

**`di/AppModule.kt`** — dispatcher qualifiers + factory annotations used everywhere:

```kotlin
@Qualifier @Retention(AnnotationRetention.BINARY) annotation class IoDispatcher
@Qualifier @Retention(AnnotationRetention.BINARY) annotation class MainDispatcher
@Qualifier @Retention(AnnotationRetention.BINARY) annotation class DefaultDispatcher
@Qualifier @Retention(AnnotationRetention.RUNTIME) annotation class AppGuestRetrofit
@Qualifier @Retention(AnnotationRetention.BINARY) annotation class HttpClientAppGuestInterceptor

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @IoDispatcher @Provides @Singleton
    fun provideIoDispatcher(): CoroutineDispatcher = Dispatchers.IO

    @MainDispatcher @Provides @Singleton
    fun provideMainDispatcher(): CoroutineDispatcher = Dispatchers.Main

    @DefaultDispatcher @Provides @Singleton
    fun provideDefaultDispatcher(): CoroutineDispatcher = Dispatchers.Default
}
```

**`features/data/remote/base/BaseRepositoryDependencies.kt`**:

```kotlin
data class BaseRepositoryDependencies(
    val authSessionManager: AuthSessionManager,
    val networkMonitor: NetworkMonitorIFace
)
```

**`features/data/remote/base/BaseRepository.kt`** — `executeRequest` (auth, clears
session on 401) and `executePublicRequest` (no session handling), both delegating to
a private `safeApiCall` that uses `NetworkMonitorIFace` and returns `Resource<T?>`:

```kotlin
abstract class BaseRepository(
    private val deps: BaseRepositoryDependencies
) {
    protected suspend fun <T> executeRequest(
        apiCall: suspend () -> Response<ApiResponse<T>>
    ): Resource<T?> {
        val result = safeApiCall(deps.networkMonitor, apiCall)

        if (result is Resource.Error && result.error is AppError.Unauthorized) {
            deps.authSessionManager.clearSession()
            deps.authSessionManager.emitAuthEvent(AuthEvent.SessionExpired)
        }

        return result
    }

    protected suspend fun <T> executePublicRequest(
        apiCall: suspend () -> Response<ApiResponse<T>>
    ): Resource<T?> {
        return safeApiCall(deps.networkMonitor, apiCall)
    }
}

private suspend inline fun <T> safeApiCall(
    networkMonitor: NetworkMonitorIFace,
    crossinline apiCall: suspend () -> Response<ApiResponse<T>>
): Resource<T?> {
    if (!networkMonitor.isConnected()) {
        return Resource.Error(AppError.Network)
    }

    return try {
        val response = apiCall()

        if (!response.isSuccessful) {
            return when (response.code()) {
                401 -> {
                    response.errorBody()?.let { errorBody ->
                        val errorResponse = errorBody.string().toErrorMap()
                        Resource.Error(AppError.Unauthorized(errorResponse.message))
                    } ?: Resource.Error(AppError.Unauthorized(response.message()))
                }
                else -> {
                    response.errorBody()?.let { errorBody ->
                        val errorResponse = errorBody.string().toErrorMap()
                        Resource.Error(
                            AppError.Http(response.code(), errorResponse.message, errors = errorResponse.errors)
                        )
                    } ?: Resource.Error(AppError.Http(response.code(), response.message(), emptyMap()))
                }
            }
        }

        val body = response.body()
            ?: return Resource.Error(AppError.Api(UiText.Static(R.string.empty_body_message)))

        if (!body.success) {
            Resource.Error(AppError.Api(UiText.Dynamic(body.message)))
        } else {
            Resource.Success(body.data)
        }
    } catch (t: Throwable) {
        if (t is CancellationException) throw t
        Resource.Error(t.toAppError())
    }
}

fun Throwable.toAppError(): AppError =
    when (this) {
        is IOException -> AppError.Network
        else -> AppError.Unknown(this)
    }

fun String.toErrorMap(): ErrorResponse {
    return if (this.isNullOrEmpty()) ErrorResponse()
    else Gson().fromJson(this, ErrorResponse::class.java)
}
```

> Requires project-side `ApiResponse<T>` and `ErrorResponse` models (data/remote
> response) and an `AuthSessionManager` exposing `clearSession()` /
> `emitAuthEvent(AuthEvent)`. `Resource`, `AppError`, `UiText` come from
> `com.ictechnology.core`.

**`di/network/AndroidNetworkMonitor.kt`** — `NetworkMonitorIFace` impl over
`ConnectivityManager`:

```kotlin
class AndroidNetworkMonitor @Inject constructor(
    @ApplicationContext context: Context
) : NetworkMonitorIFace {

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    override fun isConnected(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}
```

**`di/network/AppTokenProvider.kt`** — `TokenProvider` impl that observes
`AuthSessionManager` tokens on the `@ApplicationScope` scope:

```kotlin
class AppTokenProvider @Inject constructor(
    private val authSessionManager: AuthSessionManager,
    @param:ApplicationScope private val scope: CoroutineScope
) : TokenProvider {

    private var accessToken: String? = null
    private var refreshToken: String? = null

    init {
        scope.launch {
            authSessionManager.sessionState.collectLatest { userSession ->
                accessToken = userSession.accessToken
                refreshToken = userSession.refreshToken
            }
        }
    }

    override fun getAccessToken(): String? = accessToken
    override fun getRefreshToken(): String? = refreshToken
}
```

**`di/network/NetworkModule.kt`** — provides `@ApplicationScope CoroutineScope`,
`AppTokenProvider`, and `BaseRepositoryDependencies`:

```kotlin
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ApplicationScope

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides @ApplicationScope @Singleton
    fun providesCoroutineScope(
        @IoDispatcher ioDispatcher: CoroutineDispatcher
    ): CoroutineScope = CoroutineScope(SupervisorJob() + ioDispatcher)

    @Provides @Singleton
    fun provideAppTokenProvider(
        authSessionManager: AuthSessionManager,
        @ApplicationScope scope: CoroutineScope
    ): AppTokenProvider = AppTokenProvider(authSessionManager, scope)

    @Provides @Singleton
    fun provideBaseRepositoryDependencies(
        authSessionManager: AuthSessionManager,
        networkMonitor: NetworkMonitorIFace
    ): BaseRepositoryDependencies =
        BaseRepositoryDependencies(authSessionManager, networkMonitor)
}
```

**`di/network/AppNetworkConfigModule.kt`** — `@Binds` the core-library contracts to
the project impls. `NetworkConfigIFace` and `TokenProvider` bindings point at the
project's session-aware config/token classes:

```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class AppNetworkConfigModule {
    @Binds abstract fun bindNetworkConfig(impl: AppNetworkConfigIFace): NetworkConfigIFace
    @Binds abstract fun bindNetworkMonitor(impl: AndroidNetworkMonitor): NetworkMonitorIFace
    @Binds abstract fun bindTokenProvider(impl: AppTokenProvider): TokenProvider
    // Bind any project-specific network-config provider here as well.
}
```

**`di/network/AppNetworkModule.kt`** — provides the API factory, the guest
`OkHttpClient`, and the `@AppGuestRetrofit` `Retrofit`:

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object AppNetworkModule {

    @Provides @Singleton
    fun provideAppApiFactory(
        @AppGuestRetrofit retrofit: Retrofit
    ): AppApiFactory = AppApiFactory(retrofit)

    @Provides @Singleton @HttpClientAppGuestInterceptor
    fun provideOkHttpClient(
        config: FinalAppNetworkConfigIFace,
        guestInterceptor: GuestInterceptor
    ): OkHttpClient =
        AppOkHttpProvider.create(
            config = config,
            interceptors = listOf(guestInterceptor)
        )

    @Provides @Singleton @AppGuestRetrofit
    fun provideAppGuestRetrofit(
        config: FinalAppNetworkConfigIFace,
        gson: Gson,
        @HttpClientAppGuestInterceptor client: OkHttpClient
    ): Retrofit =
        AppRetrofitProvider.create(
            baseUrl = config.baseUrl,
            okHttpClient = client,
            gson = gson
        )
}
```

> References `AppApiFactory`, `AppOkHttpProvider`, `AppRetrofitProvider`, and
> `FinalAppNetworkConfigIFace` — these are **project-supplied** (not templated here).
> `GuestInterceptor` comes from `com.ictechnology.core`. Generate the module to match
> those classes' actual names in the project. If a project exposes a different API
> factory or config provider, swap the references accordingly.

> All templated classes above (`AppModule`, `BaseRepositoryDependencies`,
> `BaseRepository`, `AndroidNetworkMonitor`, `AppTokenProvider`, `NetworkModule`,
> `AppNetworkConfigModule`, `AppNetworkModule`) are project-stable — generate them
> verbatim from these templates. Only the API factory, OkHttp/Retrofit providers, and
> network-config provider they reference are project-specific and supplied by the
> project.

### 0.4 After bootstrap exists

Once the bootstrap is present (pre-existing or freshly generated), generate feature
DI Modules (§11) so that each feature's API is created via the project's API factory
and the repository receives `BaseRepositoryDependencies`. Use whichever factory
method the project's API factory actually declares.

---

## 1. Project Structure

```
app/src/main/java/{base_package}/
├── data/
│   ├── local/
│   │   └── database/
│   │       ├── DatabaseManager.kt
│   │       └── dao/
│   │           └── XxxDao.kt
│   └── remote/
│       ├── api/
│       │   └── XxxApi.kt
│       ├── request/
│       │   └── xxx/
│       │       └── XxxRequest.kt
│       ├── response/
│       │   └── xxx/
│       │       └── XxxResponse.kt
│       └── repository/
│           └── xxx/
│               ├── XxxRepository.kt
│               └── XxxPagingSource.kt
├── di/
│   └── xxx/
│       └── XxxModule.kt
└── domain/
    ├── entities/
    │   └── xxx/
    │       └── XxxEntity.kt
    └── usecases/
        └── xxx/
            └── XxxUseCase.kt
```

---

## 2. Kotlin Style

- Use `data class` for all request, response, and entity models
- Use `sealed class` only for result/state types — not for response variants
- Prefer `val` over `var` in data classes
- Use named arguments when calling constructors with 3+ parameters
- No unused imports
- No hardcoded strings in logic — use constants or `@SerializedName`
- Extension functions are scoped to the file or class they serve
- Private helpers inside a class are `private fun` — not top-level
- `@JvmSuppressWildcards` only where Retrofit requires it (PartMap)
- Coroutine dispatcher is always injected — never hardcoded (`Dispatchers.IO`)

---

## 3. API Layer

- One interface per feature tag, e.g. `LeaveApi`, `AuthApi`
- All functions `suspend`
- Return type always `Response<ApiResponse<T>>`
- No `@Header("Authorization")` — handled by OkHttp interceptor
- `@Header` only for explicit per-call headers (e.g. `X-Tenant-ID`)
- Multipart pattern — always `@PartMap` + separate `@Part` for file:
  ```kotlin
  @Multipart
  @POST("leave-requests")
  suspend fun submitLeaveRequest(
      @PartMap fields: Map<String, @JvmSuppressWildcards RequestBody>,
      @Part document: MultipartBody.Part?
  ): Response<ApiResponse<LeaveHistory>>
  ```
- JSON body pattern:
  ```kotlin
  @POST("leave-requests/{id}/cancel")
  suspend fun cancelLeaveRequest(
      @Path("id") id: String,
      @Body request: CancelLeaveRequest
  ): Response<ApiResponse<LeaveHistory>>
  ```
- GET with query params — all optional params are nullable:
  ```kotlin
  @GET("leave-requests")
  suspend fun getLeaveHistory(
      @Query("page") page: Int,
      @Query("per_page") perPage: Int
  ): Response<ApiResponse<LeaveHistoryPaginatedResponse>>
  ```

---

## 4. Request Classes

- `data class` with `@SerializedName` on every field
- Package: `data/remote/request/{feature}/`
- Naming: `XxxRequest.kt` — e.g. `CancelLeaveRequest`, `LoginRequest`
- No logic inside request classes
- `toPartMap()` for multipart requests lives in the **repository**, not here:
  ```kotlin
  // CancelLeaveRequest.kt — clean, no logic
  data class CancelLeaveRequest(
      @SerializedName("cancellation_reason") val cancellationReason: String?
  )
  ```

---

## 5. Response Classes

- `data class` with `@SerializedName` on every field
- Package: `data/remote/response/{feature}/`
- Naming: `XxxResponse.kt` — e.g. `LeaveHistoryPaginatedResponse`
- All fields defensive nullable unless provably safe
- No logic inside response classes
- Paginated response uses named list field matching the spec key:
  ```kotlin
  data class LeaveHistoryPaginatedResponse(
      @SerializedName("leaves") val leaves: List<LeaveHistory>,
      @SerializedName("pagination") val pagination: PaginationResponse
  )
  ```
- Shared `PaginationResponse` used across all paginated endpoints:
  ```kotlin
  data class PaginationResponse(
      @SerializedName("current_page") val currentPage: Int,
      @SerializedName("last_page") val lastPage: Int,
      @SerializedName("per_page") val perPage: Int,
      @SerializedName("total") val total: Int
  )
  ```
- `anyOf` responses: flat data class with all fields nullable — repository maps by boolean flags, no sealed class in response layer

---

## 6. Resource & AppError

These come from the shared core library. Do not redefine them.

```kotlin
sealed class Resource<out T> {
    data class Success<T>(val data: T) : Resource<T>()
    data class Error(val error: AppError) : Resource<Nothing>()
}

sealed class AppError {
    data object Network : AppError()
    data class Unauthorized(val message: String?) : AppError()
    data class Http(val code: Int, val message: String?, val errors: Map<String, List<String>>?) : AppError()
    data class Api(val message: UiText) : AppError()
    data class Unknown(val cause: Throwable) : AppError()
}
```

- Never create a `Loading` state in `Resource` — handle loading in ViewModel/UI layer
- Never unwrap `Resource` inside a UseCase — pass through as-is
- `result.error.asString(context)` used to convert `AppError` to display string

---

## 7. BaseRepository

Do not modify or regenerate this class. All repositories extend it.

```kotlin
abstract class BaseRepository(private val deps: BaseRepositoryDependencies) {

    // For authenticated endpoints — clears session on 401
    protected suspend fun <T> executeRequest(
        apiCall: suspend () -> Response<ApiResponse<T>>
    ): Resource<T?>

    // For public endpoints — no session handling
    protected suspend fun <T> executePublicRequest(
        apiCall: suspend () -> Response<ApiResponse<T>>
    ): Resource<T?>
}
```

- `executeRequest` handles: network check, HTTP errors, 401 session clear, body parsing
- `executePublicRequest` same but no session clearing on 401
- Both return `Resource<T?>`
- Never call Retrofit directly inside a repository — always go through `executeRequest` or `executePublicRequest`

---

## 8. Repository

- Concrete class — no interface
- `@Inject constructor`
- Extends `BaseRepository(deps)`
- Package: `data/remote/repository/{feature}/`
- Naming: `XxxRepository.kt`
- Constructor param order:
  1. `coroutineDispatcher: CoroutineDispatcher`
  2. `context: Context` (only if needed — e.g. PagingSource or room-cache)
  3. `api: XxxApi`
  4. `databaseManager: DatabaseManager` (only if room-cache)
  5. `deps: BaseRepositoryDependencies`
- All suspend functions use `withContext(coroutineDispatcher) { ... }`
- Authenticated → `executeRequest {}`, Public → `executePublicRequest {}`
- Returns `Resource<T?>`
- `toPartMap()` is a private extension function inside the repository:
  ```kotlin
  private fun LeaveRequest.toPartMap(): Map<String, RequestBody> {
      val mediaType = "text/plain".toMediaType()
      fun String.rb() = this.toRequestBody(mediaType)
      fun Int.rb() = this.toString().toRequestBody(mediaType)
      val map = mutableMapOf<String, RequestBody>()
      map["start_date"] = startLeave.rb()
      // nullable fields use let:
      startTime?.let { map["start_time"] = it.rb() }
      return map
  }
  ```
- room-cache pattern after network call:
  ```kotlin
  suspend fun getLeaveBalances(): Resource<List<LeaveBalance>?> {
      return withContext(coroutineDispatcher) {
          val result = executeRequest { leaveApi.getLeaveBalances() }
          if (result is Resource.Success) {
              result.data?.let { items ->
                  databaseManager.leaveBalanceDao.updateLeaveBalances(items)
              }
          }
          result
      }
  }

  fun getLeaveBalancesCached(): Flow<List<LeaveBalance>> {
      return databaseManager.leaveBalanceDao.getLeaveBalancesFlow()
  }
  ```
- paginated pattern:
  ```kotlin
  private var currentPagingSource: LeaveHistoryPagingSource? = null

  suspend fun getLeaveHistory(page: Int, perPage: Int): Resource<LeaveHistoryPaginatedResponse?> {
      return withContext(coroutineDispatcher) {
          executeRequest { leaveApi.getLeaveHistory(page, perPage) }
      }
  }

  fun getLeaveHistoryPaged(perPage: Int = 20): Flow<PagingData<LeaveHistory>> {
      return Pager(
          config = PagingConfig(
              pageSize = perPage,
              initialLoadSize = perPage,
              enablePlaceholders = false
          ),
          pagingSourceFactory = {
              LeaveHistoryPagingSource(context, this, perPage).also {
                  currentPagingSource = it
              }
          }
      ).flow
  }

  fun invalidateLeaveHistoryPagingSource() {
      currentPagingSource?.invalidate()
  }
  ```

---

## 9. PagingSource

- Package: same as repository — `data/remote/repository/{feature}/`
- Naming: `XxxPagingSource.kt`
- `@Inject constructor(context: Context, repository: XxxRepository, perPage: Int)`
- Extends `PagingSource<Int, ItemType>()`
- `load()` calls `repository.getXxx(page, perPage)`
- Maps `Resource.Success` → `LoadResult.Page`
- Maps `Resource.Error` → `LoadResult.Error(Exception(result.error.asString(context)))`
- `prevKey` = null when `pagination.currentPage == 1`
- `nextKey` = null when `pagination.currentPage >= pagination.lastPage`
- `getRefreshKey` uses `anchorPosition` + `closestPageToPosition`:
  ```kotlin
  override fun getRefreshKey(state: PagingState<Int, ItemType>): Int? {
      return state.anchorPosition?.let { pos ->
          state.closestPageToPosition(pos)?.run {
              prevKey?.plus(1) ?: nextKey?.minus(1)
          }
      }
  }
  ```

---

## 10. UseCase

- Concrete class — no interface
- `@Inject constructor(private val repository: XxxRepository)`
- Package: `domain/usecases/{feature}/`
- Naming: `VerbNounUseCase.kt` — e.g. `CancelLeaveRequestUseCase`, `GetLeaveBalancesUseCase`
- Single `suspend operator fun invoke(...)` function
- Returns `Resource<T?>` — pass through from repository, no transformation
- No business logic — that belongs in ViewModel or a dedicated validator
- One UseCase per endpoint:
  ```kotlin
  class CancelLeaveRequestUseCase @Inject constructor(
      private val leaveRepository: LeaveRepository
  ) {
      suspend operator fun invoke(id: String, reason: String): Resource<LeaveHistory?> {
          return leaveRepository.cancelLeaveRequest(id, reason)
      }
  }
  ```

---

## 11. DI Module

- One `object` per feature tag: `XxxModule.kt`
- Package: `di/{feature}/`
- `@Module @InstallIn(SingletonComponent::class)`
- `@Provides @Singleton` for everything
- API via `apiFactory.auth(XxxApi::class.java)`
- Repository constructor params explicitly named
- One `@Provides` function per UseCase:
  ```kotlin
  @Module
  @InstallIn(SingletonComponent::class)
  object LeaveModule {

      @Provides
      @Singleton
      fun provideLeaveApi(apiFactory: ApiFactory): LeaveApi {
          return apiFactory.auth(LeaveApi::class.java)
      }

      @Provides
      @Singleton
      fun provideLeaveRepository(
          @ApplicationContext context: Context,
          @IoDispatcher coroutineDispatcher: CoroutineDispatcher,
          leaveApi: LeaveApi,
          databaseManager: DatabaseManager,
          baseRepositoryDependencies: BaseRepositoryDependencies
      ): LeaveRepository {
          return LeaveRepository(
              coroutineDispatcher = coroutineDispatcher,
              context = context,
              leaveApi = leaveApi,
              databaseManager = databaseManager,
              deps = baseRepositoryDependencies
          )
      }

      @Provides
      @Singleton
      fun provideCancelLeaveRequestUseCase(
          leaveRepository: LeaveRepository
      ): CancelLeaveRequestUseCase {
          return CancelLeaveRequestUseCase(leaveRepository)
      }
  }
  ```

---

## 12. Room — DAO & Entity

### DAO

- Interface annotated with `@Dao`
- Package: `data/local/database/dao/`
- Naming: `XxxDao.kt`
- Standard functions per entity:
  ```kotlin
  @Dao
  interface LeaveBalanceDao {

      @Query("SELECT * FROM leave_balance_tbl")
      fun getLeaveBalancesFlow(): Flow<List<LeaveBalance>>

      @Query("SELECT * FROM leave_balance_tbl")
      suspend fun getLeaveBalances(): List<LeaveBalance>

      @Insert(onConflict = OnConflictStrategy.REPLACE)
      suspend fun insertLeaveBalances(balances: List<LeaveBalance>)

      @Query("DELETE FROM leave_balance_tbl")
      suspend fun clearLeaveBalances()

      @Transaction
      suspend fun updateLeaveBalances(balances: List<LeaveBalance>) {
          clearLeaveBalances()
          insertLeaveBalances(balances)
      }
  }
  ```

### Entity

- Table name pattern: `{snake_case_entity_name}_tbl`
- Annotate the domain/entity class directly — no separate DB model:
  ```kotlin
  @Entity(tableName = "leave_balance_tbl")
  data class LeaveBalance(
      @PrimaryKey val leaveTypeId: Int = 0,
      val totalDays: Double,
      val usedDays: Double,
      val remainingDays: Double,
      // embedded objects use @Embedded:
      @Embedded(prefix = "leave_type_") val leaveType: LeaveTypeBasic? = null
  )
  ```
- `@PrimaryKey` must not conflict — use list index as fallback if `id` may be 0 or null
- No migrations generated — version 1 only, developer handles future migrations

### DatabaseManager

- Add entity to `@Database(entities = [...])` — do not change version number
- Add abstract DAO property:
  ```kotlin
  abstract val leaveBalanceDao: LeaveBalanceDao
  ```
