import 'package:dio/dio.dart';
import 'failure_response.dart';
import 'response_code.dart';
import 'response_message.dart';
import 'api_error.dart';

/// Handles Dio exceptions and converts them to [FailureResponse].
///
/// Also exposes [apiError] for the type-safe [ApiError] hierarchy.
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
///   // Legacy
///   print(handler.failure.message);
///
///   // Type-safe
///   switch (handler.apiError) {
///     case ValidationError(:final fields) => showFieldErrors(fields),
///     case UnauthorizedError()            => redirectToLogin(),
///     case ServerError(:final statusCode) => showServerError(statusCode),
///     _                                   => showGenericError(),
///   }
/// }
/// ```
class ErrorHandler<E> implements Exception {
  late final FailureResponse<E> failure;

  /// Type-safe error representation – use this on new screens.
  late final ApiError apiError;

  ErrorHandler.handle(
      dynamic error, {
        E Function(Map<String, dynamic>)? parseError,
      }) {
    if (error is DioException) {
      failure  = _handleDioError(error, parseError: parseError);
      apiError = _toApiError(error);
    } else {
      failure = FailureResponse<E>(
        ResponseCode.UNKNOWN,
        ResponseMessage.UNKNOWN,
      );
      apiError = ApiError.unknown(message: error?.toString());
    }
  }

  // ── FailureResponse mapping ───────────────────────────────────────────────

  FailureResponse<E> _handleDioError(
      DioException error, {
        E Function(Map<String, dynamic>)? parseError,
      }) {
    E? customError;
    if (parseError != null && error.response?.data is Map<String, dynamic>) {
      try {
        customError = parseError(error.response!.data as Map<String, dynamic>);
      } catch (_) {}
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return FailureResponse(ResponseCode.CONNECTION_TIMEOUT,
            ResponseMessage.CONNECT_TIMEOUT,
            errorData: customError);

      case DioExceptionType.sendTimeout:
        return FailureResponse(ResponseCode.SEND_TIMEOUT,
            ResponseMessage.SEND_TIMEOUT,
            errorData: customError);

      case DioExceptionType.receiveTimeout:
        return FailureResponse(ResponseCode.RECEIVE_TIMEOUT,
            ResponseMessage.RECEIVE_TIMEOUT,
            errorData: customError);

      case DioExceptionType.badResponse:
        return _mapStatusToFailure(
          error.response?.statusCode ?? ResponseCode.UNKNOWN,
          customError,
          error,
        );

      case DioExceptionType.cancel:
        return FailureResponse(ResponseCode.CANCEL, ResponseMessage.CANCEL,
            errorData: customError);

      case DioExceptionType.connectionError:
        return FailureResponse(ResponseCode.NO_INTERNET_CONNECTION,
            ResponseMessage.NO_INTERNET_CONNECTION,
            errorData: customError);

      case DioExceptionType.badCertificate:
        return FailureResponse(ResponseCode.BAD_CERTIFICATE,
            ResponseMessage.BAD_CERTIFICATE,
            errorData: customError);

      default:
        return FailureResponse(ResponseCode.UNKNOWN, ResponseMessage.UNKNOWN,
            errorData: customError);
    }
  }

  FailureResponse<E> _mapStatusToFailure(
      int status,
      E? customError,
      DioException error,
      ) {
    return switch (status) {
      400 => FailureResponse(ResponseCode.BAD_REQUEST,
          _extractMessage(error) ?? ResponseMessage.BAD_REQUEST,
          errorData: customError),
      401 => FailureResponse(ResponseCode.UNAUTHORISED, ResponseMessage.UNAUTHORISED,
          errorData: customError),
      403 => FailureResponse(ResponseCode.FORBIDDEN, ResponseMessage.FORBIDDEN,
          errorData: customError),
      404 => FailureResponse(ResponseCode.NOT_FOUND, ResponseMessage.NOT_FOUND,
          errorData: customError),
      405 => FailureResponse(ResponseCode.METHOD_NOT_ALLOWED,
          ResponseMessage.METHOD_NOT_ALLOWED,
          errorData: customError),
      409 => FailureResponse(ResponseCode.CONFLICT,
          _extractMessage(error) ?? ResponseMessage.CONFLICT,
          errorData: customError),
      422 => FailureResponse(ResponseCode.UNPROCESSABLE_ENTITY,
          ResponseMessage.UNPROCESSABLE_ENTITY,
          errorData: customError),
      500 => FailureResponse(ResponseCode.INTERNAL_SERVER_ERROR,
          ResponseMessage.INTERNAL_SERVER_ERROR,
          errorData: customError),
      501 => FailureResponse(ResponseCode.NOT_IMPLEMENTED,
          ResponseMessage.NOT_IMPLEMENTED,
          errorData: customError),
      502 => FailureResponse(ResponseCode.BAD_GATEWAY, ResponseMessage.BAD_GATEWAY,
          errorData: customError),
      503 => FailureResponse(ResponseCode.SERVICE_UNAVAILABLE,
          ResponseMessage.SERVICE_UNAVAILABLE,
          errorData: customError),
      504 => FailureResponse(ResponseCode.GATEWAY_TIMEOUT,
          ResponseMessage.GATEWAY_TIMEOUT,
          errorData: customError),
      _ => FailureResponse(ResponseCode.UNKNOWN, ResponseMessage.UNKNOWN,
          errorData: customError),
    };
  }

  // ── ApiError mapping ──────────────────────────────────────────────────────

  ApiError _toApiError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiError.timeout();

      case DioExceptionType.connectionError:
        return const ApiError.network();

      case DioExceptionType.badCertificate:
        return const ApiError.badCertificate();

      case DioExceptionType.cancel:
        return const ApiError.cancelled();

      case DioExceptionType.badResponse:
        return _statusToApiError(error);

      default:
        return ApiError.unknown(message: error.message);
    }
  }

  ApiError _statusToApiError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;

    return switch (status) {
      400 => ApiError.badRequest(message: _extractMessage(error)),
      401 => const ApiError.unauthorized(),
      403 => const ApiError.forbidden(),
      404 => const ApiError.notFound(),
      405 => const ApiError.methodNotAllowed(),
      409 => ApiError.conflict(message: _extractMessage(error)),
      422 => ApiError.validation(
        fields: _extractValidationFields(data),
        message: _extractMessage(error),
      ),
      int s when s >= 500 && s < 600 =>
          ApiError.server(statusCode: s, message: _extractMessage(error)),
      _ => ApiError.unknown(message: error.message),
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'] ?? data['error'] ?? data['detail'];
      if (msg is String) return msg;
    }
    return null;
  }

  /// Extracts field-level validation errors from a 422 response.
  ///
  /// Handles common shapes:
  /// - `{"errors": {"email": ["Invalid format"]}}`
  /// - `{"fields": {"email": ["Invalid format"]}}`
  /// - `{"email": ["Invalid format"]}` (flat map)
  Map<String, List<String>> _extractValidationFields(dynamic data) {
    if (data is! Map<String, dynamic>) return {};

    // Try common wrapper keys first
    for (final key in ['errors', 'fields', 'validation_errors']) {
      final inner = data[key];
      if (inner is Map<String, dynamic>) {
        return _normaliseFieldMap(inner);
      }
    }

    // Flat map: each key maps to a list of strings
    return _normaliseFieldMap(data);
  }

  Map<String, List<String>> _normaliseFieldMap(Map<String, dynamic> raw) {
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is List) {
        result[entry.key] = v.map((e) => e.toString()).toList();
      } else if (v is String) {
        result[entry.key] = [v];
      }
    }
    return result;
  }
}