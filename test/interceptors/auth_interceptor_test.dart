import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone_network/keystone_network.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockTokenManager extends Mock implements TokenManager {}

class MockDioProvider extends Mock implements DioProvider {}

class MockDio extends Mock implements Dio {}

class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

class FakeRequestOptions extends Fake implements RequestOptions {
  @override
  final String path;
  @override
  final String method;
  @override
  final Map<String, dynamic> headers;
  @override
  final Map<String, dynamic> extra;

  FakeRequestOptions({
    this.path = '/test',
    this.method = 'GET',
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
  })  : headers = headers ?? {},
        extra = extra ?? {};
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(
      DioException(requestOptions: FakeRequestOptions()),
    );
    registerFallbackValue(
      Response(requestOptions: FakeRequestOptions()),
    );
  });

  group('AuthInterceptor', () {
    late MockTokenManager mockTokenManager;
    late MockDioProvider mockDioProvider;
    late MockDio mockDio;
    late AuthInterceptor interceptor;
    late MockRequestInterceptorHandler mockRequestHandler;
    late MockErrorInterceptorHandler mockErrorHandler;

    setUp(() {
      mockTokenManager = MockTokenManager();
      mockDioProvider = MockDioProvider();
      mockDio = MockDio();
      mockRequestHandler = MockRequestInterceptorHandler();
      mockErrorHandler = MockErrorInterceptorHandler();

      when(() => mockDioProvider.dio).thenReturn(mockDio);

      interceptor = AuthInterceptor(
        tokenManager: mockTokenManager,
        dioProvider: mockDioProvider,
      );
    });

    group('onRequest', () {
      test('adds authorization header with token', () async {
        const token = 'test_token_123';
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => token);

        final options = FakeRequestOptions();
        when(() => mockRequestHandler.next(any())).thenReturn(null);

        interceptor.onRequest(options, mockRequestHandler);

        expect(options.headers['Authorization'], equals('Bearer $token'));
        verify(() => mockRequestHandler.next(options)).called(1);
      });

      test('skips adding token when skipAuth is true', () async {
        final options = FakeRequestOptions(extra: {'skipAuth': true});
        when(() => mockRequestHandler.next(any())).thenReturn(null);

        interceptor.onRequest(options, mockRequestHandler);

        expect(options.headers.containsKey('Authorization'), isFalse);
        verify(() => mockRequestHandler.next(options)).called(1);
        verifyNever(() => mockTokenManager.getAccessToken());
      });

      test('does not add header when token is null', () async {
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => null);

        final options = FakeRequestOptions();
        when(() => mockRequestHandler.next(any())).thenReturn(null);

        interceptor.onRequest(options, mockRequestHandler);

        expect(options.headers.containsKey('Authorization'), isFalse);
        verify(() => mockRequestHandler.next(options)).called(1);
      });

      test('does not add header when token is empty', () async {
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => '');

        final options = FakeRequestOptions();
        when(() => mockRequestHandler.next(any())).thenReturn(null);

        interceptor.onRequest(options, mockRequestHandler);

        expect(options.headers.containsKey('Authorization'), isFalse);
        verify(() => mockRequestHandler.next(options)).called(1);
      });

      test('uses custom token formatter', () async {
        const token = 'test_token';
        final customInterceptor = AuthInterceptor(
          tokenManager: mockTokenManager,
          dioProvider: mockDioProvider,
          tokenFormatter: (t) => 'Token $t',
        );

        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => token);

        final options = FakeRequestOptions();
        when(() => mockRequestHandler.next(any())).thenReturn(null);

        customInterceptor.onRequest(options, mockRequestHandler);

        expect(options.headers['Authorization'], equals('Token $token'));
      });

      test('uses custom auth header key', () async {
        const token = 'test_token';
        final customInterceptor = AuthInterceptor(
          tokenManager: mockTokenManager,
          dioProvider: mockDioProvider,
          authHeaderKey: 'X-Auth-Token',
        );

        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => token);

        final options = FakeRequestOptions();
        when(() => mockRequestHandler.next(any())).thenReturn(null);

        customInterceptor.onRequest(options, mockRequestHandler);

        expect(options.headers['X-Auth-Token'], equals('Bearer $token'));
        expect(options.headers.containsKey('Authorization'), isFalse);
      });
    });

    group('onError - Token Refresh', () {
      test('refreshes token and retries on 401 error', () async {
        final originalRequest = FakeRequestOptions(path: '/api/users');
        final error = DioException(
          requestOptions: originalRequest,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: originalRequest,
            statusCode: 401,
          ),
        );

        const newToken = 'new_token_456';
        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => true);
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => newToken);

        final retryResponse = Response(
          requestOptions: originalRequest,
          statusCode: 200,
          data: {'success': true},
        );

        when(() => mockDio.fetch<dynamic>(any()))
            .thenAnswer((_) async => retryResponse);
        when(() => mockErrorHandler.resolve(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockTokenManager.refreshToken()).called(1);
        verify(() => mockDio.fetch<dynamic>(any())).called(1);
        verify(() => mockErrorHandler.resolve(retryResponse)).called(1);
      });

      test('clears tokens and fails on refresh failure', () async {
        final originalRequest = FakeRequestOptions();
        final error = DioException(
          requestOptions: originalRequest,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: originalRequest,
            statusCode: 401,
          ),
        );

        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => false);
        when(() => mockTokenManager.clearTokens()).thenAnswer((_) async {});
        when(() => mockErrorHandler.next(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockTokenManager.refreshToken()).called(1);
        verify(() => mockTokenManager.clearTokens()).called(1);
        verify(() => mockErrorHandler.next(error)).called(1);
        verifyNever(() => mockDio.fetch<dynamic>(any()));
      });

      test('passes through non-401 errors', () async {
        final error = DioException(
          requestOptions: FakeRequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: FakeRequestOptions(),
            statusCode: 404,
          ),
        );

        when(() => mockErrorHandler.next(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockErrorHandler.next(error)).called(1);
        verifyNever(() => mockTokenManager.refreshToken());
      });

      test('uses custom shouldRefreshToken logic', () async {
        final customInterceptor = AuthInterceptor(
          tokenManager: mockTokenManager,
          dioProvider: mockDioProvider,
          shouldRefreshToken: (statusCode) => statusCode == 403,
        );

        final error403 = DioException(
          requestOptions: FakeRequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: FakeRequestOptions(),
            statusCode: 403,
          ),
        );

        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => true);
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => 'token');
        when(() => mockDio.fetch<dynamic>(any())).thenAnswer(
              (_) async => Response(requestOptions: FakeRequestOptions()),
        );
        when(() => mockErrorHandler.resolve(any())).thenReturn(null);

        customInterceptor.onError(error403, mockErrorHandler);

        verify(() => mockTokenManager.refreshToken()).called(1);
      });

      test('queues requests during token refresh', () async {
        final request1 = FakeRequestOptions(path: '/api/endpoint1');
        final request2 = FakeRequestOptions(path: '/api/endpoint2');

        final error1 = DioException(
          requestOptions: request1,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request1, statusCode: 401),
        );

        final error2 = DioException(
          requestOptions: request2,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request2, statusCode: 401),
        );

        final handler1 = MockErrorInterceptorHandler();
        final handler2 = MockErrorInterceptorHandler();

        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => true);
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => 'new_token');

        when(() => mockDio.fetch<dynamic>(any())).thenAnswer(
              (_) async => Response(
            requestOptions: FakeRequestOptions(),
            statusCode: 200,
          ),
        );

        when(() => handler1.resolve(any())).thenReturn(null);
        when(() => handler2.resolve(any())).thenReturn(null);

        interceptor.onError(error1, handler1);
        interceptor.onError(error2, handler2);

        // Wait for async operations
        await Future.delayed(Duration(milliseconds: 100));

        // Verify results
        verify(() => handler1.resolve(any())).called(1);

        // Both should be resolved
        verify(() => handler1.resolve(any())).called(1);
        verify(() => handler2.resolve(any())).called(1);

        // Refresh should only be called once
        verify(() => mockTokenManager.refreshToken()).called(1);
      });

      test('fails queued requests when refresh fails', () async {
        final request1 = FakeRequestOptions(path: '/api/endpoint1');
        final request2 = FakeRequestOptions(path: '/api/endpoint2');

        final error1 = DioException(
          requestOptions: request1,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request1, statusCode: 401),
        );

        final error2 = DioException(
          requestOptions: request2,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request2, statusCode: 401),
        );

        final handler1 = MockErrorInterceptorHandler();
        final handler2 = MockErrorInterceptorHandler();

        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => false);
        when(() => mockTokenManager.clearTokens()).thenAnswer((_) async {});

        when(() => handler1.next(any())).thenReturn(null);
        when(() => handler2.next(any())).thenReturn(null);

        interceptor.onError(error1, handler1);
        interceptor.onError(error2, handler2);

        // Wait for async operations
        await Future.delayed(Duration(milliseconds: 100));

        // Verify results
        verify(() => handler1.resolve(any())).called(1);

        // Both should fail
        verify(() => handler1.next(any())).called(1);
        verify(() => handler2.next(any())).called(1);
      });

      test('handles refresh throwing exception', () async {
        final error = DioException(
          requestOptions: FakeRequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: FakeRequestOptions(),
            statusCode: 401,
          ),
        );

        when(() => mockTokenManager.refreshToken())
            .thenThrow(Exception('Refresh failed'));
        when(() => mockErrorHandler.next(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockErrorHandler.next(error)).called(1);
      });
    });

    group('Token Injection on Retry', () {
      test('includes new token in retry request', () async {
        final originalRequest = FakeRequestOptions();
        final error = DioException(
          requestOptions: originalRequest,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: originalRequest, statusCode: 401),
        );

        const newToken = 'refreshed_token';
        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => true);
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => newToken);

        RequestOptions? capturedOptions;
        when(() => mockDio.fetch<dynamic>(any())).thenAnswer((invocation) {
          capturedOptions = invocation.positionalArguments[0] as RequestOptions;
          return Future.value(Response(requestOptions: capturedOptions!));
        });

        when(() => mockErrorHandler.resolve(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        expect(
          capturedOptions?.headers['Authorization'],
          equals('Bearer $newToken'),
        );
      });
    });

    group('Edge Cases', () {
      test('handles missing response in error', () async {
        final error = DioException(
          requestOptions: FakeRequestOptions(),
          type: DioExceptionType.connectionTimeout,
          response: null,
        );

        when(() => mockErrorHandler.next(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockErrorHandler.next(error)).called(1);
        verifyNever(() => mockTokenManager.refreshToken());
      });

      test('handles null status code', () async {
        final error = DioException(
          requestOptions: FakeRequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: FakeRequestOptions(),
            statusCode: null,
          ),
        );

        when(() => mockErrorHandler.next(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockErrorHandler.next(error)).called(1);
        verifyNever(() => mockTokenManager.refreshToken());
      });
    });

    group('Real World Scenarios', () {
      test('simulates full authentication flow', () async {
        // 1. Initial request with valid token
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => 'initial_token');

        final initialOptions = FakeRequestOptions(path: '/api/profile');
        when(() => mockRequestHandler.next(any())).thenReturn(null);

        interceptor.onRequest(initialOptions, mockRequestHandler);
        expect(
          initialOptions.headers['Authorization'],
          equals('Bearer initial_token'),
        );

        // 2. Token expires, get 401
        final error = DioException(
          requestOptions: initialOptions,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: initialOptions, statusCode: 401),
        );

        // 3. Refresh succeeds
        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => true);
        when(() => mockTokenManager.getAccessToken())
            .thenAnswer((_) async => 'refreshed_token');

        when(() => mockDio.fetch<dynamic>(any())).thenAnswer(
              (_) async => Response(
            requestOptions: initialOptions,
            statusCode: 200,
            data: {'profile': 'data'},
          ),
        );

        when(() => mockErrorHandler.resolve(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockTokenManager.refreshToken()).called(1);
        verify(() => mockErrorHandler.resolve(any())).called(1);
      });

      test('simulates token refresh failure leading to logout', () async {
        final error = DioException(
          requestOptions: FakeRequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: FakeRequestOptions(),
            statusCode: 401,
          ),
        );

        when(() => mockTokenManager.refreshToken())
            .thenAnswer((_) async => false);
        when(() => mockTokenManager.clearTokens()).thenAnswer((_) async {});
        when(() => mockErrorHandler.next(any())).thenReturn(null);

        interceptor.onError(error, mockErrorHandler);

        verify(() => mockTokenManager.clearTokens()).called(1);
      });
    });
  });
}