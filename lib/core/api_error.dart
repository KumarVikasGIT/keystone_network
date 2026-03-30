/// Type-safe error hierarchy for keystone_network
///
/// Replaces generic FailureResponse with structured error types
/// so screens can respond specifically to each error kind.
///
/// Example:
/// ```dart
/// result.when(
///   failed: (error) => switch (error) {
///     ValidationError(:final fields) => showFieldErrors(fields),
///     UnauthorizedError()            => redirectToLogin(),
///     ServerError(:final statusCode) => showServerError(statusCode),
///     _                              => showGenericError(error.message),
///   },
///   networkError: (_) => showNoInternet(),
///   success: (data)   => render(data),
///   loading: ()       => shimmer(),
///   idle: ()          => const SizedBox.shrink(),
/// );
/// ```
sealed class ApiError {
  const ApiError();

  /// Human-readable description of the error
  String get message;

  // ── Network ──────────────────────────────────────────────────────────────

  /// No internet / connection refused / connection reset
  const factory ApiError.network({String? message}) = NetworkError;

  /// Connection / send / receive timeout
  const factory ApiError.timeout() = TimeoutError;

  /// SSL / TLS certificate verification failure
  const factory ApiError.badCertificate() = BadCertificateError;

  /// Request was cancelled via CancelToken
  const factory ApiError.cancelled() = CancelledError;

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// 401 – token missing, expired, or invalid
  const factory ApiError.unauthorized() = UnauthorizedError;

  /// 403 – authenticated but not permitted
  const factory ApiError.forbidden() = ForbiddenError;

  // ── Client ───────────────────────────────────────────────────────────────

  /// 400 – malformed request
  const factory ApiError.badRequest({String? message}) = BadRequestError;

  /// 404 – resource not found
  const factory ApiError.notFound() = NotFoundError;

  /// 405 – HTTP method not allowed
  const factory ApiError.methodNotAllowed() = MethodNotAllowedError;

  /// 409 – resource conflict
  const factory ApiError.conflict({String? message}) = ConflictError;

  /// 422 – validation failed; [fields] maps field name → list of messages
  const factory ApiError.validation({
    required Map<String, List<String>> fields,
    String? message,
  }) = ValidationError;

  // ── Server ───────────────────────────────────────────────────────────────

  /// 5xx – server-side failure
  const factory ApiError.server({int? statusCode, String? message}) =
  ServerError;

  // ── Misc ─────────────────────────────────────────────────────────────────

  /// Application-level / custom error
  const factory ApiError.app({required String message}) = AppError;

  /// Unknown / unclassified error
  const factory ApiError.unknown({String? message}) = UnknownError;
}

// ── Network errors ──────────────────────────────────────────────────────────

final class NetworkError extends ApiError {
  final String? _message;
  const NetworkError({String? message}) : _message = message;

  @override
  String get message =>
      _message ?? 'No internet connection. Please check your network.';

  @override
  String toString() => 'ApiError.network(message: $message)';
}

final class TimeoutError extends ApiError {
  const TimeoutError();

  @override
  String get message => 'Request timed out. Please check your connection.';

  @override
  String toString() => 'ApiError.timeout()';
}

final class BadCertificateError extends ApiError {
  const BadCertificateError();

  @override
  String get message =>
      'Certificate verification failed. Please check your security settings.';

  @override
  String toString() => 'ApiError.badCertificate()';
}

final class CancelledError extends ApiError {
  const CancelledError();

  @override
  String get message => 'Request was cancelled.';

  @override
  String toString() => 'ApiError.cancelled()';
}

// ── Auth errors ─────────────────────────────────────────────────────────────

final class UnauthorizedError extends ApiError {
  const UnauthorizedError();

  @override
  String get message => 'Unauthorized. Please login again.';

  @override
  String toString() => 'ApiError.unauthorized()';
}

final class ForbiddenError extends ApiError {
  const ForbiddenError();

  @override
  String get message => "Forbidden. You don't have permission.";

  @override
  String toString() => 'ApiError.forbidden()';
}

// ── Client errors ───────────────────────────────────────────────────────────

final class BadRequestError extends ApiError {
  final String? _message;
  const BadRequestError({String? message}) : _message = message;

  @override
  String get message => _message ?? 'Bad request. Please check your input.';

  @override
  String toString() => 'ApiError.badRequest(message: $message)';
}

final class NotFoundError extends ApiError {
  const NotFoundError();

  @override
  String get message => 'Resource not found.';

  @override
  String toString() => 'ApiError.notFound()';
}

final class MethodNotAllowedError extends ApiError {
  const MethodNotAllowedError();

  @override
  String get message => 'Method not allowed.';

  @override
  String toString() => 'ApiError.methodNotAllowed()';
}

final class ConflictError extends ApiError {
  final String? _message;
  const ConflictError({String? message}) : _message = message;

  @override
  String get message => _message ?? 'Conflict. Resource already exists.';

  @override
  String toString() => 'ApiError.conflict(message: $message)';
}

final class ValidationError extends ApiError {
  /// Field-level validation messages, e.g. {'email': ['Invalid format']}
  final Map<String, List<String>> fields;
  final String? _message;

  const ValidationError({required this.fields, String? message})
      : _message = message;

  @override
  String get message => _message ?? 'Validation failed.';

