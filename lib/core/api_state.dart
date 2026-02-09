import 'failure_response.dart';

/// Represents the state of an API request
///
/// Type Parameters:
///   T - Success data type
///   E - Custom error type (optional)
///
/// States:
/// - idle: Initial state, no request made yet
/// - loading: Request in progress
/// - success: Request completed successfully with data
/// - failed: Request failed with error details
/// - networkError: Request failed due to network issues
///
/// Example:
/// ```dart
/// ApiState<User, LoginError> state = ApiState.idle();
///
/// state = ApiState.loading();
///
/// state = ApiState.success(user);
/// // or
/// state = ApiState.failed(FailureResponse(...));
/// // or
/// state = ApiState.networkError(FailureResponse(...));
///
/// // Pattern matching
/// state.when(
///   idle: () => Text('Ready'),
///   loading: () => CircularProgressIndicator(),
///   success: (user) => UserProfile(user),
///   failed: (error) => ErrorWidget(error.message),
///   networkError: (error) => NoInternetWidget(),
/// );
/// ```
sealed class ApiState<T, E> {
  const ApiState();

  /// Initial state - no request made yet
  const factory ApiState.idle() = IdleState<T, E>;

  /// Loading state - request in progress
  const factory ApiState.loading() = LoadingState<T, E>;

  /// Success state - request completed with data
  const factory ApiState.success(T data) = SuccessState<T, E>;

  /// Failed state - request failed with error
  const factory ApiState.failed(FailureResponse<E> error) = FailedState<T, E>;

  /// Network error state - request failed due to network issues
  const factory ApiState.networkError(FailureResponse<E> error) =
      NetworkErrorState<T, E>;

  /// Get data if in success state, null otherwise
  T? get data => switch (this) {
        SuccessState<T, E>(data: final d) => d,
        _ => null,
      };

  /// Get error if in failed/networkError state, null otherwise
  FailureResponse<E>? get error => switch (this) {
        FailedState<T, E>(error: final e) => e,
        NetworkErrorState<T, E>(error: final e) => e,
        _ => null,
      };

  /// Pattern matching for all states
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(FailureResponse<E> error) failed,
    required R Function(FailureResponse<E> error) networkError,
  }) {
    return switch (this) {
      IdleState<T, E>() => idle(),
      LoadingState<T, E>() => loading(),
      SuccessState<T, E>(data: final d) => success(d),
      FailedState<T, E>(error: final e) => failed(e),
      NetworkErrorState<T, E>(error: final e) => networkError(e),
    };
  }

  /// Pattern matching with optional handlers
  R maybeWhen<R>({
    R Function()? idle,
    R Function()? loading,
    R Function(T data)? success,
    R Function(FailureResponse<E> error)? failed,
    R Function(FailureResponse<E> error)? networkError,
    required R Function() orElse,
  }) {
    return switch (this) {
      IdleState<T, E>() => idle?.call() ?? orElse(),
      LoadingState<T, E>() => loading?.call() ?? orElse(),
      SuccessState<T, E>(data: final d) => success?.call(d) ?? orElse(),
      FailedState<T, E>(error: final e) => failed?.call(e) ?? orElse(),
      NetworkErrorState<T, E>(error: final e) =>
        networkError?.call(e) ?? orElse(),
    };
  }

  /// Map the success data to a new type
  ApiState<R, E> map<R>(R Function(T data) transform) {
    return switch (this) {
      IdleState<T, E>() => ApiState<R, E>.idle(),
      LoadingState<T, E>() => ApiState<R, E>.loading(),
      SuccessState<T, E>(data: final d) => ApiState<R, E>.success(transform(d)),
      FailedState<T, E>(error: final e) => ApiState<R, E>.failed(e),
      NetworkErrorState<T, E>(error: final e) => ApiState<R, E>.networkError(e),
    };
  }
}

/// Idle state - no request made yet
final class IdleState<T, E> extends ApiState<T, E> {
  const IdleState();

  @override
  String toString() => 'ApiState<$T, $E>.idle()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdleState<T, E>;

  @override
  int get hashCode => (T).hashCode ^ (E).hashCode ^ 0;
}

/// Loading state - request in progress
final class LoadingState<T, E> extends ApiState<T, E> {
  const LoadingState();

  @override
  String toString() => 'ApiState<$T, $E>.loading()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LoadingState<T, E>;

  @override
  int get hashCode => (T).hashCode ^ (E).hashCode ^ 1;
}

/// Success state - request completed with data
final class SuccessState<T, E> extends ApiState<T, E> {
  final T data;

  const SuccessState(this.data);

  @override
  String toString() => 'ApiState<$T, $E>.success($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SuccessState<T, E> && other.data == data);

  @override
  int get hashCode => data.hashCode ^ (T).hashCode ^ (E).hashCode ^ 2;
}

/// Failed state - request failed with error
final class FailedState<T, E> extends ApiState<T, E> {
  final FailureResponse<E> error;

  const FailedState(this.error);

  @override
  String toString() => 'ApiState<$T, $E>.failed($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FailedState<T, E> && other.error == error);

  @override
  int get hashCode => error.hashCode ^ (T).hashCode ^ (E).hashCode ^ 3;
}

/// Network error state - request failed due to network issues
final class NetworkErrorState<T, E> extends ApiState<T, E> {
  final FailureResponse<E> error;

  const NetworkErrorState(this.error);

  @override
  String toString() => 'ApiState<$T, $E>.networkError($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetworkErrorState<T, E> && other.error == error);

  @override
  int get hashCode => error.hashCode ^ (T).hashCode ^ (E).hashCode ^ 4;
}

/// Convenience extensions for ApiState
extension ApiStateConvenience<T, E> on ApiState<T, E> {
  /// Get data or null
  T? get dataOrNull => data;

  /// Get error or null
  FailureResponse<E>? get errorOrNull => error;

  /// Check if has data
  bool get hasData => data != null;

  /// Check if has error
  bool get hasError => error != null;

  /// Check if is idle
  bool get isIdle => this is IdleState<T, E>;

  /// Check if is loading
  bool get isLoading => this is LoadingState<T, E>;

  /// Check if is success
  bool get isSuccess => this is SuccessState<T, E>;

  /// Check if is failed
  bool get isFailed => this is FailedState<T, E>;

  /// Check if is network error
  bool get isNetworkError => this is NetworkErrorState<T, E>;

  /// Check if is any error state (failed or network error)
  bool get isError => isFailed || isNetworkError;
}
