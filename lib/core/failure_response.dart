import 'response_code.dart';

/// Represents a failed API response with error details
///
/// Type Parameters:
///   E - Custom error data type (optional)
///
/// Example:
/// ```dart
/// // Generic failure
/// final failure = FailureResponse<dynamic>(
///   ResponseCode.NOT_FOUND,
///   'User not found',
/// );
///
/// // With custom error data
/// final failure = FailureResponse<LoginError>(
///   ResponseCode.BAD_REQUEST,
///   'Validation failed',
///   errorData: LoginError(email: 'Invalid email'),
/// );
/// ```
class FailureResponse<E> {
  /// Error code (HTTP status or custom code)
  final int code;

  /// Human-readable error message
  final String message;

  /// Optional custom error data
  final E? errorData;

  const FailureResponse(
    this.code,
    this.message, {
    this.errorData,
  });

  @override
  String toString() {
    return 'FailureResponse(code: $code, message: $message${errorData != null ? ', errorData: $errorData' : ''})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FailureResponse<E> &&
        other.code == code &&
        other.message == message &&
        other.errorData == errorData;
  }

  @override
  int get hashCode => code.hashCode ^ message.hashCode ^ errorData.hashCode;
}

/// Extensions for FailureResponse to provide additional utilities
extension FailureResponseExtensions<E> on FailureResponse<E> {
  /// Check if this is a network-related error
  ///
  /// Returns true for:
  /// - Connection timeout
  /// - No internet connection
  /// - Receive timeout
  /// - Send timeout
  ///
  /// Example:
  /// ```dart
  /// if (failure.isNetworkError) {
  ///   showNoInternetDialog();
  /// }
  /// ```
  bool get isNetworkError =>
      code == ResponseCode.CONNECTION_TIMEOUT ||
      code == ResponseCode.NO_INTERNET_CONNECTION ||
      code == ResponseCode.RECEIVE_TIMEOUT ||
      code == ResponseCode.SEND_TIMEOUT;

  /// Check if this is a client error (4xx)
  bool get isClientError => code >= 400 && code < 500;

  /// Check if this is a server error (5xx)
  bool get isServerError => code >= 500 && code < 600;

  /// Check if this is an authentication error
  bool get isAuthError =>
      code == ResponseCode.UNAUTHORISED || code == ResponseCode.FORBIDDEN;

  /// Check if this is a validation error
  bool get isValidationError => code == ResponseCode.BAD_REQUEST;
}
