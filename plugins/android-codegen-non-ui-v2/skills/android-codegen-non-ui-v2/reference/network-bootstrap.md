# Network Bootstrap Templates (`com.ictechnology.core`)

> **Read this file only when the detection in `non-ui-rules.md §0.1` reports a missing marker.**
> If all markers are present, do **not** load this file — treat the bootstrap as read-only and
> generate feature code against it. This is generated **once per project** and reused thereafter.

Generate only the templates for markers that are missing in §0.1. Substitute
`{base_package}` for the project package (e.g. `com.ictechnology.hris`).

Before relying on `Resource`, `AppError`, `NetworkConfigIFace`, etc., confirm the
`com.ictechnology.core` dependency is declared (non-ui §0.2). Do **not** redefine any of these
core types locally — they come from the library.

---

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
