import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keystone_network/keystone_network.dart';

void main() {
  group('ErrorHandler', () {
    group('DioException Handling', () {
      test('handles connection timeout', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.CONNECTION_TIMEOUT));
        expect(handler.failure.message, equals(ResponseMessage.CONNECT_TIMEOUT));
        expect(handler.failure.isNetworkError, isTrue);
      });

      test('handles send timeout', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.sendTimeout,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.SEND_TIMEOUT));
        expect(handler.failure.message, equals(ResponseMessage.SEND_TIMEOUT));
        expect(handler.failure.isNetworkError, isTrue);
      });

      test('handles receive timeout', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.receiveTimeout,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.RECEIVE_TIMEOUT));
        expect(handler.failure.message, equals(ResponseMessage.RECEIVE_TIMEOUT));
        expect(handler.failure.isNetworkError, isTrue);
      });

      test('handles connection error (no internet)', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.NO_INTERNET_CONNECTION));
        expect(handler.failure.message, equals(ResponseMessage.NO_INTERNET_CONNECTION));
        expect(handler.failure.isNetworkError, isTrue);
      });

      test('handles request cancellation', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.cancel,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.CANCEL));
        expect(handler.failure.message, equals(ResponseMessage.CANCEL));
      });

      test('handles bad certificate', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badCertificate,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.BAD_CERTIFICATE));
        expect(handler.failure.message, equals(ResponseMessage.BAD_CERTIFICATE));
      });

      test('handles unknown error type', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.unknown,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNKNOWN));
        expect(handler.failure.message, equals(ResponseMessage.UNKNOWN));
      });
    });

    group('HTTP Status Code Mapping', () {
      test('handles 400 Bad Request', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 400,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.BAD_REQUEST));
        expect(handler.failure.message, equals(ResponseMessage.BAD_REQUEST));
        expect(handler.failure.isClientError, isTrue);
      });

      test('handles 401 Unauthorized', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 401,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNAUTHORISED));
        expect(handler.failure.message, equals(ResponseMessage.UNAUTHORISED));
        expect(handler.failure.isAuthError, isTrue);
      });

      test('handles 403 Forbidden', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 403,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.FORBIDDEN));
        expect(handler.failure.message, equals(ResponseMessage.FORBIDDEN));
        expect(handler.failure.isAuthError, isTrue);
      });

      test('handles 404 Not Found', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 404,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.NOT_FOUND));
        expect(handler.failure.message, equals(ResponseMessage.NOT_FOUND));
      });

      test('handles 405 Method Not Allowed', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 405,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.METHOD_NOT_ALLOWED));
        expect(handler.failure.message, equals(ResponseMessage.METHOD_NOT_ALLOWED));
      });

      test('handles 409 Conflict', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 409,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.CONFLICT));
        expect(handler.failure.message, equals(ResponseMessage.CONFLICT));
      });

      test('handles 422 Unprocessable Entity', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 422,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNPROCESSABLE_ENTITY));
        expect(handler.failure.message, equals(ResponseMessage.UNPROCESSABLE_ENTITY));
      });

      test('handles 500 Internal Server Error', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 500,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.INTERNAL_SERVER_ERROR));
        expect(handler.failure.message, equals(ResponseMessage.INTERNAL_SERVER_ERROR));
        expect(handler.failure.isServerError, isTrue);
      });

      test('handles 501 Not Implemented', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 501,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.NOT_IMPLEMENTED));
        expect(handler.failure.message, equals(ResponseMessage.NOT_IMPLEMENTED));
      });

      test('handles 502 Bad Gateway', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 502,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.BAD_GATEWAY));
        expect(handler.failure.message, equals(ResponseMessage.BAD_GATEWAY));
      });

      test('handles 503 Service Unavailable', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 503,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.SERVICE_UNAVAILABLE));
        expect(handler.failure.message, equals(ResponseMessage.SERVICE_UNAVAILABLE));
      });

      test('handles 504 Gateway Timeout', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 504,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.GATEWAY_TIMEOUT));
        expect(handler.failure.message, equals(ResponseMessage.GATEWAY_TIMEOUT));
      });

      test('handles unknown status code', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 418, // I'm a teapot
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNKNOWN));
        expect(handler.failure.message, equals(ResponseMessage.UNKNOWN));
      });

      test('handles null status code', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: null,
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNKNOWN));
        expect(handler.failure.message, equals(ResponseMessage.UNKNOWN));
      });
    });

    group('Custom Error Parsing', () {
      test('parses custom error from response data', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 400,
            data: {
              'field': 'email',
              'message': 'Invalid email format',
            },
          ),
        );

        final handler = ErrorHandler<ValidationError>.handle(
          error,
          parseError: (json) => ValidationError.fromJson(json),
        );

        expect(handler.failure.errorData, isNotNull);
        expect(handler.failure.errorData?.field, equals('email'));
        expect(handler.failure.errorData?.message, equals('Invalid email format'));
      });

      test('handles parsing errors gracefully', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 400,
            data: {'invalid': 'structure'}, // Won't match ValidationError
          ),
        );

        final handler = ErrorHandler<ValidationError>.handle(
          error,
          parseError: (json) => ValidationError.fromJson(json),
        );

        // Should not crash, errorData should be null
        expect(handler.failure.errorData, isNull);
        expect(handler.failure.code, equals(ResponseCode.BAD_REQUEST));
      });

      test('ignores custom parser when response data is not a map', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 400,
            data: 'Plain text error',
          ),
        );

        final handler = ErrorHandler<ValidationError>.handle(
          error,
          parseError: (json) => ValidationError.fromJson(json),
        );

        expect(handler.failure.errorData, isNull);
      });

      test('works without custom parser', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 400,
            data: {'field': 'email', 'message': 'Invalid'},
          ),
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.errorData, isNull);
        expect(handler.failure.code, equals(ResponseCode.BAD_REQUEST));
      });
    });

    group('Non-Dio Exception Handling', () {
      test('handles generic exception', () {
        final error = Exception('Something went wrong');

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNKNOWN));
        expect(handler.failure.message, equals(ResponseMessage.UNKNOWN));
      });

      test('handles Error', () {
        final error = ArgumentError('Invalid argument');

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNKNOWN));
        expect(handler.failure.message, equals(ResponseMessage.UNKNOWN));
      });

      test('handles String', () {
        const error = 'Error string';

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.code, equals(ResponseCode.UNKNOWN));
        expect(handler.failure.message, equals(ResponseMessage.UNKNOWN));
      });
    });

    group('ErrorHandler as Exception', () {
      test('implements Exception interface', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler, isA<Exception>());
      });

      test('can be thrown and caught', () {
        expect(
              () {
            final error = DioException(
              requestOptions: RequestOptions(path: '/test'),
              type: DioExceptionType.connectionTimeout,
            );
            throw ErrorHandler<dynamic>.handle(error);
          },
          throwsA(isA<ErrorHandler<dynamic>>()),
        );
      });
    });

    group('Real World Scenarios', () {
      test('handles validation error with field-specific messages', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/register'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/register'),
            statusCode: 422,
            data: {
              'errors': {
                'email': ['Email is already taken'],
                'password': ['Password is too short'],
              },
            },
          ),
        );

        final handler = ErrorHandler<RegistrationError>.handle(
          error,
          parseError: (json) => RegistrationError.fromJson(json),
        );

        expect(handler.failure.code, equals(ResponseCode.UNPROCESSABLE_ENTITY));
        expect(handler.failure.errorData?.errors, isNotNull);
        expect(handler.failure.errorData?.errors?['email'], isNotNull);
      });

      test('handles network timeout in production scenario', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/api/users'),
          type: DioExceptionType.receiveTimeout,
          message: 'Request timeout after 30 seconds',
        );

        final handler = ErrorHandler<dynamic>.handle(error);

        expect(handler.failure.isNetworkError, isTrue);
        expect(handler.failure.code, equals(ResponseCode.RECEIVE_TIMEOUT));
      });

      test('handles server error with custom error response', () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/api/payment'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/payment'),
            statusCode: 500,
            data: {
              'error_code': 'PAYMENT_GATEWAY_ERROR',
              'message': 'Payment gateway temporarily unavailable',
              'retry_after': 300,
            },
          ),
        );

        final handler = ErrorHandler<PaymentError>.handle(
          error,
          parseError: (json) => PaymentError.fromJson(json),
        );

        expect(handler.failure.isServerError, isTrue);
        expect(handler.failure.errorData?.errorCode, equals('PAYMENT_GATEWAY_ERROR'));
        expect(handler.failure.errorData?.retryAfter, equals(300));
      });
    });
  });
}

// Helper classes for testing custom error types
class ValidationError {
  final String field;
  final String message;

  ValidationError({required this.field, required this.message});

  factory ValidationError.fromJson(Map<String, dynamic> json) {
    return ValidationError(
      field: json['field'] as String,
      message: json['message'] as String,
    );
  }
}

class RegistrationError {
  final Map<String, List<String>>? errors;

  RegistrationError({this.errors});

  factory RegistrationError.fromJson(Map<String, dynamic> json) {
    final errorsMap = json['errors'] as Map<String, dynamic>?;
    final parsedErrors = errorsMap?.map(
          (key, value) => MapEntry(key, List<String>.from(value as List)),
    );
    return RegistrationError(errors: parsedErrors);
  }
}

class PaymentError {
  final String errorCode;
  final String message;
  final int retryAfter;

  PaymentError({
    required this.errorCode,
    required this.message,
    required this.retryAfter,
  });

  factory PaymentError.fromJson(Map<String, dynamic> json) {
    return PaymentError(
      errorCode: json['error_code'] as String,
      message: json['message'] as String,
      retryAfter: json['retry_after'] as int,
    );
  }
}