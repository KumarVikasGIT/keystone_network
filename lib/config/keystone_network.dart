import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../core/dio_provider.dart';

/// Main KeystoneNetwork configuration class
/// 
/// This is OPTIONAL - developers can still use Dio directly.
/// KeystoneNetwork provides a convenient way to configure and manage Dio instances.
/// 
/// Features:
/// - Simple initialization
/// - Pre-configured defaults
/// - Interceptor management
/// - Multiple instance support
/// - DioProvider integration for interceptors
/// 
/// Example:
/// ```dart
/// // Initialize once in main()
/// KeystoneNetwork.initialize(
///   baseUrl: 'https://api.example.com',
///   interceptors: [
///     AuthInterceptor(
///       tokenManager: myTokenManager,
///       dioProvider: KeystoneNetwork.dioProvider,
///     ),
///     LoggingInterceptor(),
///   ],
/// );
/// 
/// // Use anywhere in your app
/// final response = await KeystoneNetwork.dio.get('/users');
/// 
/// // Or with ApiExecutor
/// final result = await ApiExecutor.execute<User, dynamic>(
///   request: () => KeystoneNetwork.dio.get('/user/me'),
///   parser: (json) => User.fromJson(json),
/// );
/// ```
class KeystoneNetwork {
  static Dio? _dio;
  static DioProvider? _dioProvider;

  /// Get the configured Dio instance
  static Dio get dio {
    if (_dio == null) {
      throw StateError(
        'KeystoneNetwork not initialized. Call KeystoneNetwork.initialize() first.',
      );
    }
    return _dio!;
  }

  /// Get the DioProvider for use with interceptors
  /// 
  /// Pass this to interceptors that need to retry requests:
  /// ```dart
  /// AuthInterceptor(
  ///   tokenManager: myTokenManager,
  ///   dioProvider: KeystoneNetwork.dioProvider,
  /// )
  /// ```

  static DioProvider get dioProvider {
    if (_dioProvider == null) {
      throw StateError(
        'KeystoneNetwork not initialized. Call KeystoneNetwork.initialize() first.',
      );
    }
    return _dioProvider!;
  }

  /// Initialize KeystoneNetwork with configuration
  /// 
  /// This should be called once during app startup, typically in main().
  /// 
  /// Parameters:
  /// - [baseUrl]: Base URL for all requests (optional)
  /// - [connectTimeout]: Connection timeout duration
  /// - [receiveTimeout]: Response receive timeout duration
  /// - [sendTimeout]: Request send timeout duration
  /// - [headers]: Default headers for all requests
  /// - [interceptors]: List of Dio interceptors
  /// - [responseType]: Default response type (json, plain, bytes, stream)
  /// - [validateStatus]: Custom status code validation
  /// 
  /// Example:
  /// ```dart
  /// KeystoneNetwork.initialize(
  ///   baseUrl: 'https://api.example.com',
  ///   connectTimeout: Duration(seconds: 30),
  ///   headers: {
  ///     'Accept': 'application/json',
  ///     'X-App-Version': '1.0.0',
  ///   },
  ///   interceptors: [
  ///     AuthInterceptor(
  ///       tokenManager: myTokenManager,
  ///       dioProvider: KeystoneNetwork.dioProvider,
  ///     ),
  ///     LoggingInterceptor(),
  ///   ],
  /// );
  /// ```
  static void initialize({
    String? baseUrl,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration sendTimeout = const Duration(seconds: 30),
    Map<String, dynamic>? headers,
    List<Interceptor> interceptors = const [],
    ResponseType responseType = ResponseType.json,
    bool Function(int?)? validateStatus,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        },
        responseType: responseType,
        validateStatus: validateStatus ?? _defaultValidateStatus,
      ),
    );

    // Create DioProvider for interceptors
    _dioProvider = DefaultDioProvider(_dio!);

    // Add interceptors
    if (interceptors.isNotEmpty) {
      _dio!.interceptors.addAll(interceptors);
    }
  }

  /// Default status code validation
  /// 
  /// Considers 2xx status codes as successful
  static bool _defaultValidateStatus(int? status) {
    return status != null && status >= 200 && status < 300;
  }

  /// Create a new Dio instance for multiple API endpoints
  /// 
  /// Use this when you need to communicate with multiple different APIs
  /// with different configurations.
  /// 
  /// Example:
  /// ```dart
  /// final paymentApi = KeystoneNetwork.createInstance(
  ///   baseUrl: 'https://payment-api.example.com',
  ///   headers: {'X-Payment-Key': 'xxx'},
  ///   interceptors: [
  ///     PaymentAuthInterceptor(),
  ///   ],
  /// );
  /// 
  /// final analyticsApi = KeystoneNetwork.createInstance(
  ///   baseUrl: 'https://analytics-api.example.com',
  ///   headers: {'X-Analytics-Key': 'yyy'},
  /// );
  /// ```
  static Dio createInstance({
    required String baseUrl,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration sendTimeout = const Duration(seconds: 30),
    Map<String, dynamic>? headers,
    List<Interceptor> interceptors = const [],
    ResponseType responseType = ResponseType.json,
    bool Function(int?)? validateStatus,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        },
        responseType: responseType,
        validateStatus: validateStatus ?? _defaultValidateStatus,
      ),
    );

    // Add interceptors
    if (interceptors.isNotEmpty) {
      dio.interceptors.addAll(interceptors);
    }

    return dio;
  }

  /// Create a DioProvider for a custom Dio instance
  /// 
  /// Use this when you need a DioProvider for a Dio instance
  /// that wasn't created through KeystoneNetwork.
  /// 
  /// Example:
  /// ```dart
  /// final customDio = Dio(BaseOptions(...));
  /// final provider = KeystoneNetwork.createDioProvider(customDio);
  /// 
  /// final interceptor = AuthInterceptor(
  ///   tokenManager: myTokenManager,
  ///   dioProvider: provider,
  /// );
  /// ```
  static DioProvider createDioProvider(Dio dio) {
    return DefaultDioProvider(dio);
  }

  /// Reset KeystoneNetwork (for testing purposes only)
  ///
  /// **WARNING:** This will close the current Dio instance and clear all state.
  /// Only use this in test tearDown methods.
  ///
  /// Example:
  /// ```dart
  /// tearDown(() {
  ///   KeystoneNetwork.reset();
  /// });
  /// ```
  @visibleForTesting
  static void reset() {
    // Safely close existing Dio instance
    if (_dio != null) {
      try {
        _dio!.close(force: true);
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    // Reset to null (not creating new instance)
    _dio = null;
    _dioProvider = null;
  }
}