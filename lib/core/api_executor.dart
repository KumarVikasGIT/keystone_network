import 'package:dio/dio.dart';
import 'api_state.dart';
import 'error_handler.dart';
import 'failure_response.dart';

class ApiExecutor {
  /// Execute a network request as a state stream
  ///
  /// **State Emission:**
  /// 1. Emits `loading` state immediately
  /// 2. Emits `success` or `failed/networkError` when request completes
  ///
  /// **Note:** This stream does NOT emit `idle` state.
  /// It begins from `loading` and ends at a final state.
  /// If you need idle state, manage it separately in your UI.
  ///
  /// Example:
  /// ```dart
  /// // In StatefulWidget
  /// ApiState<User, dynamic> _state = ApiState.idle(); // Manual idle
  ///
  /// void loadData() {
  ///   ApiExecutor.executeAsStateStream<User, dynamic>(
  ///     request: () => dio.get('/user'),
  ///     parser: (json) => User.fromJson(json),
  ///   ).listen((state) {
  ///     setState(() => _state = state);
  ///   });
  /// }
  ///
  /// // Stream will emit: loading → success/failed
  /// // Your _state starts as idle, then updates to stream values
  /// ```
  static Stream<ApiState<T, E>> executeAsStateStream<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    CancelToken? cancelToken,
  }) async* {
    // Emit loading state
    yield const ApiState.loading();

    try {
      // Execute request
      final response = await request();

      // Parse success response
      final data = parser(response.data);

      // Emit success state
      yield ApiState.success(data);
    } catch (error) {
      // Handle error with ErrorHandler
      final handler = ErrorHandler<E>.handle(
        error,
        parseError: errorParser,
      );

      final failure = handler.failure;

      // Use extension method for cleaner network error check
      if (failure.isNetworkError) {
        yield ApiState.networkError(failure);
      } else {
        yield ApiState.failed(failure);
      }
    }
  }

  /// Execute a network request as a state stream
  ///
  /// **Deprecated:** Use `executeAsStateStream` for clearer semantics.
  /// The name "executeAsStream" was ambiguous about state emission.
  @Deprecated('Use executeAsStateStream instead. Will be removed in v2.0.0')
  static Stream<ApiState<T, E>> executeAsStream<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    CancelToken? cancelToken,
  }) {
    return executeAsStateStream<T, E>(
      request: request,
      parser: parser,
      errorParser: errorParser,
      cancelToken: cancelToken,
    );
  }

  /// Execute request and return final state (no loading emission)
  ///
  /// Use this when you manage loading state yourself.
  static Future<ApiState<T, E>> execute<T, E>({
    required Future<Response> Function() request,
    required T Function(dynamic json) parser,
    E Function(Map<String, dynamic> json)? errorParser,
    CancelToken? cancelToken,
  }) async {
    try {
      // Execute request
      final response = await request();

      // Parse success response
      final data = parser(response.data);

      return ApiState.success(data);
    } catch (error) {
      // Handle error with ErrorHandler
      final handler = ErrorHandler<E>.handle(
        error,
        parseError: errorParser,
      );

      final failure = handler.failure;

      // Use extension method for cleaner network error check
      if (failure.isNetworkError) {
        return ApiState.networkError(failure);
      }

      return ApiState.failed(failure);
    }
  }

  /// Execute a request without state wrapping (returns raw data or throws)
  /// 
  /// Use this when you need the raw data and want to handle errors yourself.
  /// This is useful for scenarios where you're composing multiple requests
  /// or need more control over error handling.
  /// 
  /// Throws ErrorHandler on failure
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
}