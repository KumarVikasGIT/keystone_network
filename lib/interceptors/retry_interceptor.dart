import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../core/dio_provider.dart';

/// Retry policy configuration
///
/// Example:
/// ```dart
/// const RetryConfig(
///   maxAttempts: 3,
///   initialDelay: Duration(seconds: 1),
///   maxDelay: Duration(seconds: 30),
///   multiplier: 2.0,
///   shouldRetry: myCustomRetryLogic,
/// )
/// ```
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Initial delay before first retry
  final Duration initialDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Exponential backoff multiplier
  final double multiplier;

  /// Custom function to determine if request should be retried
  /// If null, uses default retry logic
  final bool Function(DioException)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.shouldRetry,
  });
}

/// Smart retry interceptor with exponential backoff and idempotency guard
///
/// Features:
/// - Exponential backoff with configurable delays
/// - Idempotency protection (prevents retrying non-idempotent methods by default)
/// - Configurable retry conditions
/// - Request-level retry override
/// - Automatic retry count tracking
///
/// Safety:
/// - GET, HEAD, PUT, DELETE, OPTIONS, TRACE are retried by default
/// - POST, PATCH require explicit opt-in via extra['allowRetry'] = true
///
/// **IMPORTANT:** Requires DioProvider injection to maintain interceptors
///
/// Example:
/// ```dart
/// // Default configuration
/// final retryInterceptor = RetryInterceptor();
///
/// // Custom configuration
/// final retryInterceptor = RetryInterceptor(
///   dioProvider: KeystoneNetwork.dioProvider, // ✅ Pass provider
///   config: RetryConfig(maxAttempts: 5),
/// );
///
/// KeystoneNetwork.initialize(
///   baseUrl: 'https://api.example.com',
///   interceptors: [retryInterceptor],
/// );
/// ```
class RetryInterceptor extends Interceptor {
  final RetryConfig config;
  final DioProvider dioProvider;

  RetryInterceptor({
    RetryConfig? config,
    required this.dioProvider, // ✅ Now required
  }) : config = config ?? const RetryConfig();

  @override
  void onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {
    // Check if should retry
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    // Get current retry count
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    // Check if max attempts reached
    if (retryCount >= config.maxAttempts) {
      return handler.next(err);
    }

    // Calculate delay with exponential backoff
    final delay = _calculateDelay(retryCount);

    // Log retry attempt (if you have a logger)
    _logRetry(err, retryCount, delay);

    // Wait before retry
    await Future.delayed(delay);

    // Increment retry count
    err.requestOptions.extra['retryCount'] = retryCount + 1;

    // Retry the request using DioProvider (maintains all interceptors!)
    try {
      final response = await dioProvider.dio.fetch(err.requestOptions); // ✅ Fixed!
      return handler.resolve(response);
    } on DioException catch (e) {
      // If retry fails, it will go through onError again
      // and either retry again or give up based on the new error
      return handler.next(e);
    } catch (e) {
      return handler.next(err);
    }
  }

  /// Determine if the request should be retried
  bool _shouldRetry(DioException err) {
    // Check idempotency first (safety guard)
    if (!_isIdempotent(err.requestOptions)) {
      // Only retry non-idempotent methods if explicitly allowed
      if (err.requestOptions.extra['allowRetry'] != true) {
        return false;
      }
    }

    // Use custom logic if provided
    if (config.shouldRetry != null) {
      return config.shouldRetry!(err);
    }

    // Default retry logic: retry on network errors or 5xx server errors
    return _isRetryableError(err);
  }

  /// Check if the error is retryable by default
  bool _isRetryableError(DioException err) {
    // Network-related errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Server errors (5xx)
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }

    // Don't retry client errors (4xx) or other errors
    return false;
  }

  /// Check if HTTP method is idempotent (safe to retry)
  ///
  /// Idempotent methods:
  /// - GET: Safe, read-only
  /// - HEAD: Safe, read-only
  /// - PUT: Idempotent by HTTP spec (same request = same result)
  /// - DELETE: Idempotent by HTTP spec (deleting same resource multiple times)
  /// - OPTIONS: Safe, metadata only
  /// - TRACE: Safe, diagnostic only
  ///
  /// Non-idempotent methods (require explicit opt-in):
  /// - POST: Not idempotent (creates new resources, can cause duplicates)
  /// - PATCH: Not guaranteed idempotent (partial updates can compound)
  bool _isIdempotent(RequestOptions options) {
    final method = options.method.toUpperCase();
    return method == 'GET' ||
        method == 'HEAD' ||
        method == 'PUT' ||
        method == 'DELETE' ||
        method == 'OPTIONS' ||
        method == 'TRACE';
  }

  /// Calculate delay for retry with exponential backoff
  Duration _calculateDelay(int retryCount) {
    // Calculate exponential delay: initialDelay * (multiplier ^ retryCount)
    final delayMs = config.initialDelay.inMilliseconds *
        math.pow(config.multiplier, retryCount);

    final delay = Duration(milliseconds: delayMs.toInt());

    // Cap at max delay
    return delay > config.maxDelay ? config.maxDelay : delay;
  }

  /// Log retry attempt (optional, can be customized)
  void _logRetry(DioException err, int retryCount, Duration delay) {
    print(
      'Retrying ${err.requestOptions.method} ${err.requestOptions.uri} '
      '(attempt ${retryCount + 1}/${config.maxAttempts}) '
      'after ${delay.inMilliseconds}ms delay',
    );
  }
}