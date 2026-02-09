import 'package:dio/dio.dart';
import '../core/dio_provider.dart';

/// Main NetworkKit configuration class
/// 
/// This is OPTIONAL - developers can still use Dio directly.
/// NetworkKit provides a convenient way to configure and manage Dio instances.
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
/// NetworkKit.initialize(
///   baseUrl: 'https://api.example.com',
///   interceptors: [
///     AuthInterceptor(
///       tokenManager: myTokenManager,
///       dioProvider: NetworkKit.dioProvider,
///     ),
///     LoggingInterceptor(),
///   ],
/// );
/// 
/// // Use anywhere in your app
/// final response = await NetworkKit.dio.get('/users');
/// 
/// // Or with ApiExecutor
/// final result = await ApiExecutor.execute<User, dynamic>(
///   request: () => NetworkKit.dio.get('/user/me'),
///   parser: (json) => User.fromJson(json),
/// );
/// ```
class NetworkKit {
  static late Dio _dio;
  static late DioProvider _dioProvider;

  /// Get the configured Dio instance
  static Dio get dio => _dio;

  /// Get the DioProvider for use with interceptors
  /// 
  /// Pass this to interceptors that need to retry requests:
  /// ```dart
  /// AuthInterceptor(
  ///   tokenManager: myTokenManager,
  ///   dioProvider: NetworkKit.dioProvider,
  /// )
  /// ```
  static DioProvider get dioProvider => _dioProvider;

  /// Initialize NetworkKit with configuration
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
  /// NetworkKit.initialize(
  ///   baseUrl: 'https://api.example.com',
  ///   connectTimeout: Duration(seconds: 30),
  ///   headers: {
  ///     'Accept': 'application/json',
  ///     'X-App-Version': '1.0.0',
  ///   },
  ///   interceptors: [
  ///     AuthInterceptor(
  ///       tokenManager: myTokenManager,
  ///       dioProvider: NetworkKit.dioProvider,
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
    _dioProvider = DefaultDioProvider(_dio);

    // Add interceptors
    if (interceptors.isNotEmpty) {
      _dio.interceptors.addAll(interceptors);
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
  /// final paymentApi = NetworkKit.createInstance(
  ///   baseUrl: 'https://payment-api.example.com',
  ///   headers: {'X-Payment-Key': 'xxx'},
  ///   interceptors: [
  ///     PaymentAuthInterceptor(),
  ///   ],
  /// );
  /// 
  /// final analyticsApi = NetworkKit.createInstance(
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
  /// that wasn't created through NetworkKit.
  /// 
  /// Example:
  /// ```dart
  /// final customDio = Dio(BaseOptions(...));
  /// final provider = NetworkKit.createDioProvider(customDio);
  /// 
  /// final interceptor = AuthInterceptor(
  ///   tokenManager: myTokenManager,
  ///   dioProvider: provider,
  /// );
  /// ```
  static DioProvider createDioProvider(Dio dio) {
    return DefaultDioProvider(dio);
  }

  /// Reset NetworkKit (useful for testing)
  /// 
  /// This clears the singleton instance. Only use this in tests.
  static void reset() {
    _dio.close(force: true);
  }
}