  /// Flat list of all validation messages across all fields
  List<String> get allMessages =>
      fields.values.expand((msgs) => msgs).toList();

  /// First message for a specific field, or null
  String? fieldMessage(String field) => fields[field]?.firstOrNull;

  @override
  String toString() =>
      'ApiError.validation(fields: $fields, message: $message)';
}

// ── Server errors ───────────────────────────────────────────────────────────

final class ServerError extends ApiError {
  final int? statusCode;
  final String? _message;

  const ServerError({this.statusCode, String? message}) : _message = message;

  @override
  String get message =>
      _message ?? 'Internal server error. Please try again later.';

  @override
  String toString() =>
      'ApiError.server(statusCode: $statusCode, message: $message)';
}

// ── Misc ────────────────────────────────────────────────────────────────────

final class AppError extends ApiError {
  final String _message;
  const AppError({required String message}) : _message = message;

  @override
  String get message => _message;

  @override
  String toString() => 'ApiError.app(message: $message)';
}

final class UnknownError extends ApiError {
  final String? _message;
  const UnknownError({String? message}) : _message = message;

  @override
  String get message => _message ?? 'Something went wrong. Please try again.';

  @override
  String toString() => 'ApiError.unknown(message: $message)';
}

// ── Convenience extensions ───────────────────────────────────────────────────

extension ApiErrorX on ApiError {
  /// True for any connectivity-related error (NetworkError, TimeoutError,
  /// BadCertificateError, CancelledError)
  bool get isNetworkRelated =>
      this is NetworkError ||
          this is TimeoutError ||
          this is BadCertificateError ||
          this is CancelledError;

  /// True for auth errors (401 / 403)
  bool get isAuthError => this is UnauthorizedError || this is ForbiddenError;

  /// True for any 4xx client error
  bool get isClientError =>
      this is BadRequestError ||
          this is UnauthorizedError ||
          this is ForbiddenError ||
          this is NotFoundError ||
          this is MethodNotAllowedError ||
          this is ConflictError ||
          this is ValidationError;

  /// True for any 5xx server error
  bool get isServerError => this is ServerError;

  /// Exhaustive pattern-match helper
  R when<R>({
    required R Function(NetworkError e) network,
    required R Function(TimeoutError e) timeout,
    required R Function(BadCertificateError e) badCertificate,
    required R Function(CancelledError e) cancelled,
    required R Function(UnauthorizedError e) unauthorized,
    required R Function(ForbiddenError e) forbidden,
    required R Function(BadRequestError e) badRequest,
    required R Function(NotFoundError e) notFound,
    required R Function(MethodNotAllowedError e) methodNotAllowed,
    required R Function(ConflictError e) conflict,
    required R Function(ValidationError e) validation,
    required R Function(ServerError e) server,
    required R Function(AppError e) app,
    required R Function(UnknownError e) unknown,
  }) =>
      switch (this) {
        NetworkError e        => network(e),
        TimeoutError e        => timeout(e),
        BadCertificateError e => badCertificate(e),
        CancelledError e      => cancelled(e),
        UnauthorizedError e   => unauthorized(e),
        ForbiddenError e      => forbidden(e),
        BadRequestError e     => badRequest(e),
        NotFoundError e       => notFound(e),
        MethodNotAllowedError e => methodNotAllowed(e),
        ConflictError e       => conflict(e),
        ValidationError e     => validation(e),
        ServerError e         => server(e),
        AppError e            => app(e),
        UnknownError e        => unknown(e),
      };

  /// Partial match — handle what you care about, delegate the rest
  R maybeWhen<R>({
    R Function(NetworkError e)? network,
    R Function(TimeoutError e)? timeout,
    R Function(BadCertificateError e)? badCertificate,
    R Function(CancelledError e)? cancelled,
    R Function(UnauthorizedError e)? unauthorized,
    R Function(ForbiddenError e)? forbidden,
    R Function(BadRequestError e)? badRequest,
    R Function(NotFoundError e)? notFound,
    R Function(MethodNotAllowedError e)? methodNotAllowed,
    R Function(ConflictError e)? conflict,
    R Function(ValidationError e)? validation,
    R Function(ServerError e)? server,
    R Function(AppError e)? app,
    R Function(UnknownError e)? unknown,
    required R Function(ApiError e) orElse,
  }) =>
      switch (this) {
        NetworkError e        => network?.call(e) ?? orElse(this),
        TimeoutError e        => timeout?.call(e) ?? orElse(this),
        BadCertificateError e => badCertificate?.call(e) ?? orElse(this),
        CancelledError e      => cancelled?.call(e) ?? orElse(this),
        UnauthorizedError e   => unauthorized?.call(e) ?? orElse(this),
        ForbiddenError e      => forbidden?.call(e) ?? orElse(this),
        BadRequestError e     => badRequest?.call(e) ?? orElse(this),
        NotFoundError e       => notFound?.call(e) ?? orElse(this),
        MethodNotAllowedError e => methodNotAllowed?.call(e) ?? orElse(this),
        ConflictError e       => conflict?.call(e) ?? orElse(this),
        ValidationError e     => validation?.call(e) ?? orElse(this),
        ServerError e         => server?.call(e) ?? orElse(this),
        AppError e            => app?.call(e) ?? orElse(this),
        UnknownError e        => unknown?.call(e) ?? orElse(this),
      };
}