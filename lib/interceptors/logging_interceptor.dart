import 'package:dio/dio.dart';

/// Logging levels for controlling output verbosity
enum LogLevel {
  /// No logging
  none,

  /// Basic logging (URL + status code)
  basic,

  /// Basic + headers
  headers,

  /// Basic + headers + request/response bodies
  body;

  bool get isNone => this == LogLevel.none;
  bool get isBasic => index >= LogLevel.basic.index;
  bool get includesHeaders => index >= LogLevel.headers.index;
  bool get includesBody => index >= LogLevel.body.index;
}

/// Clean logging interceptor with redaction support
///
/// Features:
/// - Configurable log levels
/// - Sensitive data redaction
/// - Request ID tracking for distributed debugging
/// - Clean, formatted output
/// - Custom log function support
///
/// Example:
/// ```dart
/// LoggingInterceptor(
///   level: LogLevel.body,
///   redactHeaders: ['authorization', 'cookie', 'x-api-key'],
///   redactFields: ['password', 'token', 'ssn', 'credit_card'],
///   logPrint: (message) => debugPrint(message), // Custom logger
/// );
/// ```
class LoggingInterceptor extends Interceptor {
  /// Logging level
  final LogLevel level;

  /// Headers to redact (case-insensitive)
  final List<String> redactHeaders;

  /// JSON fields to redact (case-insensitive)
  final List<String> redactFields;

  /// Custom log function (defaults to print)
  final void Function(String message)? logPrint;

  LoggingInterceptor({
    this.level = LogLevel.body,
    this.redactHeaders = const [
      'authorization',
      'cookie',
      'x-api-key',
      'api-key',
    ],
    this.redactFields = const [
      'password',
      'token',
      'access_token',
      'refresh_token',
      'ssn',
      'credit_card',
      'cvv',
    ],
    this.logPrint,
  });

  void _log(String message) {
    if (logPrint != null) {
      logPrint!(message);
    } else {
      // ignore: avoid_print
      print(message);
    }
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (level.isNone) return handler.next(options);

    // Generate or use existing request ID for tracking
    final requestId =
        options.extra['requestId'] as String? ?? _generateRequestId();
    options.extra['requestId'] = requestId;

    _log('┌──── Request [$requestId] ────────────────────────────');
    _log('│ ${options.method} ${options.uri}');

    if (level.includesHeaders && options.headers.isNotEmpty) {
      final headers = _redactHeaders(options.headers);
      _log('│ Headers:');
      headers.forEach((key, value) {
        _log('│   $key: $value');
      });
    }

    if (level.includesBody && options.data != null) {
      final data = _redactData(options.data);
      _log('│ Body: $data');
    }

    if (options.queryParameters.isNotEmpty) {
      _log('│ Query Parameters: ${options.queryParameters}');
    }

    _log('└──────────────────────────────────────────────────────');

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    if (level.isNone) return handler.next(response);

    final requestId = response.requestOptions.extra['requestId'] ?? 'unknown';

    _log('┌──── Response [$requestId] ───────────────────────────');
    _log('│ ${response.statusCode} ${response.requestOptions.uri}');

    if (level.includesHeaders && response.headers.map.isNotEmpty) {
      _log('│ Headers:');
      response.headers.map.forEach((key, value) {
        _log('│   $key: ${value.join(', ')}');
      });
    }

    if (level.includesBody && response.data != null) {
      final data = _redactData(response.data);
      _log('│ Body: $data');
    }

    _log('└──────────────────────────────────────────────────────');

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (level.isNone) return handler.next(err);

    final requestId = err.requestOptions.extra['requestId'] ?? 'unknown';

    _log('┌──── Error [$requestId] ──────────────────────────────');
    _log('│ ${err.requestOptions.method} ${err.requestOptions.uri}');
    _log('│ Type: ${err.type.name}');
    _log('│ Message: ${err.message}');

    if (err.response != null) {
      _log('│ Status: ${err.response?.statusCode}');

      if (level.includesBody && err.response?.data != null) {
        final data = _redactData(err.response?.data);
        _log('│ Error Data: $data');
      }
    }

    if (level.includesBody) {
      _log('│ Stack Trace:');
      final stackLines = err.stackTrace.toString().split('\n');
      for (var line in stackLines.take(5)) {
        // Show first 5 lines
        _log('│   $line');
      }
    }

    _log('└──────────────────────────────────────────────────────');

    handler.next(err);
  }

  /// Redact sensitive headers
  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      final lowerKey = key.toLowerCase();
      if (redactHeaders.any((h) => h.toLowerCase() == lowerKey)) {
        return MapEntry(key, '***REDACTED***');
      }
      return MapEntry(key, value);
    });
  }

  /// Redact sensitive data from request/response body
  dynamic _redactData(dynamic data) {
    if (data is Map) {
      return data.map((key, value) {
        final lowerKey = key.toString().toLowerCase();
        if (redactFields.any((f) => f.toLowerCase() == lowerKey)) {
          return MapEntry(key, '***REDACTED***');
        }
        if (value is Map || value is List) {
          return MapEntry(key, _redactData(value));
        }
        return MapEntry(key, value);
      });
    }
    if (data is List) {
      return data.map(_redactData).toList();
    }
    return data;
  }

  /// Generate a unique request ID for tracking
  String _generateRequestId() {
    // Simple implementation using timestamp
    // You can use uuid package for production if needed
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}
