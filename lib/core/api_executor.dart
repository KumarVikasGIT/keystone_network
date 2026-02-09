import 'package:dio/dio.dart';
import 'api_state.dart';
import 'error_handler.dart';
import 'failure_response.dart';

/// Generic API executor that handles all network requests
/// 
/// Type Parameters:
///   T - Success response type
///   E - Custom error type (optional)
/// 
/// Features:
/// - Automatic error handling
/// - Type-safe success and error parsing
/// - Stream-based loading state management
/// - Network error detection
/// - Cancel token support
/// 
/// Example:
/// ```dart
/// // Simple usage
/// final result = await ApiExecutor.execute<User, dynamic>(
///   request: () => dio.get('/user/me'),
///   parser: (json) => User.fromJson(json),
/// );
/// 
/// // With custom error type
/// final result = await ApiExecutor.execute<User, LoginError>(
///   request: () => dio.post('/login', data: {...}),
///   parser: (json) => User.fromJson(json['user']),
///   errorParser: (json) => LoginError.fromJson(json),
/// );
/// 
/// // As stream for loading state
/// ApiExecutor.executeAsStateStream<List<User>, dynamic>(
///   request: () => dio.get('/users'),
///   parser: (json) => (json as List).map((e) => User.fromJson(e)).toList(),
/// ).listen((state) {
///   state.when(
///     idle: () => {},
///     loading: () => showLoader(),
///     success: (users) => displayUsers(users),
///     failed: (error) => showError(error.message),
///     networkError: (error) => showNoInternet(),
///   );
/// });
/// ```
class ApiExecutor {
  /// Execute a network request as a state stream (emits loading → success/error)
  /// 
  /// This is the recommended method when you want automatic loading state management.
  /// The stream will emit:
  /// 1. Loading state immediately
  /// 2. Success or Error state when request completes
  /// 
  /// Returns a Stream that emits ApiState updates
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

  /// Execute a network request as a state stream (emits loading → success/error)
  /// 
  /// Deprecated: Use executeAsStateStream instead for clearer naming
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
  /// Use this when you manage loading state yourself or when you don't need
  /// the intermediate loading state.
  /// 
  /// Returns the final ApiState (success, failed, or networkError)
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