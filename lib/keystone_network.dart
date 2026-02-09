library keystone_network;

/// Network Kit - Clean, Generic, Minimal Networking Library for Flutter
///
/// A production-ready networking library that provides:
/// - Type-safe API state management
/// - Automatic error handling
/// - Token management with auto-refresh
/// - Smart retry with idempotency protection
/// - Clean logging with sensitive data redaction
/// - Minimal core with optional features
///
/// ## Quick Start
///
/// ```dart
/// // 1. Initialize (optional)
/// NetworkKit.initialize(
///   baseUrl: 'https://api.example.com',
///   interceptors: [
///     AuthInterceptor(
///       tokenManager: myTokenManager,
///       dioProvider: NetworkKit.dioProvider,
///     ),
///     RetryInterceptor(),
///     LoggingInterceptor(level: LogLevel.body),
///   ],
/// );
///
/// // 2. Make requests
/// final result = await ApiExecutor.execute<User, dynamic>(
///   request: () => NetworkKit.dio.get('/user/me'),
///   parser: (json) => User.fromJson(json),
/// );
///
/// // 3. Handle states
/// result.when(
///   idle: () => Text('Ready'),
///   loading: () => CircularProgressIndicator(),
///   success: (user) => UserProfile(user),
///   failed: (error) => ErrorWidget(error.message),
///   networkError: (error) => NoInternetWidget(),
/// );
/// ```

// Core exports
export 'core/api_state.dart';
export 'core/api_executor.dart';
export 'core/failure_response.dart';
export 'core/response_code.dart';
export 'core/response_message.dart';
export 'core/error_handler.dart';
export 'core/dio_provider.dart';

// Configuration exports
export 'config/environment_config.dart';

// Interceptor exports
export 'interceptors/auth_interceptor.dart';
export 'interceptors/logging_interceptor.dart';
export 'interceptors/retry_interceptor.dart';
export 'interceptors/token_manager.dart';

// Re-export commonly used Dio types for convenience
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
    ErrorInterceptorHandler;
