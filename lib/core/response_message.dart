/// Human-readable error messages for response codes
class ResponseMessage {
  // Success messages
  static const String SUCCESS = 'Success';

  // Client error messages
  static const String BAD_REQUEST = 'Bad request. Please check your input.';
  static const String UNAUTHORISED = 'Unauthorized. Please login again.';
  static const String FORBIDDEN = 'Forbidden. You don\'t have permission.';
  static const String NOT_FOUND = 'Resource not found.';
  static const String METHOD_NOT_ALLOWED = 'Method not allowed.';
  static const String CONFLICT = 'Conflict. Resource already exists.';
  static const String UNPROCESSABLE_ENTITY = 'Validation failed.';

  // Server error messages
  static const String INTERNAL_SERVER_ERROR =
      'Internal server error. Please try again later.';
  static const String NOT_IMPLEMENTED = 'Feature not implemented yet.';
  static const String BAD_GATEWAY = 'Bad gateway. Please try again.';
  static const String SERVICE_UNAVAILABLE =
      'Service temporarily unavailable. Please try again later.';
  static const String GATEWAY_TIMEOUT = 'Gateway timeout. Please try again.';

  // Network error messages
  static const String NO_INTERNET_CONNECTION =
      'No internet connection. Please check your network.';
  static const String SEND_TIMEOUT =
      'Request timeout. Please check your connection.';
  static const String RECEIVE_TIMEOUT =
      'Response timeout. Please check your connection.';
  static const String CONNECT_TIMEOUT =
      'Connection timeout. Please check your connection.';
  static const String CANCEL = 'Request was cancelled.';
  static const String BAD_CERTIFICATE =
      'Certificate verification failed. Please check your security settings.';
  static const String UNKNOWN = 'Something went wrong. Please try again.';

  ResponseMessage._();
}
