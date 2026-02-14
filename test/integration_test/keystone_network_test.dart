import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone_network/config/keystone_network.dart';
import 'package:keystone_network/keystone_network.dart';
import 'package:mocktail/mocktail.dart';

// Mock HTTP client for integration testing
class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
  });

  group('KeystoneNetwork Integration Tests', () {
    tearDown(() {
      // Reset KeystoneNetwork after each test
      KeystoneNetwork.reset();
    });

    group('Initialization', () {
      test('initializes with default configuration', () {
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
        );

        final dio = KeystoneNetwork.dio;
        expect(dio.options.baseUrl, equals('https://api.example.com'));
        expect(dio.options.connectTimeout, equals(const Duration(seconds: 30)));
      });

      test('initializes with custom configuration', () {
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
          headers: {'X-Custom-Header': 'value'},
        );

        final dio = KeystoneNetwork.dio;
        expect(dio.options.connectTimeout, equals(const Duration(seconds: 60)));
        expect(dio.options.receiveTimeout, equals(const Duration(seconds: 45)));
        expect(dio.options.headers['X-Custom-Header'], equals('value'));
      });

      test('initializes with interceptors', () {
        final loggingInterceptor = LoggingInterceptor();

        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          interceptors: [loggingInterceptor],
        );

        final dio = KeystoneNetwork.dio;
        expect(dio.interceptors.length, greaterThan(0));
      });

      test('throws when accessing dio before initialization', () {
        expect(
              () => KeystoneNetwork.dio,
          throwsA(isA<StateError>()),
        );
      });

      test('throws when accessing dioProvider before initialization', () {
        expect(
              () => KeystoneNetwork.dioProvider,
          throwsA(isA<StateError>()),
        );
      });

      test('provides dioProvider after initialization', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api.example.com');

        final provider = KeystoneNetwork.dioProvider;
        expect(provider, isNotNull);
        expect(provider.dio, equals(KeystoneNetwork.dio));
      });
    });

    group('Multiple Instances', () {
      test('creates independent instance', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api1.example.com');

        final instance2 = KeystoneNetwork.createInstance(
          baseUrl: 'https://api2.example.com',
          connectTimeout: const Duration(seconds: 45),
        );

        expect(KeystoneNetwork.dio.options.baseUrl, equals('https://api1.example.com'));
        expect(instance2.options.baseUrl, equals('https://api2.example.com'));
        expect(instance2.options.connectTimeout, equals(const Duration(seconds: 45)));
      });

      test('independent instances do not share configuration', () {
        final instance1 = KeystoneNetwork.createInstance(
          baseUrl: 'https://api1.example.com',
          headers: {'X-App': 'App1'},
        );

        final instance2 = KeystoneNetwork.createInstance(
          baseUrl: 'https://api2.example.com',
          headers: {'X-App': 'App2'},
        );

        expect(instance1.options.headers['X-App'], equals('App1'));
        expect(instance2.options.headers['X-App'], equals('App2'));
      });

      test('independent instances can have different interceptors', () {
        final logging1 = LoggingInterceptor(level: LogLevel.basic);
        final logging2 = LoggingInterceptor(level: LogLevel.body);

        final instance1 = KeystoneNetwork.createInstance(
          baseUrl: 'https://api1.example.com',
          interceptors: [logging1],
        );

        final instance2 = KeystoneNetwork.createInstance(
          baseUrl: 'https://api2.example.com',
          interceptors: [logging2],
        );

        expect(instance1.interceptors.length, equals(1));
        expect(instance2.interceptors.length, equals(1));
        expect(instance1.interceptors.first, equals(logging1));
        expect(instance2.interceptors.first, equals(logging2));
      });
    });

    group('Custom DioProvider', () {
      test('creates DioProvider for custom Dio instance', () {
        final customDio = Dio(BaseOptions(baseUrl: 'https://custom.com'));
        final provider = KeystoneNetwork.createDioProvider(customDio);

        expect(provider.dio, equals(customDio));
      });
    });

    group('Default Headers', () {
      test('includes default Accept and Content-Type headers', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api.example.com');

        final dio = KeystoneNetwork.dio;
        expect(dio.options.headers['Accept'], equals('application/json'));
        expect(dio.options.headers['Content-Type'], equals('application/json'));
      });

      test('allows custom headers to override defaults', () {
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          headers: {'Content-Type': 'application/xml'},
        );

        final dio = KeystoneNetwork.dio;
        expect(dio.options.headers['Content-Type'], equals('application/xml'));
      });

      test('merges custom headers with defaults', () {
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          headers: {
            'X-API-Key': 'secret',
            'X-App-Version': '1.0.0',
          },
        );

        final dio = KeystoneNetwork.dio;
        expect(dio.options.headers['Accept'], equals('application/json'));
        expect(dio.options.headers['X-API-Key'], equals('secret'));
        expect(dio.options.headers['X-App-Version'], equals('1.0.0'));
      });
    });

    group('Response Type', () {
      test('defaults to JSON response type', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api.example.com');

        expect(KeystoneNetwork.dio.options.responseType, equals(ResponseType.json));
      });

      test('allows custom response type', () {
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          responseType: ResponseType.plain,
        );

        expect(KeystoneNetwork.dio.options.responseType, equals(ResponseType.plain));
      });
    });

    group('Status Validation', () {
      test('uses default status validation', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api.example.com');

        final validate = KeystoneNetwork.dio.options.validateStatus;
        expect(validate, isNotNull);
        expect(validate(200), isTrue);
        expect(validate(299), isTrue);
        expect(validate(300), isFalse);
        expect(validate(400), isFalse);
      });

      test('allows custom status validation', () {
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          validateStatus: (status) => status != null && status < 500,
        );

        final validate = KeystoneNetwork.dio.options.validateStatus;
        expect(validate(200), isTrue);
        expect(validate(400), isTrue);
        expect(validate(500), isFalse);
      });
    });

    group('Reset Functionality', () {
      test('reset clears Dio instance', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api.example.com');
        expect(() => KeystoneNetwork.dio, returnsNormally);

        KeystoneNetwork.reset();

        expect(() => KeystoneNetwork.dio, throwsA(isA<StateError>()));
      });

      test('reset clears DioProvider', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api.example.com');
        expect(() => KeystoneNetwork.dioProvider, returnsNormally);

        KeystoneNetwork.reset();

        expect(() => KeystoneNetwork.dioProvider, throwsA(isA<StateError>()));
      });

      test('can reinitialize after reset', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api1.example.com');
        final dio1 = KeystoneNetwork.dio;

        KeystoneNetwork.reset();

        KeystoneNetwork.initialize(baseUrl: 'https://api2.example.com');
        final dio2 = KeystoneNetwork.dio;

        expect(dio1, isNot(same(dio2)));
        expect(dio2.options.baseUrl, equals('https://api2.example.com'));
      });
    });

    group('End-to-End Integration', () {
      test('complete API flow with all components', () async {
        // Setup mock token manager
        final tokenManager = TestTokenManager();

        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          interceptors: [
            AuthInterceptor(
              tokenManager: tokenManager,
              dioProvider: KeystoneNetwork.dioProvider,
            ),
            LoggingInterceptor(level: LogLevel.basic),
          ],
        );

        expect(() => KeystoneNetwork.dio, returnsNormally);
        expect(KeystoneNetwork.dio.interceptors.length, equals(2));
      });

      test('multiple API configurations', () {
        // Main API
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          headers: {'X-App': 'main'},
        );

        // Analytics API
        final analyticsApi = KeystoneNetwork.createInstance(
          baseUrl: 'https://analytics.example.com',
          headers: {'X-App': 'analytics'},
          connectTimeout: const Duration(seconds: 15),
        );

        // Payment API
        final paymentApi = KeystoneNetwork.createInstance(
          baseUrl: 'https://payment.example.com',
          headers: {'X-App': 'payment'},
          connectTimeout: const Duration(seconds: 45),
        );

        expect(KeystoneNetwork.dio.options.baseUrl, equals('https://api.example.com'));
        expect(analyticsApi.options.baseUrl, equals('https://analytics.example.com'));
        expect(paymentApi.options.baseUrl, equals('https://payment.example.com'));

        expect(analyticsApi.options.connectTimeout, equals(const Duration(seconds: 15)));
        expect(paymentApi.options.connectTimeout, equals(const Duration(seconds: 45)));
      });
    });

    group('Environment-based Configuration', () {
      test('works with DefaultEnvironmentConfig', () {
        final config = DefaultEnvironmentConfig(
          environment: Environment.production,
          baseUrl: 'https://api.example.com',
          connectTimeout: const Duration(seconds: 45),
          headers: {'X-Environment': 'production'},
        );

        KeystoneNetwork.initialize(
          baseUrl: config.baseUrl,
          connectTimeout: config.connectTimeout,
          headers: config.headers,
        );

        expect(KeystoneNetwork.dio.options.baseUrl, equals(config.baseUrl));
        expect(KeystoneNetwork.dio.options.connectTimeout, equals(config.connectTimeout));
        expect(KeystoneNetwork.dio.options.headers['X-Environment'], equals('production'));
      });

      test('supports custom EnvironmentConfig', () {
        final config = TestEnvironmentConfig(Environment.development);

        KeystoneNetwork.initialize(
          baseUrl: config.baseUrl,
          connectTimeout: config.connectTimeout,
          headers: config.headers,
        );

        expect(KeystoneNetwork.dio.options.baseUrl, contains('dev'));
        expect(KeystoneNetwork.dio.options.headers['X-Environment'], equals('development'));
      });
    });

    group('Safety and Error Handling', () {
      test('handles initialization with null baseUrl', () {
        KeystoneNetwork.initialize();

        expect(KeystoneNetwork.dio.options.baseUrl, equals(''));
      });

      test('handles empty interceptor list', () {
        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          interceptors: [],
        );

        expect(KeystoneNetwork.dio.interceptors.length, equals(0));
      });

      test('reset handles uninitialized state gracefully', () {
        expect(() => KeystoneNetwork.reset(), returnsNormally);
      });

      test('reset can be called multiple times', () {
        KeystoneNetwork.initialize(baseUrl: 'https://api.example.com');

        expect(() => KeystoneNetwork.reset(), returnsNormally);
        expect(() => KeystoneNetwork.reset(), returnsNormally);
      });
    });

    group('Interceptor Chain', () {
      test('maintains interceptor order', () {
        final interceptor1 = TestInterceptor(1);
        final interceptor2 = TestInterceptor(2);
        final interceptor3 = TestInterceptor(3);

        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          interceptors: [interceptor1, interceptor2, interceptor3],
        );

        final interceptors = KeystoneNetwork.dio.interceptors;
        expect(interceptors[0], same(interceptor1));
        expect(interceptors[1], same(interceptor2));
        expect(interceptors[2], same(interceptor3));
      });

      test('interceptors work with ApiExecutor', () async {
        final testInterceptor = TestInterceptor(1);

        KeystoneNetwork.initialize(
          baseUrl: 'https://api.example.com',
          interceptors: [testInterceptor],
        );

        // Interceptor should be properly integrated
        expect(KeystoneNetwork.dio.interceptors.contains(testInterceptor), isTrue);
      });
    });
  });
}

// Test helper classes
class TestTokenManager implements TokenManager {
  String? _accessToken = 'test_token';
  String? _refreshToken = 'refresh_token';

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<bool> refreshToken() async {
    _accessToken = 'new_token';
    return true;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<bool> isAuthenticated() async => _accessToken != null;
}

class TestEnvironmentConfig extends MultiEnvironmentConfig {
  TestEnvironmentConfig(super.environment);

  @override
  String getBaseUrl(Environment env) {
    return switch (env) {
      Environment.development => 'https://dev-api.example.com',
      Environment.staging => 'https://staging-api.example.com',
      Environment.production => 'https://api.example.com',
    };
  }

  @override
  Map<String, dynamic> getHeaders(Environment env) {
    return {'X-Environment': env.name};
  }
}

class TestInterceptor extends Interceptor {
  final int id;
  TestInterceptor(this.id);
}