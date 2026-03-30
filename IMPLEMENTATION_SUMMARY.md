# keystone_network

**Flutter Networking Library — v1.0.0**
*API Reference, Changelog & Example Project*

---

## Table of Contents

1. [Overview](#1-overview)
2. [Installation & Setup](#2-installation--setup)
3. [ApiState](#3-apistate)
4. [ApiExecutor](#4-apiexecutor)
5. [ApiError — Type-Safe Errors](#5-apierror--type-safe-errors)
6. [Pagination](#6-pagination)
7. [Cache Layer](#7-cache-layer)
8. [Interceptors](#8-interceptors)
9. [Environment Configuration](#9-environment-configuration)
10. [Migration Guide](#10-migration-guide-v01x--v100)
11. [Changelog](#11-changelog)
12. [Example Project](#12-example-project)

---

## 1. Overview

`keystone_network` is a minimal, production-ready networking library for Flutter built on top of Dio. It eliminates the boilerplate of writing per-screen loading/error/empty state logic, pagination, file uploads, and caching — while remaining fully type-safe and easy to extend.

**Core Philosophy**

- **Zero magic** — every abstraction has a clear Dart equivalent you can fall back to
- **Type-safe** — API states, errors, and data are all generic and exhaustively pattern-matched
- **Minimal dependencies** — only Dio is required; cache storage, state management, and UI layer are opt-in
- **Incremental adoption** — use only what you need; raw Dio requests work side-by-side

### What's New in v1.0.0

| Feature | What it does | Key APIs |
|---|---|---|
| Empty State | Distinct state for empty list / null responses | `ApiState.empty()`, `emptyCheck` |
| `buildWidget()` | Eliminate per-screen switch boilerplate | `buildWidget()`, `ApiStateWidget` |
| Type-safe Errors | Typed `ApiError` sealed class with 14 subtypes | `ApiError`, `ValidationError` |
| Upload Progress | Stream upload with 0–100% progress | `ApiExecutor.uploadStream()` |
| Pagination | Page-number and cursor pagination | `ApiPaginator`, `PaginatedListView` |
| Cache Layer | 5 cache policies, pluggable storage | `CacheConfig`, `CachePolicy`, `ApiCache` |

---

## 2. Installation & Setup

### pubspec.yaml

```yaml
dependencies:
  keystone_network: ^1.0.0

  # Optional persistent cache backends (pick one):
  # hive: ^2.2.3
  # shared_preferences: ^2.2.2
```

### Initialization — `main.dart`

Call `KeystoneNetwork.initialize()` once before `runApp()`. All interceptors — auth, retry, and logging — are configured here.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  KeystoneNetwork.initialize(
    baseUrl: 'https://api.example.com',
    interceptors: [
      AuthInterceptor(
        tokenManager: MyTokenManager(),
        dioProvider: KeystoneNetwork.dioProvider,
      ),
      RetryInterceptor(dioProvider: KeystoneNetwork.dioProvider),
      LoggingInterceptor(level: LogLevel.body),
    ],
  );

  runApp(const MyApp());
}
```

> **Note:** For multiple API base URLs, use `KeystoneNetwork.createInstance()` to get a separate Dio instance per endpoint.

---

## 3. ApiState

`ApiState` is a sealed class that represents the full lifecycle of a network request. Every screen should track state using this type.

### 3.1 States

| State | When emitted | Payload |
|---|---|---|
| `idle()` | Before any request is made | — |
| `loading()` | Request in-flight | — |
| `success(T data)` | Request completed with data | `T` |
| `empty()` ✨ NEW | Request succeeded, data is empty | — |
| `failed(error)` | Request failed (4xx / app error) | `FailureResponse<E>` |
| `networkError(error)` | No internet / timeout | `FailureResponse<E>` |

### 3.2 Pattern Matching

```dart
// Exhaustive match — compiler enforces all states are handled
state.when(
  idle:         ()       => const SizedBox.shrink(),
  loading:      ()       => const GalleryShimmer(),
  success:      (items)  => GalleryGrid(items),
  empty:        ()       => const EmptyGalleries(),
  failed:       (error)  => ErrorView(error.message),
  networkError: (error)  => const NoInternetView(),
);

// Optional match — handle only what you care about
state.maybeWhen(
  success: (items) => GalleryGrid(items),
  orElse:  ()      => const SizedBox.shrink(),
);
```

### 3.3 `buildWidget()` — Eliminate Boilerplate

`buildWidget()` renders a Flutter widget directly from state, replacing the 15–30 line switch block that every screen used to repeat.

```dart
// Before (v0.1.x) — 20+ lines per screen
if (state.isLoading) return GalleryShimmer();
if (state.isNetworkError) return NoInternetView();
if (state.isFailure) return ErrorView(state.error);
if (state.isSuccess && state.items.isEmpty) return EmptyView();
if (state.isSuccess) return GalleryGrid(state.items);

// After (v1.0.0) — single call
state.buildWidget(
  loading:      ()       => const GalleryShimmer(),
  success:      (items)  => GalleryGrid(items),
  empty:        ()       => const EmptyGalleries(),
  error:        (msg)    => ErrorView(msg, onRetry: _reload),
  networkError: ()       => NoInternetView(onRetry: _reload),
);
```

> `networkError` and `idle` are optional — they fall back to the `error` handler and `SizedBox.shrink()` respectively.

### 3.4 `ApiStateWidget`

A stateless Flutter widget wrapping `buildWidget()` — useful as a direct drop-in inside `build()` methods.

```dart
ApiStateWidget<List<Gallery>, ApiError>(
  state:           state,
  loadingBuilder:  () => const GalleryShimmer(),
  builder:         (items) => GalleryGrid(items),
  emptyBuilder:    () => const EmptyGalleries(),
  errorBuilder:    (msg) => ErrorView(msg),
);
```

### 3.5 Convenience Extensions

```dart
state.isIdle         // bool
state.isLoading      // bool
state.isSuccess      // bool
state.isEmpty        // bool
state.isFailed       // bool
state.isNetworkError // bool
state.isError        // bool — true for failed OR networkError
state.dataOrNull     // T?
state.errorOrNull    // FailureResponse<E>?
```

---

## 4. ApiExecutor

`ApiExecutor` wraps Dio requests with state management, error parsing, empty detection, and optional caching.

### 4.1 `execute()` — Future (recommended)

```dart
final state = await ApiExecutor.execute<List<Gallery>, ApiError>(
  request:    () => KeystoneNetwork.dio.get('/galleries'),
  parser:     (json) => (json as List).map(Gallery.fromJson).toList(),
  emptyCheck: (list) => list.isEmpty,   // auto-emits ApiState.empty
  cache: CacheConfig(
    policy:   CachePolicy.networkFirst,
    key:      'user_galleries',
    duration: Duration(minutes: 5),
  ),
);
```

### 4.2 `executeAsStateStream()` — Stream

Emits `loading` first, then the final state. Ideal for reactive UI with `setState` or `StreamBuilder`.

```dart
ApiExecutor.executeAsStateStream<User, ApiError>(
  request: () => dio.get('/user/me'),
  parser:  (json) => User.fromJson(json),
).listen((state) => setState(() => _state = state));
// Stream emits: loading → success | failed | networkError | empty
```

### 4.3 `upload()` — Single-shot upload

```dart
final formData = FormData.fromMap({
  'photo': await MultipartFile.fromFile(path, filename: 'photo.jpg'),
});

final state = await ApiExecutor.upload<Photo, ApiError>(
  request:    () => dio.post('/photos', data: formData),
  parser:     (json) => Photo.fromJson(json),
  onProgress: (sent, total) {
    print('${(sent / total * 100).round()}%');
  },
);
```

### 4.4 `uploadStream()` — Streaming upload with progress

Wire the `onSendProgress` callback directly to Dio to receive real-time progress events.

```dart
ApiExecutor.uploadStream<Photo, ApiError>(
  request: (onSendProgress) => dio.post(
    '/photos',
    data: formData,
    onSendProgress: onSendProgress,  // ← wire here
  ),
  parser: Photo.fromJson,
).listen((state) {
  state.when(
    idle:         ()         => {},
    uploading:    (progress) => updateProgressBar(progress), // 0.0–1.0
    processing:   ()         => showProcessingSpinner(),
    success:      (photo)    => onUploadComplete(photo),
    failed:       (error)    => showError(error.message),
    networkError: ()         => showNoInternet(),
  );
});
```

### 4.5 `executeRaw()` — Raw data without state wrapping

```dart
// Throws ErrorHandler on failure — use when composing multiple requests
final user = await ApiExecutor.executeRaw<User, ApiError>(
  request: () => dio.get('/user/me'),
  parser:  User.fromJson,
);
```

### UploadState

| State | When | Payload |
|---|---|---|
| `idle()` | Before upload starts | — |
| `uploading(double progress)` | Bytes being sent (0.0–1.0) | progress |
| `processing()` | All bytes sent, server processing | — |
| `success(T data)` | Upload complete | `T` |
| `failed(error)` | Upload or server error | `FailureResponse<E>` |
| `networkError()` | Connectivity failure | — |

---

## 5. ApiError — Type-Safe Errors

`ApiError` is a sealed class that replaces generic error handling with a typed hierarchy. `ErrorHandler` automatically maps every `DioException` to the correct subtype, including auto-extracting field-level messages from 422 responses.

### 5.1 Error Types

| Type | HTTP / Trigger | Extra Fields |
|---|---|---|
| `NetworkError` | Connection refused | `message?` |
| `TimeoutError` | Any timeout | — |
| `BadCertificateError` | SSL failure | — |
| `CancelledError` | `CancelToken` | — |
| `UnauthorizedError` | 401 | — |
| `ForbiddenError` | 403 | — |
| `BadRequestError` | 400 | `message?` |
| `NotFoundError` | 404 | — |
| `MethodNotAllowedError` | 405 | — |
| `ConflictError` | 409 | `message?` |
| `ValidationError` | 422 | `fields: Map<String, List<String>>`, `message?` |
| `ServerError` | 5xx | `statusCode?`, `message?` |
| `AppError` | Custom | `message` |
| `UnknownError` | Unclassified | `message?` |

### 5.2 Usage

```dart
result.when(
  failed: (error) => switch (error.errorData) {
    ValidationError(:final fields) => showFieldErrors(fields),
    UnauthorizedError()            => redirectToLogin(),
    ServerError(:final statusCode) => showServerError(statusCode),
    _                              => showGenericError(),
  },
  networkError: (_) => showNoInternet(),
  success: (data)   => render(data),
  // ... other states
);

// ValidationError helpers
final e = error as ValidationError;
e.fields['email']?.first  // → 'Invalid email format'
e.fieldMessage('email')   // → 'Invalid email format'
e.allMessages             // → ['Invalid email', 'Password too short']
```

### 5.3 Backwards Compatibility

`ErrorHandler` exposes both the new and legacy error types:

```dart
final handler = ErrorHandler<ApiError>.handle(error);

handler.failure   // FailureResponse — legacy, still works
handler.apiError  // ApiError — new type-safe property
```

---

## 6. Pagination

`ApiPaginator` eliminates the 50–80 lines of boilerplate every list screen needs: page counter, `hasMore` flag, loading state, and item-append logic.

### 6.1 Page-Number Pagination

```dart
final paginator = ApiPaginator<Gallery, ApiError>(
  request:  (page) => dio.get('/galleries', queryParameters: {'page': page}),
  parser:   Gallery.fromJson,
  pageSize: 20,
);

await paginator.loadFirst();   // Load page 1 (or refresh)
await paginator.loadNext();    // Load page 2, 3... — call on scroll end

paginator.items        // List<Gallery> — all loaded items
paginator.hasMore      // bool — false when last page reached
paginator.isLoading    // bool
paginator.currentPage  // int
paginator.state        // ApiState<List<Gallery>, ApiError>
```

### 6.2 Cursor-Based Pagination

```dart
final paginator = ApiPaginator<Photo, ApiError>.cursor(
  request: (cursor) => dio.get('/photos', queryParameters:
    cursor != null ? {'cursor': cursor} : {}),
  parser:          Photo.fromJson,
  cursorExtractor: (response) => response['meta']['nextCursor'] as String?,
);
```

### 6.3 `PaginatedListView` Widget

```dart
PaginatedListView<Gallery, ApiError>(
  paginator:      _paginator,
  itemBuilder:    (ctx, item) => GalleryCard(item),
  loadingBuilder: () => const GalleryShimmer(),
  emptyBuilder:   () => const EmptyGalleries(),
  errorBuilder:   (msg) => ErrorView(msg, onRetry: _paginator.loadFirst),
  // Optional:
  loadMoreThreshold: 0.9,                                    // trigger at 90% scroll depth
  separatorBuilder:  (ctx, i) => const Divider(),
);
```

`PaginatedListView` handles first-page shimmer, empty state, per-page footer loader, and auto-calls `loadNext()` when the user scrolls past `loadMoreThreshold`.

### 6.4 Manual listener (for custom list widgets)

```dart
// Register a rebuild callback — PaginatedListView does this internally
_paginator.addListener(() => setState(() {}));

// Always clean up
@override
void dispose() {
  _paginator.removeListener(_rebuild);
  super.dispose();
}
```

---

## 7. Cache Layer

Attach a `CacheConfig` to any `execute()` call to enable caching. No other code changes needed.

### 7.1 Cache Policies

| Policy | Behaviour | Best for |
|---|---|---|
| `networkFirst` (default) | Try network; fall back to cache on failure | Most screens — always fresh |
| `cacheFirst` | Return cache immediately; refresh in background | Fast perceived performance |
| `cacheOnly` | Never hit network | Offline mode |
| `networkOnly` | Never read/write cache | Real-time data |
| `cacheAndNetwork` | Emit cache immediately, then network result | Best UX for lists |

### 7.2 Usage

```dart
final state = await ApiExecutor.execute<List<Gallery>, ApiError>(
  request: () => dio.get('/galleries'),
  parser:  (json) => (json as List).map(Gallery.fromJson).toList(),
  cache: CacheConfig(
    policy:   CachePolicy.networkFirst,
    key:      'user_galleries',
    duration: Duration(minutes: 5),
  ),
);

// Invalidation
await ApiCache.invalidate('user_galleries');
await ApiCache.invalidatePattern('gallery_');  // prefix match — removes gallery_1, gallery_2, etc.
await ApiCache.clear();                        // wipe everything
```

### 7.3 Persistent Storage

The default storage is in-memory (lost on restart). Implement `CacheStorage` to plug in your own backend:

```dart
class HiveCacheStorage implements CacheStorage {
  @override
  Future<String?> get(String key) async => Hive.box('cache').get(key);

  @override
  Future<void> set(String key, String value, Duration ttl) async {
    await Hive.box('cache').put(key, value);
    // store expiry separately if your backend supports it
  }

  @override
  Future<void> delete(String key) => Hive.box('cache').delete(key);

  @override
  Future<void> clear() => Hive.box('cache').clear();

  @override
  Future<List<String>> keys() =>
      Future.value(Hive.box('cache').keys.cast<String>().toList());
}

// Replace at startup — before the first execute() call
ApiCache.storage = HiveCacheStorage();
```

---

## 8. Interceptors

### 8.1 `AuthInterceptor`

Automatically injects the access token into every request and refreshes it on 401 responses. Parallel requests during the refresh window are queued and replayed automatically.

```dart
AuthInterceptor(
  tokenManager: MyTokenManager(),
  dioProvider:  KeystoneNetwork.dioProvider,
  // Optional customisation:
  authHeaderKey:      'Authorization',
  tokenFormatter:     (token) => 'Bearer $token',
  shouldRefreshToken: (status) => status == 401,
)

// Skip auth on public endpoints:
dio.get('/public', options: Options(extra: {'skipAuth': true}))
```

### 8.2 `RetryInterceptor`

Exponential-backoff retry for network errors and 5xx responses. Idempotent HTTP methods (GET, PUT, DELETE, HEAD, OPTIONS, TRACE) are retried automatically. POST and PATCH require explicit opt-in.

```dart
RetryInterceptor(
  dioProvider: KeystoneNetwork.dioProvider,
  config: RetryConfig(
    maxAttempts:  3,
    initialDelay: Duration(seconds: 1),
    maxDelay:     Duration(seconds: 30),
    multiplier:   2.0,
  ),
)

// Opt-in retry for non-idempotent methods:
dio.post('/checkout', options: Options(extra: {'allowRetry': true}))
```

### 8.3 `LoggingInterceptor`

```dart
LoggingInterceptor(
  level:         LogLevel.body,          // none | basic | headers | body
  redactHeaders: ['authorization', 'cookie'],
  redactFields:  ['password', 'token', 'credit_card'],
  logPrint:      (msg) => debugPrint(msg), // custom logger
)
```

### 8.4 `TokenManager`

Implement this interface to integrate with your auth storage:

```dart
class MyTokenManager implements TokenManager {
  // Dedicated Dio for auth calls — no AuthInterceptor to avoid infinite loops
  final Dio _authDio = KeystoneNetwork.createInstance(
    baseUrl: 'https://api.example.com',
  );

  @override
  Future<String?> getAccessToken() async =>
      await secureStorage.read(key: 'access_token');

  @override
  Future<String?> getRefreshToken() async =>
      await secureStorage.read(key: 'refresh_token');

  @override
  Future<bool> refreshToken() async {
    try {
      final rt = await getRefreshToken();
      if (rt == null) return false;

      final res = await _authDio.post('/auth/refresh',
          data: {'refresh_token': rt});

      await secureStorage.write(
          key: 'access_token', value: res.data['access_token']);
      await secureStorage.write(
          key: 'refresh_token', value: res.data['refresh_token']);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearTokens() async {
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'refresh_token');
  }
}
```

---

## 9. Environment Configuration

```dart
class AppConfig extends MultiEnvironmentConfig {
  const AppConfig(super.environment);

  @override
  String getBaseUrl(Environment env) => switch (env) {
    Environment.development => 'https://dev-api.example.com',
    Environment.staging     => 'https://staging-api.example.com',
    Environment.production  => 'https://api.example.com',
  };

  @override
  Map<String, dynamic> getHeaders(Environment env) => {
    'X-App-Version': '1.0.0',
    'X-Environment': env.name,
  };
}

// Usage
const config = AppConfig(Environment.production);

KeystoneNetwork.initialize(
  baseUrl:        config.baseUrl,
  connectTimeout: config.connectTimeout,
  headers:        config.headers,
);
```

---

## 10. Migration Guide (v0.1.x → v1.0.0)

### Breaking Changes

#### `ApiState.when()` — `empty` parameter is now required

Every existing `when()` call needs an `empty` case added.

```dart
// Before
state.when(
  idle:         () => ...,
  loading:      () => ...,
  success:      (data) => ...,
  failed:       (e) => ...,
  networkError: (e) => ...,
);

// After — add empty
state.when(
  idle:         () => ...,
  loading:      () => ...,
  success:      (data) => ...,
  empty:        () => ...,   // ← ADD THIS
  failed:       (e) => ...,
  networkError: (e) => ...,
);
```

> `maybeWhen()` is unaffected — the new `empty` parameter is optional and falls through to `orElse` if omitted.

### Non-Breaking Additions

All of the following are additive and require no changes to existing code:

- `ApiError` — available via `handler.apiError`; `handler.failure` still works
- `emptyCheck` — optional parameter on `execute()`; ignored if omitted
- `cache` — optional parameter on `execute()`; ignored if omitted
- `ApiPaginator`, `PaginatedListView`, `UploadState`, `ApiCache` — all new, no conflicts

### `executeAsStream()` Deprecation

```dart
// Deprecated (still compiles, shows warning)
ApiExecutor.executeAsStream(...)

// Replace with
ApiExecutor.executeAsStateStream(...)
```

Will be removed in v2.0.0.

---

## 11. Changelog

All notable changes follow [Semantic Versioning](https://semver.org).

---

### v1.0.0 — 2026-03-30

Major stable release. Adds four production-grade features that were missing from every real project using v0.1.x, plus a type-safe error hierarchy and Flutter UI helpers.

#### ApiState — Empty State & UI Helpers

- ✅ `ADDED` `ApiState.empty()` — new sealed state for successful but empty responses
- ✅ `ADDED` `ApiState.when()` — `empty` parameter added (required)
- ✅ `ADDED` `ApiState.maybeWhen()` — `empty` parameter added (optional; falls through to `orElse`)
- ✅ `ADDED` `ApiState.map()` — `empty` case maps to `ApiState.empty()` on the output type
- ✅ `ADDED` `extension ApiStateBuildWidget.buildWidget()` — renders a Flutter `Widget` from state; replaces per-screen switch/when boilerplate
- ✅ `ADDED` `ApiStateWidget<T,E>` — `StatelessWidget` wrapping `buildWidget()`; drop-in replacement for `BlocBuilder` patterns
- 🔴 `BREAKING` `ApiState.when()` — the `empty` parameter is now required; add `empty: () => ...` to all existing `when()` calls

#### ApiError — Type-Safe Error Hierarchy

- ✅ `ADDED` `ApiError` — new sealed class with 14 concrete subtypes replacing generic exception handling
- ✅ `ADDED` `NetworkError`, `TimeoutError`, `BadCertificateError`, `CancelledError` — connectivity errors
- ✅ `ADDED` `UnauthorizedError`, `ForbiddenError` — auth errors (401/403)
- ✅ `ADDED` `BadRequestError`, `NotFoundError`, `MethodNotAllowedError`, `ConflictError` — client errors
- ✅ `ADDED` `ValidationError` — 422 errors with field-level messages; auto-extracts `errors`/`fields` keys from response body; helpers: `fields`, `allMessages`, `fieldMessage(key)`
- ✅ `ADDED` `ServerError` — 5xx errors with `statusCode`
- ✅ `ADDED` `AppError`, `UnknownError` — custom and fallback errors
- ✅ `ADDED` `ApiErrorX` extension — `isNetworkRelated`, `isAuthError`, `isClientError`, `isServerError`, `when()`, `maybeWhen()`
- ✅ `ADDED` `ErrorHandler.apiError` — new property alongside the existing `ErrorHandler.failure`; fully backwards compatible

#### ApiExecutor — Upload & Empty Detection

- ✅ `ADDED` `ApiExecutor.upload<T,E>()` — single-shot multipart upload returning `UploadState<T,E>`
- ✅ `ADDED` `ApiExecutor.uploadStream<T,E>()` — streaming upload that emits real-time `UploadState` updates; `onSendProgress` wired directly to Dio
- ✅ `ADDED` `ApiExecutor.execute()` `emptyCheck` parameter — optional predicate; emits `ApiState.empty()` instead of `success` when true
- ✅ `ADDED` `ApiExecutor.execute()` `cache` parameter — optional `CacheConfig` for automatic cache integration
- ✅ `ADDED` `ApiExecutor.executeAsStateStream()` — same `emptyCheck` and `cache` parameters; `cacheAndNetwork` policy emits two success states
- ⚠️ `DEPRECATED` `ApiExecutor.executeAsStream()` — renamed to `executeAsStateStream()`; will be removed in v2.0.0

#### UploadState

- ✅ `ADDED` `UploadState<T,E>` — new sealed class: `idle`, `uploading(double progress)`, `processing`, `success(T)`, `failed(FailureResponse)`, `networkError`
- ✅ `ADDED` `UploadState.when()` / `maybeWhen()` — exhaustive and optional pattern matching
- ✅ `ADDED` `UploadStateX` extension — `isIdle`, `isUploading`, `isProcessing`, `isSuccess`, `isFailed`, `isNetworkError`, `isError`, `isInProgress`

#### ApiPaginator

- ✅ `ADDED` `ApiPaginator<T,E>` — page-number pagination; constructor: `request(page)`, `parser`, `pageSize`
- ✅ `ADDED` `ApiPaginator.cursor` — cursor-based pagination; constructor: `request(cursor?)`, `parser`, `cursorExtractor`
- ✅ `ADDED` `loadFirst()` — load or refresh the first page
- ✅ `ADDED` `loadNext()` — load the next page; no-op if `isLoading` or `!hasMore`
- ✅ `ADDED` `reset()` — clear state without triggering a request
- ✅ `ADDED` `addListener()` / `removeListener()` — register callbacks for state changes
- ✅ `ADDED` `PaginatedListView<T,E>` — Flutter `ListView` widget wired to `ApiPaginator`; handles shimmer, empty, footer loader, and auto-triggers `loadNext`

#### Cache Layer

- ✅ `ADDED` `CachePolicy` — `networkFirst`, `cacheFirst`, `cacheOnly`, `networkOnly`, `cacheAndNetwork`
- ✅ `ADDED` `CacheConfig` — attaches policy, key, and duration to any `execute()` call
- ✅ `ADDED` `CacheStorage` interface — `get()`, `set()`, `delete()`, `clear()`, `keys()`; implement for persistent backends
- ✅ `ADDED` `InMemoryCacheStorage` — default implementation; zero dependencies; data lost on app restart
- ✅ `ADDED` `ApiCache` — global facade: `set()`, `get()`, `invalidate(key)`, `invalidatePattern(prefix)`, `clear()`, `storage` (replaceable)

#### Barrel file

- ✅ `ADDED` New exports: `api_error.dart`, `upload_state.dart`, `api_paginator.dart`, `api_cache.dart`, `paginated_list_view.dart`
- ✅ `ADDED` Dio re-exports: `FormData`, `MultipartFile` added for upload convenience

---

### v0.1.3 — 2026-03-15

Maintenance release. Fixes `RetryInterceptor` losing interceptors on retry.

- 🔧 `FIXED` `RetryInterceptor` used `new Dio()` internally on retry, losing all configured interceptors. Now requires `DioProvider` injection — uses `dioProvider.dio.fetch(options)` instead
- 🔴 `BREAKING` `RetryInterceptor` now requires `dioProvider` parameter

```dart
// Before (broken — interceptors lost on retry)
RetryInterceptor()

// After
RetryInterceptor(dioProvider: KeystoneNetwork.dioProvider)
```

---

### v0.1.2 — 2026-02-28

- ✅ `ADDED` `MultiEnvironmentConfig` — abstract helper for defining all environments in one class
- ✅ `ADDED` `LoggingInterceptor` `redactHeaders` and `redactFields` — mask sensitive values in logs
- ✅ `ADDED` `LoggingInterceptor` request ID tracking — correlates request and response log lines
- ✅ `ADDED` `DefaultEnvironmentConfig` — concrete `EnvironmentConfig` for simple single-class setup

---

### v0.1.1 — 2026-02-10

- ✅ `ADDED` `AuthInterceptor` — automatic token injection and 401 handling with refresh
- ✅ `ADDED` `AuthInterceptor` request queuing — parallel requests during token refresh are queued and replayed
- ✅ `ADDED` `TokenManager` interface — `getAccessToken`, `getRefreshToken`, `refreshToken`, `clearTokens`, `isAuthenticated`
- ✅ `ADDED` `AuthInterceptor.skipAuth` — per-request opt-out via `Options(extra: {'skipAuth': true})`
- ✅ `ADDED` `AuthInterceptor.tokenFormatter` — customisable token header format

---

### v0.1.0 — 2026-01-20

Initial release.

- ✅ `ADDED` `ApiState<T,E>` sealed class — `idle`, `loading`, `success`, `failed`, `networkError`
- ✅ `ADDED` `ApiExecutor.execute()` — type-safe request execution returning `ApiState`
- ✅ `ADDED` `ApiExecutor.executeAsStream()` — stream variant with loading emission
- ✅ `ADDED` `ApiExecutor.executeRaw()` — raw data without state wrapping
- ✅ `ADDED` `ErrorHandler<E>` — maps `DioException` to `FailureResponse`
- ✅ `ADDED` `FailureResponse<E>` — error payload with `code`, `message`, and optional typed `errorData`
- ✅ `ADDED` `ResponseCode` / `ResponseMessage` — standard HTTP and network error constants
- ✅ `ADDED` `LoggingInterceptor` — formatted request/response logging with configurable level
- ✅ `ADDED` `RetryInterceptor` — exponential backoff with idempotency guard
- ✅ `ADDED` `EnvironmentConfig` / `DefaultEnvironmentConfig` — base URL and timeout configuration
- ✅ `ADDED` `KeystoneNetwork` — initialise Dio with interceptors; `createInstance` for multiple endpoints
- ✅ `ADDED` `DioProvider` / `DefaultDioProvider` — injectable Dio reference for interceptors

---

## 12. Example Project

A complete Flutter project demonstrating every v1.0.0 feature. Three screens, each focused on a different set of APIs.

**Project structure:**

```
example/
├── pubspec.yaml
└── lib/
    ├── main.dart                    # Initialization, interceptors, nav shell
    ├── config/
    │   └── app_config.dart         # MultiEnvironmentConfig
    ├── data/
    │   ├── models.dart             # Gallery, Photo, User
    │   └── token_manager.dart      # TokenManager implementation
    └── screens/
        ├── gallery_screen.dart     # Pagination + cache + empty state
        ├── upload_screen.dart      # Upload with progress stream
        └── profile_screen.dart     # execute() + buildWidget() + ApiError
```

---

### `pubspec.yaml`

```yaml
name: keystone_network_example
description: >
  Full example demonstrating keystone_network v1.0.0: ApiState (with empty),
  buildWidget(), type-safe ApiError, upload with progress, pagination, cache.

publish_to: none
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  keystone_network: ^1.0.0

  # Optional persistent cache backends
  # hive: ^2.2.3
  # shared_preferences: ^2.2.2

  # Optional: file picking for upload demo
  # image_picker: ^1.0.7

  # Optional: secure token storage
  # flutter_secure_storage: ^9.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

---

### `lib/main.dart`

```dart
// Demonstrates:
//   1. Full initialization with all three interceptors
//   2. Environment-based configuration
//   3. Where to swap in a persistent cache backend

import 'package:flutter/material.dart';
import 'package:keystone_network/keystone_network.dart';

import 'config/app_config.dart';
import 'data/token_manager.dart';
import 'screens/gallery_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Pick environment ──────────────────────────────────────────────────────
  // In a real app: const env = String.fromEnvironment('ENV', defaultValue: 'development');
  const config = AppConfig(Environment.development);

  // ── Initialize KeystoneNetwork ────────────────────────────────────────────
  // Call this exactly once before runApp().
  // All interceptors receive the same DioProvider so the interceptor chain
  // is never lost when auth/retry internally re-fires a request.
  KeystoneNetwork.initialize(
    baseUrl:        config.baseUrl,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
    headers:        config.headers,
    interceptors: [
      // Auth — injects Bearer token, refreshes on 401, queues parallel requests
      AuthInterceptor(
        tokenManager: AppTokenManager(),
        dioProvider:  KeystoneNetwork.dioProvider,
      ),

      // Retry — exponential backoff for network errors and 5xx
      RetryInterceptor(
        dioProvider: KeystoneNetwork.dioProvider,
        config: const RetryConfig(
          maxAttempts:  3,
          initialDelay: Duration(seconds: 1),
          multiplier:   2.0,
        ),
      ),

      // Logging — full body in dev, silent in production
      LoggingInterceptor(
        level:        config.enableLogging ? LogLevel.body : LogLevel.none,
        redactFields: const ['password', 'token', 'access_token', 'refresh_token'],
      ),
    ],
  );

  // ── (Optional) Persistent cache storage ──────────────────────────────────
  // The default InMemoryCacheStorage loses data on restart.
  // Uncomment one of these to persist across sessions:
  //
  //   ApiCache.storage = HiveCacheStorage();
  //   ApiCache.storage = SharedPrefsCacheStorage();

  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'keystone_network Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A56DB)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    GalleryScreen(),  // pagination + cache + empty state
    UploadScreen(),   // upload with progress stream
    ProfileScreen(),  // execute() + buildWidget() + ApiError
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Gallery'),
          NavigationDestination(icon: Icon(Icons.upload_file),   label: 'Upload'),
          NavigationDestination(icon: Icon(Icons.person),        label: 'Profile'),
        ],
      ),
    );
  }
}
```

---

### `lib/config/app_config.dart`

```dart
// Demonstrates MultiEnvironmentConfig — all environments defined in one class.

import 'package:keystone_network/keystone_network.dart';

class AppConfig extends MultiEnvironmentConfig {
  const AppConfig(super.environment);

  @override
  String getBaseUrl(Environment env) => switch (env) {
    Environment.development => 'https://dev-api.example.com/v1',
    Environment.staging     => 'https://staging-api.example.com/v1',
    Environment.production  => 'https://api.example.com/v1',
  };

  @override
  Map<String, dynamic> getHeaders(Environment env) => {
    'X-App-Version': '1.0.0',
    'X-Platform':    'flutter',
    'X-Env':         env.name,
  };

  // Development gets a longer timeout so you can pause in the debugger.
  @override
  Duration getConnectTimeout(Environment env) => switch (env) {
    Environment.development => const Duration(seconds: 60),
    _                       => const Duration(seconds: 30),
  };

  @override
  Duration getReceiveTimeout(Environment env) => switch (env) {
    Environment.development => const Duration(seconds: 60),
    _                       => const Duration(seconds: 30),
  };
}
```

---

### `lib/data/models.dart`

```dart
class Gallery {
  final int    id;
  final String title;
  final String thumbnailUrl;
  final int    photoCount;

  const Gallery({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.photoCount,
  });

  factory Gallery.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Gallery(
      id:           map['id'] as int,
      title:        map['title'] as String,
      thumbnailUrl: map['thumbnail_url'] as String,
      photoCount:   map['photo_count'] as int,
    );
  }
}

class Photo {
  final int    id;
  final String url;
  final String filename;

  const Photo({required this.id, required this.url, required this.filename});

  factory Photo.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Photo(
      id:       map['id'] as int,
      url:      map['url'] as String,
      filename: map['filename'] as String,
    );
  }
}

class User {
  final int    id;
  final String name;
  final String email;
  final String avatarUrl;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  factory User.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return User(
      id:        map['id'] as int,
      name:      map['name'] as String,
      email:     map['email'] as String,
      avatarUrl: map['avatar_url'] as String,
    );
  }
}
```

---

### `lib/data/token_manager.dart`

```dart
// Demonstrates a concrete TokenManager implementation.
//
// KEY RULE: the Dio instance used inside refreshToken() must NOT have
// AuthInterceptor — a 401 on the refresh endpoint would trigger another
// refresh, creating an infinite loop.
//
// In production, replace the in-memory Map with flutter_secure_storage:
//   await _storage.write(key: 'access_token', value: token);
//   final token = await _storage.read(key: 'access_token');

import 'package:keystone_network/keystone_network.dart';

class AppTokenManager implements TokenManager {
  // In-memory store — replace with secure storage in production
  final Map<String, String> _store = {
    'access_token':  'fake-access-token-123',
    'refresh_token': 'fake-refresh-token-456',
  };

  // Dedicated Dio for auth calls — deliberately no AuthInterceptor
  final Dio _authDio = KeystoneNetwork.createInstance(
    baseUrl: 'https://dev-api.example.com/v1',
    interceptors: [
      LoggingInterceptor(level: LogLevel.basic), // logging is fine
    ],
  );

  @override
  Future<String?> getAccessToken() async => _store['access_token'];

  @override
  Future<String?> getRefreshToken() async => _store['refresh_token'];

  @override
  Future<bool> refreshToken() async {
    try {
      final rt = await getRefreshToken();
      if (rt == null) return false;

      final response = await _authDio.post(
        '/auth/refresh',
        data: {'refresh_token': rt},
      );

      _store['access_token']  = response.data['access_token'] as String;
      _store['refresh_token'] = response.data['refresh_token'] as String;
      return true;
    } catch (_) {
      return false; // AuthInterceptor will call clearTokens() next
    }
  }

  @override
  Future<void> clearTokens() async {
    _store.remove('access_token');
    _store.remove('refresh_token');
    // Navigate to login screen here in a real app
  }
}
```

---

### `lib/screens/gallery_screen.dart`

```dart
// Demonstrates:
//   • ApiPaginator — page-number pagination
//   • PaginatedListView — scroll-to-load, shimmer, empty, error with retry
//   • CachePolicy.cacheAndNetwork — instant render + background refresh
//   • ApiState.empty() rendered automatically by PaginatedListView

import 'package:flutter/material.dart';
import 'package:keystone_network/keystone_network.dart';
import '../data/models.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {

  // ApiPaginator manages: page counter, hasMore, item accumulation, state.
  // cacheAndNetwork: emits cached galleries immediately (no blank flash on
  // revisit), then refreshes silently from the network in the background.
  late final ApiPaginator<Gallery, ApiError> _paginator = ApiPaginator(
    request:  (page) => KeystoneNetwork.dio.get(
      '/galleries',
      queryParameters: {'page': page, 'per_page': 20},
    ),
    parser:   Gallery.fromJson,
    pageSize: 20,
  );

  @override
  void initState() {
    super.initState();
    // addListener is only needed when building a custom list widget.
    // PaginatedListView handles this internally.
    _paginator.addListener(_rebuild);
    _paginator.loadFirst();
  }

  @override
  void dispose() {
    _paginator.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galleries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _paginator.loadFirst,
          ),
        ],
      ),

      // PaginatedListView handles:
      //   • First-page shimmer           (loadingBuilder)
      //   • Empty state                  (emptyBuilder)
      //   • Error + retry                (errorBuilder)
      //   • Per-page footer loader
      //   • Auto-calls loadNext() at 90% scroll depth (configurable)
      body: RefreshIndicator(
        onRefresh: _paginator.loadFirst,
        child: PaginatedListView<Gallery, ApiError>(
          paginator: _paginator,

          itemBuilder: (ctx, gallery) => ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                gallery.thumbnailUrl,
                width: 56, height: 56, fit: BoxFit.cover,
              ),
            ),
            title:    Text(gallery.title),
            subtitle: Text('${gallery.photoCount} photos'),
            trailing: const Icon(Icons.chevron_right),
          ),

          loadingBuilder: () => ListView.builder(
            itemCount: 8,
            itemBuilder: (_, __) => ListTile(
              leading: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              title: Container(height: 14, color: Colors.grey.shade300),
            ),
          ),

          emptyBuilder: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No galleries yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          errorBuilder: (message) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _paginator.loadFirst,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

          separatorBuilder:  (_, __) => const Divider(height: 1),
          loadMoreThreshold: 0.85,
        ),
      ),
    );
  }
}
```

---

### `lib/screens/upload_screen.dart`

```dart
// Demonstrates:
//   • ApiExecutor.uploadStream() with real-time progress
//   • UploadState — all 6 states handled explicitly
//   • UploadState.when() for exhaustive pattern matching
//   • FormData and MultipartFile construction
//
// KEY PATTERN: wire the onSendProgress callback that uploadStream() passes
// to your request closure directly into Dio's onSendProgress parameter.
// This is the only change vs a normal dio.post() call.

import 'package:flutter/material.dart';
import 'package:keystone_network/keystone_network.dart';
import '../data/models.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  UploadState<Photo, ApiError> _state = const UploadState.idle();

  Future<void> _startUpload() async {
    final formData = FormData.fromMap({
      // In a real app the path comes from image_picker or file_picker
      'photo': await MultipartFile.fromFile(
        '/tmp/photo.jpg',
        filename: 'photo.jpg',
      ),
      'gallery_id': '42',
    });

    // uploadStream() signature:
    //   request: (void Function(int sent, int total) onSendProgress) → Future<Response>
    //
    // You MUST pass onSendProgress into dio.post(onSendProgress: ...).
    // Omitting it means the state jumps directly to processing with no progress events.
    ApiExecutor.uploadStream<Photo, ApiError>(
      request: (onSendProgress) => KeystoneNetwork.dio.post(
        '/photos',
        data: formData,
        onSendProgress: onSendProgress, // ← the only required wiring
      ),
      parser: Photo.fromJson,
    ).listen(
      (state) => setState(() => _state = state),
      onError: (_) => setState(() => _state = const UploadState.networkError()),
    );
  }

  void _reset() => setState(() => _state = const UploadState.idle());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Photo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _state.when(

          idle: () => Center(
            child: FilledButton.icon(
              icon:     const Icon(Icons.upload),
              label:    const Text('Upload Photo'),
              onPressed: _startUpload,
            ),
          ),

          // progress is 0.0–1.0
          uploading: (progress) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Uploading… ${(progress * 100).round()}%',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
            ],
          ),

          // All bytes sent — server is processing (resizing, storing, etc.)
          processing: () => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Processing on server…'),
            ],
          ),

          success: (photo) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 96, color: Colors.green),
              const SizedBox(height: 24),
              Text('Uploaded: ${photo.filename}'),
              const SizedBox(height: 32),
              OutlinedButton(onPressed: _reset, child: const Text('Upload Another')),
            ],
          ),

          failed: (error) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 96, color: Colors.red),
              const SizedBox(height: 24),
              Text(error.message, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(onPressed: _startUpload, child: const Text('Retry')),
            ],
          ),

          networkError: () => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 96, color: Colors.orange),
              const SizedBox(height: 24),
              const Text('No internet connection'),
              const SizedBox(height: 32),
              FilledButton(onPressed: _startUpload, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### `lib/screens/profile_screen.dart`

```dart
// Demonstrates:
//   • ApiExecutor.execute() with emptyCheck and CachePolicy.networkFirst
//   • ApiState.buildWidget() — single call replaces 20+ lines of if/switch
//   • Type-safe ApiError with switch expression pattern matching
//   • ValidationError — per-field messages from a 422 response
//   • Manual cache invalidation after a successful update

import 'package:flutter/material.dart';
import 'package:keystone_network/keystone_network.dart';
import '../data/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // Start idle — no request fired yet
  ApiState<User, ApiError> _state = const ApiState.idle();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Set loading manually so we control when the spinner appears.
    // execute() does not emit loading — that's intentional: on a pull-to-refresh
    // you may want to keep showing the old data while the new one loads.
    setState(() => _state = const ApiState.loading());

    final result = await ApiExecutor.execute<User, ApiError>(
      request: () => KeystoneNetwork.dio.get('/user/me'),
      parser:  User.fromJson,
      cache: const CacheConfig(
        // networkFirst: always tries the network; falls back to cache if offline.
        // The user always gets the freshest data available.
        policy:   CachePolicy.networkFirst,
        key:      'user_profile',
        duration: Duration(minutes: 10),
      ),
    );

    if (mounted) setState(() => _state = result);
  }

  Future<void> _updateDisplayName(String newName) async {
    try {
      await KeystoneNetwork.dio.patch('/user/me', data: {'name': newName});

      // Invalidate cache so the next loadProfile() fetches from the network
      await ApiCache.invalidate('user_profile');
      await _loadProfile();

    } on DioException catch (e) {
      final handler = ErrorHandler<ApiError>.handle(e);

      // Switch on ApiError subtypes — each case gets exactly the fields it needs.
      // No casting, no .runtimeType checks.
      final message = switch (handler.apiError) {
        ValidationError(:final fields) =>
          // 422: show the first server-side message for the 'name' field
          fields['name']?.first ?? 'Validation failed',

        UnauthorizedError() =>
          'Session expired. Please log in again.',

        NetworkError()  => 'No internet. Check your connection.',
        TimeoutError()  => 'Request timed out. Try again.',

        _ => handler.apiError.message,
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProfile),
        ],
      ),

      // buildWidget() — the one-liner that replaces 20+ lines of if/switch.
      // Only override the builders you need; the rest have sensible defaults.
      body: _state.buildWidget(

        loading: () => const Center(child: CircularProgressIndicator()),

        success: (user) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(user.avatarUrl),
              ),
            ),
            const SizedBox(height: 24),
            _InfoTile(label: 'Name',  value: user.name),
            _InfoTile(label: 'Email', value: user.email),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => _showEditDialog(context, user),
              child: const Text('Edit Display Name'),
            ),
          ],
        ),

        // empty: omitted — falls back to SizedBox.shrink()

        error: (message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),

        networkError: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('No internet connection'),
              const SizedBox(height: 8),
              const Text('Showing cached data if available.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, User user) {
    final controller = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDisplayName(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 60,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          const SizedBox(width: 16),
          Expanded(child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
```