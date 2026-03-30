# keystone_network • Changelog

All notable changes to this project are documented here. Versions follow Semantic Versioning (MAJOR.MINOR.PATCH). Breaking changes are always called out explicitly.

---

## Legend

- **ADDED** — New features or APIs  
- **CHANGED** — Behaviour change (non-breaking)  
- **DEPRECATED** — Will be removed in a future major version  
- **BREAKING** — Requires code changes  

---

## v1.0.0 — 2026-03-30

Major stable release. Adds four production-grade features that were missing from every real project using v0.1.x, plus a type-safe error hierarchy and Flutter UI helpers.

---

### ApiState — Empty State & UI Helpers

- **ADDED** ApiState.empty() — new sealed state for successful but empty responses  
- **ADDED** ApiState<T,E>.when() — empty parameter added (required)  
- **ADDED** ApiState<T,E>.maybeWhen() — empty parameter added (optional; falls through to orElse)  
- **ADDED** ApiState<T,E>.map() — empty case maps to ApiState.empty() on the output type  
- **ADDED** extension ApiStateBuildWidget.buildWidget() — renders a Flutter Widget from state  
- **ADDED** ApiStateWidget<T,E> — StatelessWidget wrapper  

- **BREAKING** ApiState.when() — empty parameter is now required  

```dart
state.when(
  idle:         () => ...,
  loading:      () => ...,
  success:      (data) => ...,
  empty:        () => ...,   // ← ADD THIS
  failed:       (e) => ...,
  networkError: (e) => ...
);
````

---

### ApiError — Type-Safe Error Hierarchy

* **ADDED** ApiError — sealed class with 14 subtypes
* **ADDED** NetworkError, TimeoutError, BadCertificateError, CancelledError
* **ADDED** UnauthorizedError, ForbiddenError
* **ADDED** BadRequestError, NotFoundError, MethodNotAllowedError, ConflictError
* **ADDED** ValidationError — includes helpers: `fields`, `allMessages`, `fieldMessage(key)`
* **ADDED** ServerError — 5xx errors
* **ADDED** AppError, UnknownError
* **ADDED** ApiErrorX extension — helper methods and pattern matching
* **ADDED** ErrorHandler.apiError

---

### ApiExecutor — Upload & Empty Detection

* **ADDED** ApiExecutor.upload<T,E>() — multipart upload
* **ADDED** ApiExecutor.uploadStream<T,E>() — streaming upload
* **ADDED** emptyCheck parameter — emits empty state
* **ADDED** cache parameter — integrates caching
* **DEPRECATED** executeAsStream() → renamed to executeAsStateStream()

---

### UploadState<T, E>

* **ADDED** UploadState — states:

    * idle
    * uploading(progress)
    * processing
    * success
    * failed
    * networkError

* **ADDED** pattern matching: when(), maybeWhen()

* **ADDED** helpers: isIdle, isUploading, isProcessing, isSuccess, isFailed, isNetworkError

---

### ApiPaginator<T, E>

* **ADDED** Page-based and cursor-based pagination

* **ADDED** loadFirst(), loadNext(), reset()

* **ADDED** listeners: addListener(), removeListener()

* **ADDED** properties:

    * items
    * hasMore
    * isLoading
    * isEmpty
    * currentPage
    * state

* **ADDED** PaginatedListView widget

---

### Cache Layer

* **ADDED** CachePolicy:

    * networkFirst
    * cacheFirst
    * cacheOnly
    * networkOnly
    * cacheAndNetwork

* **ADDED** CacheConfig

* **ADDED** CacheStorage interface

* **ADDED** InMemoryCacheStorage

* **ADDED** ApiCache global facade

---

### keystone_network.dart barrel

* **ADDED** Exports:

    * api_error.dart
    * upload_state.dart
    * api_paginator.dart
    * api_cache.dart
    * paginated_list_view.dart

* **ADDED** Dio re-exports:

    * FormData
    * MultipartFile

---

## v0.1.3 — 2026-03-15

Maintenance release.

* **FIXED** RetryInterceptor losing interceptors
* **BREAKING** RetryInterceptor now requires dioProvider

```dart
// Old
RetryInterceptor()

// New
RetryInterceptor(dioProvider: KeystoneNetwork.dioProvider)
```

---

## v0.1.2 — 2026-02-28

* **ADDED** MultiEnvironmentConfig
* **ADDED** LoggingInterceptor redaction
* **ADDED** Request ID tracking
* **ADDED** DefaultEnvironmentConfig

---

## v0.1.1 — 2026-02-10

* **ADDED** AuthInterceptor
* **ADDED** Request queuing during token refresh
* **ADDED** TokenManager interface
* **ADDED** skipAuth option
* **ADDED** tokenFormatter

---

## v0.1.0 — 2026-01-20

Initial release.

* **ADDED** ApiState<T,E>

* **ADDED** ApiExecutor methods:

    * execute()
    * executeAsStream()
    * executeRaw()

* **ADDED** ErrorHandler

* **ADDED** FailureResponse

* **ADDED** ResponseCode / ResponseMessage

* **ADDED** LoggingInterceptor

* **ADDED** RetryInterceptor

* **ADDED** EnvironmentConfig

* **ADDED** KeystoneNetwork

* **ADDED** DioProvider
