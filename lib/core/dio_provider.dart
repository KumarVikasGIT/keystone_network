import 'package:dio/dio.dart';

/// Provides access to the configured Dio instance
///
/// This prevents interceptors from losing configuration when they need
/// to retry requests. Instead of creating new Dio instances, interceptors
/// should use the injected provider to access the configured instance.
///
/// Example:
/// ```dart
/// class MyInterceptor extends Interceptor {
///   final DioProvider dioProvider;
///
///   MyInterceptor(this.dioProvider);
///
///   Future<Response> retry(RequestOptions options) {
///     return dioProvider.dio.fetch(options); // ✅ Keeps all interceptors
///   }
/// }
/// ```
abstract class DioProvider {
  /// Get the configured Dio instance
  Dio get dio;
}

/// Default implementation of DioProvider
class DefaultDioProvider implements DioProvider {
  @override
  final Dio dio;

  /// Create a provider with a Dio instance
  const DefaultDioProvider(this.dio);
}
