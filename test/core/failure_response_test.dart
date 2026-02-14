import 'package:flutter_test/flutter_test.dart';
import 'package:keystone_network/keystone_network.dart';

void main() {
  group('FailureResponse', () {
    group('Constructor', () {
      test('creates instance with code and message', () {
        const failure = FailureResponse<dynamic>(400, 'Bad Request');
        expect(failure.code, equals(400));
        expect(failure.message, equals('Bad Request'));
        expect(failure.errorData, isNull);
      });

      test('creates instance with custom error data', () {
        final errorData = {'field': 'email', 'error': 'Invalid email'};
        final failure = FailureResponse<Map<String, dynamic>>(
          422,
          'Validation failed',
          errorData: errorData,
        );

        expect(failure.code, equals(422));
        expect(failure.message, equals('Validation failed'));
        expect(failure.errorData, equals(errorData));
      });

      test('handles null error data', () {
        const failure = FailureResponse<String>(500, 'Server Error');
        expect(failure.errorData, isNull);
      });
    });

    group('Network Error Detection', () {
      test('isNetworkError returns true for connection timeout', () {
        const failure = FailureResponse<dynamic>(
          ResponseCode.CONNECTION_TIMEOUT,
          'Connection timeout',
        );
        expect(failure.isNetworkError, isTrue);
      });

      test('isNetworkError returns true for no internet', () {
        const failure = FailureResponse<dynamic>(
          ResponseCode.NO_INTERNET_CONNECTION,
          'No internet',
        );
        expect(failure.isNetworkError, isTrue);
      });

      test('isNetworkError returns true for receive timeout', () {
        const failure = FailureResponse<dynamic>(
          ResponseCode.RECEIVE_TIMEOUT,
          'Receive timeout',
        );
        expect(failure.isNetworkError, isTrue);
      });

      test('isNetworkError returns true for send timeout', () {
        const failure = FailureResponse<dynamic>(
          ResponseCode.SEND_TIMEOUT,
          'Send timeout',
        );
        expect(failure.isNetworkError, isTrue);
      });

      test('isNetworkError returns false for non-network errors', () {
        const failure = FailureResponse<dynamic>(400, 'Bad Request');
        expect(failure.isNetworkError, isFalse);
      });
    });

    group('Client Error Detection', () {
      test('isClientError returns true for 4xx codes', () {
        expect(
          const FailureResponse<dynamic>(400, 'Bad Request').isClientError,
          isTrue,
        );
        expect(
          const FailureResponse<dynamic>(401, 'Unauthorized').isClientError,
          isTrue,
        );
        expect(
          const FailureResponse<dynamic>(404, 'Not Found').isClientError,
          isTrue,
        );
        expect(
          const FailureResponse<dynamic>(422, 'Unprocessable').isClientError,
          isTrue,
        );
        expect(
          const FailureResponse<dynamic>(499, 'Client Error').isClientError,
          isTrue,
        );
      });

      test('isClientError returns false for non-4xx codes', () {
        expect(
          const FailureResponse<dynamic>(200, 'OK').isClientError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(500, 'Server Error').isClientError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(-2, 'Network Error').isClientError,
          isFalse,
        );
      });
    });

    group('Server Error Detection', () {
      test('isServerError returns true for 5xx codes', () {
        expect(
          const FailureResponse<dynamic>(500, 'Internal Error').isServerError,
          isTrue,
        );
        expect(
          const FailureResponse<dynamic>(502, 'Bad Gateway').isServerError,
          isTrue,
        );
        expect(
          const FailureResponse<dynamic>(503, 'Unavailable').isServerError,
          isTrue,
        );
        expect(
          const FailureResponse<dynamic>(599, 'Server Error').isServerError,
          isTrue,
        );
      });

      test('isServerError returns false for non-5xx codes', () {
        expect(
          const FailureResponse<dynamic>(400, 'Bad Request').isServerError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(200, 'OK').isServerError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(-2, 'Network Error').isServerError,
          isFalse,
        );
      });
    });

    group('Auth Error Detection', () {
      test('isAuthError returns true for 401', () {
        const failure = FailureResponse<dynamic>(401, 'Unauthorized');
        expect(failure.isAuthError, isTrue);
      });

      test('isAuthError returns true for 403', () {
        const failure = FailureResponse<dynamic>(403, 'Forbidden');
        expect(failure.isAuthError, isTrue);
      });

      test('isAuthError returns false for other codes', () {
        expect(
          const FailureResponse<dynamic>(400, 'Bad Request').isAuthError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(404, 'Not Found').isAuthError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(500, 'Server Error').isAuthError,
          isFalse,
        );
      });
    });

    group('Validation Error Detection', () {
      test('isValidationError returns true for 400', () {
        const failure = FailureResponse<dynamic>(400, 'Bad Request');
        expect(failure.isValidationError, isTrue);
      });

      test('isValidationError returns false for other codes', () {
        expect(
          const FailureResponse<dynamic>(401, 'Unauthorized').isValidationError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(422, 'Unprocessable').isValidationError,
          isFalse,
        );
        expect(
          const FailureResponse<dynamic>(500, 'Server Error').isValidationError,
          isFalse,
        );
      });
    });

    group('Equality', () {
      test('equal instances with same values', () {
        const failure1 = FailureResponse<dynamic>(400, 'Bad Request');
        const failure2 = FailureResponse<dynamic>(400, 'Bad Request');

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
      });

      test('not equal with different codes', () {
        const failure1 = FailureResponse<dynamic>(400, 'Bad Request');
        const failure2 = FailureResponse<dynamic>(401, 'Bad Request');

        expect(failure1, isNot(equals(failure2)));
      });

      test('not equal with different messages', () {
        const failure1 = FailureResponse<dynamic>(400, 'Bad Request');
        const failure2 = FailureResponse<dynamic>(400, 'Validation Error');

        expect(failure1, isNot(equals(failure2)));
      });

      test('equal with same custom error data', () {
        // Using a custom class with proper equality
        final error1 = ValidationError('email', 'Invalid email');
        final error2 = ValidationError('email', 'Invalid email');

        final failure1 = FailureResponse<ValidationError>(
          400,
          'Validation failed',
          errorData: error1,
        );
        final failure2 = FailureResponse<ValidationError>(
          400,
          'Validation failed',
          errorData: error2,
        );

        expect(failure1, equals(failure2));
        expect(failure1.hashCode, equals(failure2.hashCode));
      });

      test('not equal with different error data', () {
        final error1 = ValidationError('email', 'Invalid email');
        final error2 = ValidationError('password', 'Too short');

        final failure1 = FailureResponse<ValidationError>(
          400,
          'Validation failed',
          errorData: error1,
        );
        final failure2 = FailureResponse<ValidationError>(
          400,
          'Validation failed',
          errorData: error2,
        );

        expect(failure1, isNot(equals(failure2)));
      });

      test('equal when both have null error data', () {
        const failure1 = FailureResponse<String>(400, 'Bad Request');
        const failure2 = FailureResponse<String>(400, 'Bad Request');

        expect(failure1, equals(failure2));
      });

      test('not equal when one has error data and other is null', () {
        const failure1 = FailureResponse<String>(
          400,
          'Bad Request',
          errorData: 'error',
        );
        const failure2 = FailureResponse<String>(400, 'Bad Request');

        expect(failure1, isNot(equals(failure2)));
      });
    });

    group('toString', () {
      test('toString without error data', () {
        const failure = FailureResponse<dynamic>(400, 'Bad Request');
        expect(
          failure.toString(),
          equals('FailureResponse(code: 400, message: Bad Request)'),
        );
      });

      test('toString with error data', () {
        const failure = FailureResponse<String>(
          400,
          'Bad Request',
          errorData: 'Custom error',
        );
        expect(
          failure.toString(),
          equals(
            'FailureResponse(code: 400, message: Bad Request, errorData: Custom error)',
          ),
        );
      });

      test('toString with complex error data', () {
        final errorData = {'field': 'email', 'error': 'Invalid'};
        final failure = FailureResponse<Map<String, dynamic>>(
          422,
          'Validation failed',
          errorData: errorData,
        );

        expect(failure.toString(), contains('code: 422'));
        expect(failure.toString(), contains('message: Validation failed'));
        expect(failure.toString(), contains('errorData:'));
      });
    });

    group('Type Safety', () {
      test('preserves custom error type', () {
        final error = ValidationError('email', 'Invalid email');
        final failure = FailureResponse<ValidationError>(
          400,
          'Validation failed',
          errorData: error,
        );

        expect(failure.errorData, isA<ValidationError>());
        expect(failure.errorData?.field, equals('email'));
        expect(failure.errorData?.message, equals('Invalid email'));
      });

      test('works with Map error data', () {
        final errorData = {'field': 'email', 'error': 'Invalid'};
        final failure = FailureResponse<Map<String, dynamic>>(
          422,
          'Validation failed',
          errorData: errorData,
        );

        expect(failure.errorData, isA<Map<String, dynamic>>());
        expect(failure.errorData?['field'], equals('email'));
      });

      test('works with List error data', () {
        final errorData = ['Error 1', 'Error 2'];
        final failure = FailureResponse<List<String>>(
          400,
          'Multiple errors',
          errorData: errorData,
        );

        expect(failure.errorData, isA<List<String>>());
        expect(failure.errorData?.length, equals(2));
      });
    });

    group('Real World Scenarios', () {
      test('handles standard HTTP errors', () {
        final scenarios = [
          (400, 'Bad Request', false, true, false, false),
          (401, 'Unauthorized', false, true, false, true),
          (403, 'Forbidden', false, true, false, true),
          (404, 'Not Found', false, true, false, false),
          (500, 'Internal Server Error', false, false, true, false),
          (502, 'Bad Gateway', false, false, true, false),
          (503, 'Service Unavailable', false, false, true, false),
        ];

        for (final scenario in scenarios) {
          final failure = FailureResponse<dynamic>(scenario.$1, scenario.$2);
          expect(
            failure.isNetworkError,
            equals(scenario.$3),
            reason: '${scenario.$1} network error check failed',
          );
          expect(
            failure.isClientError,
            equals(scenario.$4),
            reason: '${scenario.$1} client error check failed',
          );
          expect(
            failure.isServerError,
            equals(scenario.$5),
            reason: '${scenario.$1} server error check failed',
          );
          expect(
            failure.isAuthError,
            equals(scenario.$6),
            reason: '${scenario.$1} auth error check failed',
          );
        }
      });

      test('handles network timeouts', () {
        final scenarios = [
          (ResponseCode.CONNECTION_TIMEOUT, 'Connection timeout'),
          (ResponseCode.SEND_TIMEOUT, 'Send timeout'),
          (ResponseCode.RECEIVE_TIMEOUT, 'Receive timeout'),
          (ResponseCode.NO_INTERNET_CONNECTION, 'No internet'),
        ];

        for (final scenario in scenarios) {
          final failure = FailureResponse<dynamic>(scenario.$1, scenario.$2);
          expect(
            failure.isNetworkError,
            isTrue,
            reason: '${scenario.$2} should be network error',
          );
          expect(failure.isClientError, isFalse);
          expect(failure.isServerError, isFalse);
        }
      });
    });
  });
}

// Helper class for testing custom error types
class ValidationError {
  final String field;
  final String message;

  ValidationError(this.field, this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ValidationError &&
              other.field == field &&
              other.message == message;

  @override
  int get hashCode => field.hashCode ^ message.hashCode;

  @override
  String toString() => 'ValidationError(field: $field, message: $message)';
}