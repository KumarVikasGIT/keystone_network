library keystone_network;

/// Keystone Network - Clean, Generic, Minimal Networking Library for Flutter
///
/// A production-ready networking library that provides:
/// - Type-safe API state management (with empty state)
/// - Automatic error handling with typed ApiError hierarchy
/// - Token management with auto-refresh
/// - Smart retry with idempotency protection
/// - Clean logging with sensitive data redaction
/// - Upload with real-time progress streaming
/// - Built-in pagination (page-number + cursor)
/// - Cache layer with five configurable policies
/// - Flutter UI helpers (buildWidget, ApiStateWidget, PaginatedListView)
///
/// ## Quick Start
///
/// ```dart
/// // 1. Initialize
/// KeystoneNetwork.initialize(
///   baseUrl: 'https://api.example.com',
///   interceptors: [
///     AuthInterceptor(
///       tokenManager: myTokenManager,
///       dioProvider: KeystoneNetwork.dioProvider,
///     ),
///     RetryInterceptor(dioProvider: KeystoneNetwork.dioProvider),
///     LoggingInterceptor(level: LogLevel.body),
///   ],
/// );
///
/// // 2. Make requests (with optional cache + empty detection)
/// final result = await ApiExecutor.execute<List<Gallery>, ApiError>(
///   request: () => KeystoneNetwork.dio.get('/galleries'),
///   parser:  (json) => (json as List).map(Gallery.fromJson).toList(),
///   emptyCheck: (list) => list.isEmpty,
///   cache: CacheConfig(
///     policy:   CachePolicy.networkFirst,
///     key:      'galleries',
///     duration: Duration(minutes: 5),
///   ),
/// );
///
/// // 3. Handle states (including new empty state)
/// result.when(
///   idle:         ()        => const SizedBox.shrink(),
///   loading:      ()        => const GalleryShimmer(),
///   success:      (items)   => GalleryGrid(items),
///   empty:        ()        => const EmptyGalleries(),
///   failed:       (error)   => ErrorView(error.message),
///   networkError: (error)   => const NoInternetWidget(),
/// );
///
/// // Or use the UI helper
/// result.buildWidget(
///   loading:  ()        => const GalleryShimmer(),
///   success:  (items)   => GalleryGrid(items),
///   empty:    ()        => const EmptyGalleries(),
///   error:    (msg)     => ErrorView(msg, onRetry: _reload),
/// );
///
/// // 4. Upload with progress
/// ApiExecutor.uploadStream<Photo, ApiError>(
///   request: (onSendProgress) => KeystoneNetwork.dio.post(
///     '/photos',
///     data: formData,
///     onSendProgress: onSendProgress,
///   ),
///   parser: Photo.fromJson,
/// ).listen((state) {
///   state.when(
///     uploading:    (p)     => updateProgressBar(p),
///     processing:   ()      => showSpinner(),
///     success:      (photo) => onDone(photo),
///     failed:       (e)     => showError(e.message),
///     networkError: ()      => showNoInternet(),
///     idle:         ()      => {},
///   );
/// });
///
/// // 5. Pagination
/// final paginator = ApiPaginator<Gallery, ApiError>(
///   request: (page) => KeystoneNetwork.dio.get('/galleries',
///     queryParameters: {'page': page}),
///   parser:  Gallery.fromJson,
///   pageSize: 20,
/// );
/// await paginator.loadFirst();
///
/// // 6. Type-safe errors
/// result.when(
///   failed: (error) => switch (error.errorData) {
///     ValidationError(:final fields) => showFieldErrors(fields),
///     UnauthorizedError()            => redirectToLogin(),
///     ServerError(:final statusCode) => showServerError(statusCode),
///     _                              => showGenericError(),
///   },
///   ...
/// );
/// ```

// Core exports
export 'core/api_executor.dart';
export 'core/api_error.dart';
export 'core/upload_state.dart';
export 'core/api_paginator.dart';
export 'core/api_cache.dart';
export 'core/failure_response.dart';
export 'core/response_code.dart';
export 'core/response_message.dart';
export 'core/error_handler.dart';
export 'core/dio_provider.dart';

// Flutter widget exports
export 'widgets/paginated_list_view.dart';
export 'widgets/api_state_widget.dart';   // re-exported from api_state_widget.dart

// Configuration exports
export 'config/environment_config.dart';

// Interceptor exports
export 'interceptors/auth_interceptor.dart';
export 'interceptors/logging_interceptor.dart';
export 'interceptors/retry_interceptor.dart';
export 'interceptors/token_manager.dart';

// Re-export commonly used Dio types
export 'package:dio/dio.dart'
    show
    Dio,
    Response,
    RequestOptions,
    Options,
    CancelToken,
    ResponseType,
    DioException,
    DioExceptionType,
    Interceptor,
    RequestInterceptorHandler,
    ResponseInterceptorHandler,
    ErrorInterceptorHandler,
    FormData,
    MultipartFile;