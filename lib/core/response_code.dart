/// Standard HTTP and network error codes
class ResponseCode {
  // Success codes
  static const int SUCCESS = 200;
  static const int CREATED = 201;
  static const int ACCEPTED = 202;
  static const int NO_CONTENT = 204;

  // Client error codes
  static const int BAD_REQUEST = 400;
  static const int UNAUTHORISED = 401;
  static const int FORBIDDEN = 403;
  static const int NOT_FOUND = 404;
  static const int METHOD_NOT_ALLOWED = 405;
  static const int CONFLICT = 409;
  static const int UNPROCESSABLE_ENTITY = 422;

  // Server error codes
  static const int INTERNAL_SERVER_ERROR = 500;
  static const int NOT_IMPLEMENTED = 501;
  static const int BAD_GATEWAY = 502;
  static const int SERVICE_UNAVAILABLE = 503;
  static const int GATEWAY_TIMEOUT = 504;

  // Network error codes (custom negative codes)
  static const int NO_INTERNET_CONNECTION = -2;
  static const int SEND_TIMEOUT = -5;
  static const int RECEIVE_TIMEOUT = -6;
  static const int CONNECTION_TIMEOUT = -7;
  static const int CANCEL = -8;
  static const int BAD_CERTIFICATE = -9;
  static const int UNKNOWN = -1;

  ResponseCode._();
}