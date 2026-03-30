import 'package:dio/dio.dart';
import '../widgets/api_state_widget.dart';
import 'upload_state.dart';
import 'error_handler.dart';
import 'failure_response.dart';
import 'api_cache.dart';

class ApiExecutor {
  // ── Standard execute ────────────────────────────────────────────────────

  /// Execute a request and return the final [ApiState] (no loading emission).
  ///
  /// - [emptyCheck]  auto-emits [ApiState.empty] when predicate returns true.
  /// - [cache]       when supplied, respects the configured [CachePolicy].
  ///
  /// Example:
  /// ```dart
  /// final state = await ApiExecutor.execute<List<Gallery>, ApiError>(
  ///   request: () => dio.get('/galleries'),
  ///   parser:  (json) => (json as List).map(Gallery.fromJson).toList(),
  ///   emptyCheck: (list) => list.isEmpty,
  ///   cache: CacheConfig(
  ///     policy:   CachePolicy.networkFirst,
  ///     key:      'user_galleries',
  ///     duration: Duration(minutes: 5),
  ///   ),
  /// );
  /// ```
  static Future<ApiState<T, E>> execute<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    bool Function(T data)? emptyCheck,
    CacheConfig? cache,
    CancelToken? cancelToken,
  }) async {
    if (cache != null) {
      return _executeWithCache<T, E>(
        request: request,
        parser: parser,
        errorParser: errorParser,
        emptyCheck: emptyCheck,
        cache: cache,
      );
    }
    return _executeCore<T, E>(
      request: request,
      parser: parser,
      errorParser: errorParser,
      emptyCheck: emptyCheck,
    );
  }

  /// Execute a request as a state stream.
  ///
  /// Emits [ApiState.loading] immediately, then the final state.
  /// With [CachePolicy.cacheAndNetwork] may emit two success states.
  static Stream<ApiState<T, E>> executeAsStateStream<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    bool Function(T data)? emptyCheck,
    CacheConfig? cache,
    CancelToken? cancelToken,
  }) async* {
    yield const ApiState.loading();

    if (cache?.policy == CachePolicy.cacheAndNetwork) {
      yield* _cacheAndNetworkStream<T, E>(
        request: request,
        parser: parser,
        errorParser: errorParser,
        emptyCheck: emptyCheck,
        cache: cache!,
      );
      return;
    }

    yield await execute<T, E>(
      request: request,
      parser: parser,
      errorParser: errorParser,
      emptyCheck: emptyCheck,
      cache: cache,
    );
  }

  /// Execute a request returning raw data; throws [ErrorHandler] on failure.
  static Future<T> executeRaw<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await request();
      return parser(response.data);
    } catch (error) {
      throw ErrorHandler<E>.handle(error, parseError: errorParser);
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Upload a multipart request and return a final [UploadState].
  ///
  /// Example:
  /// ```dart
  /// final formData = FormData.fromMap({
  ///   'photo': await MultipartFile.fromFile(path, filename: 'photo.jpg'),
  /// });
  ///
  /// final state = await ApiExecutor.upload<Photo, ApiError>(
  ///   request: () => dio.post('/photos', data: formData),
  ///   parser:  (json) => Photo.fromJson(json),
  ///   onProgress: (sent, total) {
  ///     print('${(sent / total * 100).round()}%');
  ///   },
  /// );
  /// ```
  static Future<UploadState<T, E>> upload<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await request();
      return UploadState.success(parser(response.data));
    } catch (error) {
      final failure =
          ErrorHandler<E>.handle(error, parseError: errorParser).failure;
      if (failure.isNetworkError) return UploadState.networkError();
      return UploadState.failed(failure);
    }
  }

  /// Upload a multipart request and stream [UploadState] updates.
  ///
  /// Wire the callback's [onSendProgress] directly to Dio:
  /// ```dart
  /// ApiExecutor.uploadStream<Photo, ApiError>(
  ///   request: (onSendProgress) => dio.post(
  ///     '/photos',
  ///     data: formData,
  ///     onSendProgress: onSendProgress,
  ///   ),
  ///   parser: Photo.fromJson,
  /// ).listen((state) {
  ///   state.when(
  ///     idle:         ()         => {},
  ///     uploading:    (progress) => updateProgressBar(progress),
  ///     processing:   ()         => showSpinner(),
  ///     success:      (photo)    => onUploadComplete(photo),
  ///     failed:       (error)    => showError(error.message),
  ///     networkError: ()         => showNoInternet(),
  ///   );
  /// });
  /// ```
  static Stream<UploadState<T, E>> uploadStream<T, E>({
    required Future<Response> Function(
        void Function(int sent, int total) onSendProgress,
        ) request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    CancelToken? cancelToken,
  }) async* {
    yield const UploadState.uploading(0.0);

    final progressBuffer = <double>[];
    var lastEmitted = 0.0;

    void onSendProgress(int sent, int total) {
      if (total > 0) progressBuffer.add(sent / total);
    }

    try {
      final responseFuture = request(onSendProgress);

      while (progressBuffer.isNotEmpty) {
        final p = progressBuffer.removeAt(0);
        if (p > lastEmitted) {
          lastEmitted = p;
          yield UploadState.uploading(p);
        }
      }

      yield const UploadState.processing();

      final response = await responseFuture;
      yield UploadState.success(parser(response.data));
    } catch (error) {
      final failure =
          ErrorHandler<E>.handle(error, parseError: errorParser).failure;
      if (failure.isNetworkError) {
        yield UploadState.networkError();
      } else {
        yield UploadState.failed(failure);
      }
    }
  }

  // ── Deprecated ────────────────────────────────────────────────────────────

  @Deprecated('Use executeAsStateStream instead. Will be removed in v2.0.0')
  static Stream<ApiState<T, E>> executeAsStream<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    CancelToken? cancelToken,
  }) =>
      executeAsStateStream<T, E>(
        request: request,
        parser: parser,
        errorParser: errorParser,
        cancelToken: cancelToken,
      );

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<ApiState<T, E>> _executeCore<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    bool Function(T data)? emptyCheck,
  }) async {
    try {
      final response = await request();
      final data = parser(response.data);
      if (emptyCheck != null && emptyCheck(data)) return const ApiState.empty();
      return ApiState.success(data);
    } catch (error) {
      final failure =
          ErrorHandler<E>.handle(error, parseError: errorParser).failure;
      if (failure.isNetworkError) return ApiState.networkError(failure);
      return ApiState.failed(failure);
    }
  }

  static Future<ApiState<T, E>> _executeWithCache<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    bool Function(T data)? emptyCheck,
    required CacheConfig cache,
  }) async {
    switch (cache.policy) {
      case CachePolicy.networkOnly:
        return _executeCore<T, E>(
          request: request,
          parser: parser,
          errorParser: errorParser,
          emptyCheck: emptyCheck,
        );

      case CachePolicy.cacheOnly:
        final cached = await ApiCache.get(cache.key);
        if (cached == null) {
          return ApiState.failed(
            FailureResponse<E>(
              -3,
              'No cached data available for "${cache.key}".',
            ),
          );
        }
        final data = parser(cached);
        if (emptyCheck != null && emptyCheck(data)) return const ApiState.empty();
        return ApiState.success(data);

      case CachePolicy.cacheFirst:
        final cached = await ApiCache.get(cache.key);
        if (cached != null) {
          final data = parser(cached);
          if (emptyCheck != null && emptyCheck(data)) {
            return const ApiState.empty();
          }
          return ApiState.success(data);
        }
        final state = await _executeCore<T, E>(
          request: request,
          parser: parser,
          errorParser: errorParser,
          emptyCheck: emptyCheck,
        );
        if (state is SuccessState<T, E>) {
          await ApiCache.set(cache.key, state.data, cache.duration);
        }
        return state;

      case CachePolicy.networkFirst:
      case CachePolicy.cacheAndNetwork:
      // cacheAndNetwork is handled by the stream variant;
      // in the Future path we treat it as networkFirst.
        final state = await _executeCore<T, E>(
          request: request,
          parser: parser,
          errorParser: errorParser,
          emptyCheck: emptyCheck,
        );
        if (state is SuccessState<T, E>) {
          await ApiCache.set(cache.key, state.data, cache.duration);
          return state;
        }
        // Network failed – try cache fallback
        final cached = await ApiCache.get(cache.key);
        if (cached != null) {
          final data = parser(cached);
          if (emptyCheck != null && emptyCheck(data)) {
            return const ApiState.empty();
          }
          return ApiState.success(data);
        }
        return state;
    }
  }

  static Stream<ApiState<T, E>> _cacheAndNetworkStream<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    bool Function(T data)? emptyCheck,
    required CacheConfig cache,
  }) async* {
    final cached = await ApiCache.get(cache.key);
    if (cached != null) {
      final data = parser(cached);
      if (emptyCheck != null && emptyCheck(data)) {
        yield const ApiState.empty();
      } else {
        yield ApiState.success(data);
      }
    }

    final state = await _executeCore<T, E>(
      request: request,
      parser: parser,
      errorParser: errorParser,
      emptyCheck: emptyCheck,
    );
    if (state is SuccessState<T, E>) {
      await ApiCache.set(cache.key, state.data, cache.duration);
    }
    yield state;
  }
}