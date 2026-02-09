import 'response_code.dart';

/// Represents a failed API response with error details
///
/// Type Parameters:
///   E - Custom error data type (optional)
///
/// **Equality Note:**
/// For proper equality comparison, your custom error type `E` should
/// implement `==` and `hashCode`. Otherwise, equality will use
/// reference comparison (identity).
///
/// Example with proper equality:
/// ```dart
/// class LoginError {
///   final String? email;
///   final String? password;
///
///   LoginError({this.email, this.password});
///
///   // ✅ Implement equality
///   @override
///   bool operator ==(Object other) =>
///     identical(this, other) ||
///     other is LoginError &&
///       other.email == email &&
///       other.password == password;
///
///   @override
///   int get hashCode => email.hashCode ^ password.hashCode;
/// }
///
/// // Now FailureResponse equality works correctly
/// final error1 = FailureResponse<LoginError>(
///   400,
///   'Validation failed',
///   errorData: LoginError(email: 'Invalid email'),
/// );
///
/// final error2 = FailureResponse<LoginError>(
///   400,
///   'Validation failed',
///   errorData: LoginError(email: 'Invalid email'),
/// );
///
/// print(error1 == error2); // true (because LoginError has equality)
/// ```
class FailureResponse<E> {
  /// Error code (HTTP status or custom code)
  final int code;

  /// Human-readable error message
  final String message;

  /// Optional custom error data
  ///
  /// **Note:** For equality to work correctly, E should
  /// implement proper `==` and `hashCode` operators.
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
        other.errorData == errorData; // Uses E's equality if implemented
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
