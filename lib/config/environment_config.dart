/// Environment enumeration for different deployment stages
///
/// Example:
/// ```dart
/// const environment = Environment.production;
///
/// if (environment.isDevelopment) {
///   print('Debug mode enabled');
/// }
/// ```
enum Environment {
  development,
  staging,
  production;

  /// Check if current environment is development
  bool get isDevelopment => this == Environment.development;

  /// Check if current environment is staging
  bool get isStaging => this == Environment.staging;

  /// Check if current environment is production
  bool get isProduction => this == Environment.production;

  /// Get a user-friendly name
  String get displayName => switch (this) {
        Environment.development => 'Development',
        Environment.staging => 'Staging',
        Environment.production => 'Production',
      };
}

/// Generic environment configuration
///
/// Developers can extend this for their specific needs.
///
/// Example:
/// ```dart
/// class MyConfig extends EnvironmentConfig {
///   @override
///   final Environment environment;
///
///   const MyConfig(this.environment);
///
///   @override
///   String get baseUrl {
///     return switch (environment) {
///       Environment.development => 'https://dev-api.example.com',
///       Environment.staging => 'https://staging-api.example.com',
///       Environment.production => 'https://api.example.com',
///     };
///   }
///
///   @override
///   Map<String, dynamic> get headers => {
///     'X-App-Version': '1.0.0',
///     'X-Environment': environment.name,
///   };
/// }
///
/// // Usage
/// const config = MyConfig(Environment.production);
///
/// KeystoneNetwork.initialize(
///   baseUrl: config.baseUrl,
///   connectTimeout: config.connectTimeout,
///   headers: config.headers,
/// );
/// ```
abstract class EnvironmentConfig {
  /// Current environment
  Environment get environment;

  /// Base URL for API requests
  String get baseUrl;

  /// Connection timeout duration
  Duration get connectTimeout => const Duration(seconds: 30);

  /// Response receive timeout duration
  Duration get receiveTimeout => const Duration(seconds: 30);

  /// Request send timeout duration
  Duration get sendTimeout => const Duration(seconds: 30);

  /// Default headers for all requests
  Map<String, dynamic> get headers => {};

  /// Enable debug logging
  bool get enableLogging => environment.isDevelopment;
}

/// Default implementation of EnvironmentConfig
///
/// Use this for simple cases where you just need basic configuration.
///
/// Example:
/// ```dart
/// final config = DefaultEnvironmentConfig(
///   environment: Environment.production,
///   baseUrl: 'https://api.example.com',
///   headers: {'X-API-Key': 'xxx'},
/// );
///
/// KeystoneNetwork.initialize(
///   baseUrl: config.baseUrl,
///   connectTimeout: config.connectTimeout,
///   headers: config.headers,
/// );
/// ```
class DefaultEnvironmentConfig implements EnvironmentConfig {
  @override
  final Environment environment;

  @override
  final String baseUrl;

  final Duration? _connectTimeout;
  final Duration? _receiveTimeout;
  final Duration? _sendTimeout;
  final Map<String, dynamic>? _headers;
  final bool? _enableLogging;

  const DefaultEnvironmentConfig({
    required this.environment,
    required this.baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, dynamic>? headers,
    bool? enableLogging,
  })  : _connectTimeout = connectTimeout,
        _receiveTimeout = receiveTimeout,
        _sendTimeout = sendTimeout,
        _headers = headers,
        _enableLogging = enableLogging;

  @override
  Duration get connectTimeout => _connectTimeout ?? const Duration(seconds: 30);

  @override
  Duration get receiveTimeout => _receiveTimeout ?? const Duration(seconds: 30);

  @override
  Duration get sendTimeout => _sendTimeout ?? const Duration(seconds: 30);

  @override
  Map<String, dynamic> get headers => _headers ?? {};

  @override
  bool get enableLogging => _enableLogging ?? environment.isDevelopment;
}

/// Multi-environment configuration helper
///
/// Use this when you want to define all environments in one place.
///
/// Example:
/// ```dart
/// class AppConfig extends MultiEnvironmentConfig {
///   const AppConfig(super.environment);
///
///   @override
///   String getBaseUrl(Environment env) {
///     return switch (env) {
///       Environment.development => 'https://dev-api.example.com',
///       Environment.staging => 'https://staging-api.example.com',
///       Environment.production => 'https://api.example.com',
///     };
///   }
///
///   @override
///   Map<String, dynamic> getHeaders(Environment env) {
///     return {
///       'X-App-Version': '1.0.0',
///       'X-Environment': env.name,
///     };
///   }
/// }
///
/// // Usage
/// const config = AppConfig(Environment.production);
/// ```
abstract class MultiEnvironmentConfig implements EnvironmentConfig {
  @override
  final Environment environment;

  const MultiEnvironmentConfig(this.environment);

  /// Get base URL for the given environment
  String getBaseUrl(Environment env);

  /// Get headers for the given environment
  Map<String, dynamic> getHeaders(Environment env) => {};

  /// Get timeouts for the given environment
  Duration getConnectTimeout(Environment env) => const Duration(seconds: 30);

  Duration getReceiveTimeout(Environment env) => const Duration(seconds: 30);

  Duration getSendTimeout(Environment env) => const Duration(seconds: 30);

  @override
  String get baseUrl => getBaseUrl(environment);

  @override
  Map<String, dynamic> get headers => getHeaders(environment);

  @override
  Duration get connectTimeout => getConnectTimeout(environment);

  @override
  Duration get receiveTimeout => getReceiveTimeout(environment);

  @override
  Duration get sendTimeout => getSendTimeout(environment);

  @override
  bool get enableLogging => environment.isDevelopment;
}
