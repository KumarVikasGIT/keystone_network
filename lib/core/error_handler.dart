import 'package:dio/dio.dart';
import 'failure_response.dart';
import 'response_code.dart';
import 'response_message.dart';

/// Handles Dio exceptions and converts them to FailureResponse
///
/// Type Parameters:
///   E - Custom error data type (optional)
///
/// Example:
/// ```dart
/// try {
///   final response = await dio.get('/users');
/// } catch (error) {
///   final handler = ErrorHandler<LoginError>.handle(
///     error,
///     parseError: (json) => LoginError.fromJson(json),
///   );
///
///   print(handler.failure.message);
///   print(handler.failure.errorData?.email); // Type-safe!
/// }
/// ```
class ErrorHandler<E> implements Exception {
  late final FailureResponse<E> failure;

  ErrorHandler.handle(
    dynamic error, {
    E Function(Map<String, dynamic>)? parseError,
  }) {
    if (error is DioException) {
      failure = _handleDioError(error, parseError: parseError);
    } else {
      failure = FailureResponse<E>(
        ResponseCode.UNKNOWN,
        ResponseMessage.UNKNOWN,
      );
    }
  }

  FailureResponse<E> _handleDioError(
    DioException error, {
    E Function(Map<String, dynamic>)? parseError,
  }) {
    // Try to parse custom error if available
    E? customError;
    if (parseError != null && error.response?.data is Map<String, dynamic>) {
      try {
        customError = parseError(error.response!.data as Map<String, dynamic>);
      } catch (_) {
        // Parsing failed, continue without custom error
        // This is expected if the error response format doesn't match
      }
    }

    // Map DioExceptionType to FailureResponse
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return FailureResponse(
          ResponseCode.CONNECTION_TIMEOUT,
          ResponseMessage.CONNECT_TIMEOUT,
          errorData: customError,
        );

      case DioExceptionType.sendTimeout:
        return FailureResponse(
          ResponseCode.SEND_TIMEOUT,
          ResponseMessage.SEND_TIMEOUT,
          errorData: customError,
        );

      case DioExceptionType.receiveTimeout:
        return FailureResponse(
          ResponseCode.RECEIVE_TIMEOUT,
          ResponseMessage.RECEIVE_TIMEOUT,
          errorData: customError,
        );

      case DioExceptionType.badResponse:
        return _mapStatusToFailure(
          error.response?.statusCode ?? ResponseCode.UNKNOWN,
          customError,
        );

      case DioExceptionType.cancel:
        return FailureResponse(
          ResponseCode.CANCEL,
          ResponseMessage.CANCEL,
          errorData: customError,
        );

      case DioExceptionType.connectionError:
        return FailureResponse(
          ResponseCode.NO_INTERNET_CONNECTION,
          ResponseMessage.NO_INTERNET_CONNECTION,
          errorData: customError,
        );

      case DioExceptionType.badCertificate:
        return FailureResponse(
          ResponseCode.BAD_CERTIFICATE,
          ResponseMessage.BAD_CERTIFICATE,
          errorData: customError,
        );

      default:
        return FailureResponse(
          ResponseCode.UNKNOWN,
          ResponseMessage.UNKNOWN,
          errorData: customError,
        );
    }
  }

  FailureResponse<E> _mapStatusToFailure(int status, E? customError) {
    switch (status) {
      case 400:
        return FailureResponse(
          ResponseCode.BAD_REQUEST,
          ResponseMessage.BAD_REQUEST,
          errorData: customError,
        );
      case 401:
        return FailureResponse(
          ResponseCode.UNAUTHORISED,
          ResponseMessage.UNAUTHORISED,
          errorData: customError,
        );
      case 403:
        return FailureResponse(
          ResponseCode.FORBIDDEN,
          ResponseMessage.FORBIDDEN,
          errorData: customError,
        );
      case 404:
        return FailureResponse(
          ResponseCode.NOT_FOUND,
          ResponseMessage.NOT_FOUND,
          errorData: customError,
        );
      case 405:
        return FailureResponse(
          ResponseCode.METHOD_NOT_ALLOWED,
          ResponseMessage.METHOD_NOT_ALLOWED,
          errorData: customError,
        );
      case 409:
        return FailureResponse(
          ResponseCode.CONFLICT,
          ResponseMessage.CONFLICT,
          errorData: customError,
        );
      case 422:
        return FailureResponse(
          ResponseCode.UNPROCESSABLE_ENTITY,
          ResponseMessage.UNPROCESSABLE_ENTITY,
          errorData: customError,
        );
      case 500:
        return FailureResponse(
          ResponseCode.INTERNAL_SERVER_ERROR,
          ResponseMessage.INTERNAL_SERVER_ERROR,
          errorData: customError,
        );
      case 501:
        return FailureResponse(
          ResponseCode.NOT_IMPLEMENTED,
          ResponseMessage.NOT_IMPLEMENTED,
          errorData: customError,
        );
      case 502:
        return FailureResponse(
          ResponseCode.BAD_GATEWAY,
          ResponseMessage.BAD_GATEWAY,
          errorData: customError,
        );
      case 503:
        return FailureResponse(
          ResponseCode.SERVICE_UNAVAILABLE,
          ResponseMessage.SERVICE_UNAVAILABLE,
          errorData: customError,
        );
      case 504:
        return FailureResponse(
          ResponseCode.GATEWAY_TIMEOUT,
          ResponseMessage.GATEWAY_TIMEOUT,
          errorData: customError,
        );
      default:
        return FailureResponse(
          ResponseCode.UNKNOWN,
          ResponseMessage.UNKNOWN,
          errorData: customError,
        );
    }
  }
}
