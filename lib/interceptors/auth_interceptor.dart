import 'package:dio/dio.dart';
import '../core/dio_provider.dart';
import 'token_manager.dart';

/// Authentication interceptor with automatic token refresh
///
/// Features:
/// - Automatic token injection
/// - Token refresh on 401 errors
/// - Request queuing during refresh
/// - Race condition prevention
/// - Configurable token format
///
/// Example:
/// ```dart
/// final authInterceptor = AuthInterceptor(
///   tokenManager: myTokenManager,
///   dioProvider: NetworkKit.dioProvider,
/// );
///
/// NetworkKit.initialize(
///   baseUrl: 'https://api.example.com',
///   interceptors: [authInterceptor],
/// );
///
/// // Now all requests automatically include auth token
/// // and will refresh on 401 errors
/// ```
class AuthInterceptor extends Interceptor {
  /// Token manager for accessing and refreshing tokens
  final TokenManager tokenManager;

  /// DioProvider for making retry requests
  /// Use NetworkKit.dioProvider or create your own
  final DioProvider dioProvider;

  /// Header key for authorization (default: 'Authorization')
  final String authHeaderKey;

  /// Function to format the token (default: 'Bearer {token}')
  final String Function(String token) tokenFormatter;

  /// Function to determine if token should be refreshed based on status code
  /// Default: refresh on 401 status code
  final bool Function(int? statusCode)? shouldRefreshToken;

  // Prevent multiple simultaneous refresh attempts
  bool _isRefreshing = false;
  final List<_RequestQueueItem> _requestQueue = [];

  AuthInterceptor({
    required this.tokenManager,
    required this.dioProvider,
    this.authHeaderKey = 'Authorization',
    this.tokenFormatter = _defaultTokenFormatter,
    this.shouldRefreshToken,
  });

  static String _defaultTokenFormatter(String token) => 'Bearer $token';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for certain endpoints
    // Usage: dio.get('/public', options: Options(extra: {'skipAuth': true}))
    if (options.extra['skipAuth'] == true) {
      return handler.next(options);
    }

    // Get and add token
    final token = await tokenManager.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers[authHeaderKey] = tokenFormatter(token);
    }

    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Check if we should refresh token
    final shouldRefresh = shouldRefreshToken?.call(err.response?.statusCode) ??
        err.response?.statusCode == 401;

    if (!shouldRefresh) {
      return handler.next(err);
    }

    // If already refreshing, queue this request
    if (_isRefreshing) {
      _queueRequest(err.requestOptions, handler);
      return;
    }

    // Start refresh process
    _isRefreshing = true;

    try {
      // Attempt to refresh token
      final refreshed = await tokenManager.refreshToken();

      if (refreshed) {
        // Refresh succeeded - retry original request
        _isRefreshing = false;

        // Retry queued requests first
        await _retryQueuedRequests();

        // Retry the failed request
        final response = await _retryRequest(err.requestOptions);
        return handler.resolve(response);
      } else {
        // Refresh failed - clear tokens and fail all requests
        _isRefreshing = false;
        await tokenManager.clearTokens();
        _failQueuedRequests(err);
        return handler.next(err);
      }
    } catch (e) {
      // Refresh threw an error - fail all requests
      _isRefreshing = false;
      _failQueuedRequests(err);
      return handler.next(err);
    }
  }

  /// Queue a request to be retried after token refresh
  void _queueRequest(
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) {
    _requestQueue.add(_RequestQueueItem(options, handler));
  }

  /// Retry all queued requests after successful token refresh
  Future<void> _retryQueuedRequests() async {
    final queue = List<_RequestQueueItem>.from(_requestQueue);
    _requestQueue.clear();

    for (final item in queue) {
      try {
        final response = await _retryRequest(item.options);
        item.handler.resolve(response);
      } catch (e) {
        item.handler.reject(
          DioException(
            requestOptions: item.options,
            error: e,
          ),
        );
      }
    }
  }

  /// Fail all queued requests with the same error
  void _failQueuedRequests(DioException error) {
    final queue = List<_RequestQueueItem>.from(_requestQueue);
    _requestQueue.clear();

    for (final item in queue) {
      item.handler.reject(error);
    }
  }

  /// Retry a request with fresh token
  Future<Response> _retryRequest(RequestOptions options) async {
    // Get fresh token
    final token = await tokenManager.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers[authHeaderKey] = tokenFormatter(token);
    }

    // Use DioProvider to maintain interceptors and configuration
    return dioProvider.dio.fetch(options);
  }
}

/// Internal class to hold queued request information
class _RequestQueueItem {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;

  _RequestQueueItem(this.options, this.handler);
}
