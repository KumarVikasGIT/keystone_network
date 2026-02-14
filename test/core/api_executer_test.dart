import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone_network/keystone_network.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockDio extends Mock implements Dio {}

class MockCancelToken extends Mock implements CancelToken {}

// Test models
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is User && other.id == id && other.name == name && other.email == email;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;
}

class CustomError {
  final String message;

  CustomError({required this.message});

  factory CustomError.fromJson(Map<String, dynamic> json) {
    return CustomError(message: json['message'] as String);
  }
}

void main() {
  group('ApiExecutor', () {
    late MockDio mockDio;
    late RequestOptions requestOptions;

    setUp(() {
      mockDio = MockDio();
      requestOptions = RequestOptions(path: '/test');
      registerFallbackValue(requestOptions);
    });

    group('execute', () {
      test('returns success state on successful request', () async {
        final responseData = {
          'id': 1,
          'name': 'John Doe',
          'email': 'john@example.com',
        };

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: responseData,
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        final result = await ApiExecutor.execute<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        expect(result.isSuccess, isTrue);
        expect(result.data?.id, equals(1));
        expect(result.data?.name, equals('John Doe'));
        expect(result.data?.email, equals('john@example.com'));

        verify(() => mockDio.get('/users/1')).called(1);
      });

      test('returns failed state on client error', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 400,
            data: {'message': 'Invalid request'},
          ),
        );

        when(() => mockDio.post('/users')).thenThrow(error);

        final result = await ApiExecutor.execute<User, dynamic>(
          request: () => mockDio.post('/users'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        expect(result.isFailed, isTrue);
        expect(result.error?.code, equals(ResponseCode.BAD_REQUEST));
        expect(result.error?.isClientError, isTrue);
      });

      test('returns network error state on network issues', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );

        when(() => mockDio.get('/users/1')).thenThrow(error);

        final result = await ApiExecutor.execute<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        expect(result.isNetworkError, isTrue);
        expect(result.error?.code, equals(ResponseCode.CONNECTION_TIMEOUT));
        expect(result.error?.isNetworkError, isTrue);
      });

      test('parses custom error data', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 400,
            data: {'message': 'Custom validation error'},
          ),
        );

        when(() => mockDio.post('/users')).thenThrow(error);

        final result = await ApiExecutor.execute<User, CustomError>(
          request: () => mockDio.post('/users'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
          errorParser: (json) => CustomError.fromJson(json),
        );

        expect(result.isFailed, isTrue);
        expect(result.error?.errorData?.message, equals('Custom validation error'));
      });

      test('handles server errors', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 500,
          ),
        );

        when(() => mockDio.get('/users/1')).thenThrow(error);

        final result = await ApiExecutor.execute<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        expect(result.isFailed, isTrue);
        expect(result.error?.code, equals(ResponseCode.INTERNAL_SERVER_ERROR));
        expect(result.error?.isServerError, isTrue);
      });

      test('handles different network error types', () async {
        final errorTypes = [
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.connectionError,
        ];

        for (final errorType in errorTypes) {
          final error = DioException(
            requestOptions: requestOptions,
            type: errorType,
          );

          when(() => mockDio.get('/users/1')).thenThrow(error);

          final result = await ApiExecutor.execute<User, dynamic>(
            request: () => mockDio.get('/users/1'),
            parser: (json) => User.fromJson(json as Map<String, dynamic>),
          );

          expect(
            result.isNetworkError,
            isTrue,
            reason: '$errorType should be network error',
          );
        }
      });

      test('parses list response', () async {
        final responseData = [
          {'id': 1, 'name': 'John', 'email': 'john@example.com'},
          {'id': 2, 'name': 'Jane', 'email': 'jane@example.com'},
        ];

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: responseData,
        );

        when(() => mockDio.get('/users')).thenAnswer((_) async => response);

        final result = await ApiExecutor.execute<List<User>, dynamic>(
          request: () => mockDio.get('/users'),
          parser: (json) {
            final list = json as List;
            return list.map((item) => User.fromJson(item as Map<String, dynamic>)).toList();
          },
        );

        expect(result.isSuccess, isTrue);
        expect(result.data?.length, equals(2));
        expect(result.data?[0].name, equals('John'));
        expect(result.data?[1].name, equals('Jane'));
      });
    });

    group('executeAsStateStream', () {
      test('emits loading then success states', () async {
        final responseData = {
          'id': 1,
          'name': 'John Doe',
          'email': 'john@example.com',
        };

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: responseData,
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        final stream = ApiExecutor.executeAsStateStream<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        final states = await stream.toList();

        expect(states.length, equals(2));
        expect(states[0].isLoading, isTrue);
        expect(states[1].isSuccess, isTrue);
        expect(states[1].data?.name, equals('John Doe'));
      });

      test('emits loading then failed states', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 404,
          ),
        );

        when(() => mockDio.get('/users/999')).thenThrow(error);

        final stream = ApiExecutor.executeAsStateStream<User, dynamic>(
          request: () => mockDio.get('/users/999'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        final states = await stream.toList();

        expect(states.length, equals(2));
        expect(states[0].isLoading, isTrue);
        expect(states[1].isFailed, isTrue);
        expect(states[1].error?.code, equals(ResponseCode.NOT_FOUND));
      });

      test('emits loading then network error states', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );

        when(() => mockDio.get('/users/1')).thenThrow(error);

        final stream = ApiExecutor.executeAsStateStream<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        final states = await stream.toList();

        expect(states.length, equals(2));
        expect(states[0].isLoading, isTrue);
        expect(states[1].isNetworkError, isTrue);
      });

      test('does not emit idle state', () async {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'id': 1, 'name': 'John', 'email': 'john@example.com'},
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        final stream = ApiExecutor.executeAsStateStream<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        final states = await stream.toList();

        expect(states.any((state) => state.isIdle), isFalse);
      });

      test('can be listened to multiple times', () async {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'id': 1, 'name': 'John', 'email': 'john@example.com'},
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        final stream = ApiExecutor.executeAsStateStream<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        // First listen
        final states1 = await stream.toList();
        expect(states1.length, greaterThan(0));

        // Reset mock
        reset(mockDio);
        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        // Second listen should work independently
        final stream2 = ApiExecutor.executeAsStateStream<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        final states2 = await stream2.toList();
        expect(states2.length, greaterThan(0));
      });
    });

    group('executeRaw', () {
      test('returns parsed data on success', () async {
        final responseData = {
          'id': 1,
          'name': 'John Doe',
          'email': 'john@example.com',
        };

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: responseData,
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        final user = await ApiExecutor.executeRaw<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        expect(user.id, equals(1));
        expect(user.name, equals('John Doe'));
        expect(user.email, equals('john@example.com'));
      });

      test('throws ErrorHandler on error', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 404,
          ),
        );

        when(() => mockDio.get('/users/999')).thenThrow(error);

        expect(
              () => ApiExecutor.executeRaw<User, dynamic>(
            request: () => mockDio.get('/users/999'),
            parser: (json) => User.fromJson(json as Map<String, dynamic>),
          ),
          throwsA(isA<ErrorHandler<dynamic>>()),
        );
      });

      test('includes custom error data in thrown ErrorHandler', () async {
        final error = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: requestOptions,
            statusCode: 400,
            data: {'message': 'Custom error'},
          ),
        );

        when(() => mockDio.post('/users')).thenThrow(error);

        try {
          await ApiExecutor.executeRaw<User, CustomError>(
            request: () => mockDio.post('/users'),
            parser: (json) => User.fromJson(json as Map<String, dynamic>),
            errorParser: (json) => CustomError.fromJson(json),
          );
          fail('Should have thrown ErrorHandler');
        } catch (e) {
          expect(e, isA<ErrorHandler<CustomError>>());
          final handler = e as ErrorHandler<CustomError>;
          expect(handler.failure.errorData?.message, equals('Custom error'));
        }
      });

      test('useful for composing multiple requests', () async {
        // Simulate fetching user, then their posts
        final userResponse = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'id': 1, 'name': 'John', 'email': 'john@example.com'},
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => userResponse);

        final user = await ApiExecutor.executeRaw<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        expect(user.id, equals(1));
        // Can now use user.id for next request
      });
    });

    group('Deprecated executeAsStream', () {
      test('still works but is deprecated', () async {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'id': 1, 'name': 'John', 'email': 'john@example.com'},
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        // Should still work
        final stream = ApiExecutor.executeAsStream<User, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => User.fromJson(json as Map<String, dynamic>),
        );

        final states = await stream.toList();

        expect(states.length, equals(2));
        expect(states[0].isLoading, isTrue);
        expect(states[1].isSuccess, isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles null response data gracefully', () async {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 204,
          data: null,
        );

        when(() => mockDio.delete('/users/1')).thenAnswer((_) async => response);

        final result = await ApiExecutor.execute<String, dynamic>(
          request: () => mockDio.delete('/users/1'),
          parser: (json) => json?.toString() ?? '',
        );

        expect(result.isSuccess, isTrue);
      });

      test('handles complex nested JSON', () async {
        final complexData = {
          'id': 1,
          'name': 'John',
          'email': 'john@example.com',
          'metadata': {
            'preferences': {
              'theme': 'dark',
              'notifications': true,
            },
          },
        };

        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: complexData,
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        final result = await ApiExecutor.execute<Map<String, dynamic>, dynamic>(
          request: () => mockDio.get('/users/1'),
          parser: (json) => json as Map<String, dynamic>,
        );

        expect(result.isSuccess, isTrue);
        expect(result.data?['metadata']['preferences']['theme'], equals('dark'));
      });

      test('handles parser throwing exception', () async {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'invalid': 'data'},
        );

        when(() => mockDio.get('/users/1')).thenAnswer((_) async => response);

        expect(
              () => ApiExecutor.execute<User, dynamic>(
            request: () => mockDio.get('/users/1'),
            parser: (json) {
              // Parser throws because data doesn't have required fields
              return User.fromJson(json as Map<String, dynamic>);
            },
          ),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('Integration Scenarios', () {
      test('simulates login flow', () async {
        final loginResponse = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {
            'user': {'id': 1, 'name': 'John', 'email': 'john@example.com'},
            'token': 'abc123',
          },
        );

        when(() => mockDio.post('/auth/login')).thenAnswer((_) async => loginResponse);

        final result = await ApiExecutor.execute<Map<String, dynamic>, dynamic>(
          request: () => mockDio.post('/auth/login'),
          parser: (json) => json as Map<String, dynamic>,
        );

        expect(result.isSuccess, isTrue);
        expect(result.data?['token'], equals('abc123'));
        expect(result.data?['user']['id'], equals(1));
      });

      test('simulates paginated list fetching', () async {
        final page1Response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {
            'data': [
              {'id': 1, 'name': 'User 1', 'email': 'user1@example.com'},
              {'id': 2, 'name': 'User 2', 'email': 'user2@example.com'},
            ],
            'pagination': {'page': 1, 'hasMore': true},
          },
        );

        when(() => mockDio.get('/users?page=1'))
            .thenAnswer((_) async => page1Response);

        final result = await ApiExecutor.execute<Map<String, dynamic>, dynamic>(
          request: () => mockDio.get('/users?page=1'),
          parser: (json) => json as Map<String, dynamic>,
        );

        expect(result.isSuccess, isTrue);
        expect((result.data?['data'] as List).length, equals(2));
        expect(result.data?['pagination']['hasMore'], isTrue);
      });
    });
  });
}