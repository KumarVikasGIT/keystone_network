import 'package:flutter/widgets.dart';
import '../core/failure_response.dart';

/// Represents the state of an API request
///
/// Type Parameters:
///   T - Success data type
///   E - Custom error type (optional, defaults to ApiError)
///
/// States:
/// - idle:         Initial state, no request made yet
/// - loading:      Request in progress
/// - success:      Request completed successfully with data
/// - empty:        Request succeeded but data is empty (list/null)
/// - failed:       Request failed with error details
/// - networkError: Request failed due to network issues
///
/// Example:
/// ```dart
/// ApiState<List<Gallery>, ApiError> state = ApiState.idle();
///
/// // Pattern matching
/// state.when(
///   idle:         ()        => const SizedBox.shrink(),
///   loading:      ()        => const GalleryShimmer(),
///   success:      (items)   => GalleryGrid(items),
///   empty:        ()        => const EmptyGalleries(),
///   failed:       (error)   => ErrorView(error.message),
///   networkError: (error)   => const NoInternetView(),
/// );
///
/// // Or use the UI helper
/// state.buildWidget(
///   loading:      ()        => const GalleryShimmer(),
///   success:      (items)   => GalleryGrid(items),
///   empty:        ()        => const EmptyGalleries(),
///   error:        (msg)     => ErrorView(msg, onRetry: _reload),
///   networkError: ()        => NoInternetView(onRetry: _reload),
/// );
/// ```
sealed class ApiState<T, E> {
  const ApiState();

  // ── Factories ──────────────────────────────────────────────────────────

  /// Initial state – no request made yet
  const factory ApiState.idle() = IdleState<T, E>;

  /// Loading state – request in progress
  const factory ApiState.loading() = LoadingState<T, E>;

  /// Success state – request completed with data
  const factory ApiState.success(T data) = SuccessState<T, E>;

  /// Empty state – request succeeded but data is empty
  /// (auto-emitted by ApiExecutor when emptyCheck returns true)
  const factory ApiState.empty() = EmptyState<T, E>;

  /// Failed state – request failed with structured error
  const factory ApiState.failed(FailureResponse<E> error) = FailedState<T, E>;

  /// Network error state – request failed due to connectivity issues
  const factory ApiState.networkError(FailureResponse<E> error) =
  NetworkErrorState<T, E>;

  // ── Data accessors ─────────────────────────────────────────────────────

  /// Success data, or null if not in success state
  T? get data => switch (this) {
    SuccessState<T, E>(data: final d) => d,
    _ => null,
  };

  /// Error payload for failed / networkError states, null otherwise
  FailureResponse<E>? get error => switch (this) {
    FailedState<T, E>(error: final e) => e,
    NetworkErrorState<T, E>(error: final e) => e,
    _ => null,
  };

  // ── Pattern matching ───────────────────────────────────────────────────

  /// Exhaustive pattern match over all states
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(T data) success,
    required R Function() empty,
    required R Function(FailureResponse<E> error) failed,
    required R Function(FailureResponse<E> error) networkError,
  }) {
    return switch (this) {
      IdleState<T, E>()                       => idle(),
      LoadingState<T, E>()                    => loading(),
      SuccessState<T, E>(data: final d)       => success(d),
      EmptyState<T, E>()                      => empty(),
      FailedState<T, E>(error: final e)       => failed(e),
      NetworkErrorState<T, E>(error: final e) => networkError(e),
    };
  }

  /// Partial pattern match – unhandled states fall through to [orElse]
  R maybeWhen<R>({
    R Function()? idle,
    R Function()? loading,
    R Function(T data)? success,
    R Function()? empty,
    R Function(FailureResponse<E> error)? failed,
    R Function(FailureResponse<E> error)? networkError,
    required R Function() orElse,
  }) {
    return switch (this) {
      IdleState<T, E>()                       => idle?.call() ?? orElse(),
      LoadingState<T, E>()                    => loading?.call() ?? orElse(),
      SuccessState<T, E>(data: final d)       => success?.call(d) ?? orElse(),
      EmptyState<T, E>()                      => empty?.call() ?? orElse(),
      FailedState<T, E>(error: final e)       => failed?.call(e) ?? orElse(),
      NetworkErrorState<T, E>(error: final e) =>
      networkError?.call(e) ?? orElse(),
    };
  }

  /// Map success data to a different type, preserving all other states
  ApiState<R, E> map<R>(R Function(T data) transform) {
    return switch (this) {
      IdleState<T, E>()                       => ApiState<R, E>.idle(),
      LoadingState<T, E>()                    => ApiState<R, E>.loading(),
      SuccessState<T, E>(data: final d)       => ApiState<R, E>.success(transform(d)),
      EmptyState<T, E>()                      => ApiState<R, E>.empty(),
      FailedState<T, E>(error: final e)       => ApiState<R, E>.failed(e),
      NetworkErrorState<T, E>(error: final e) => ApiState<R, E>.networkError(e),
    };
  }
}

// ── Concrete state classes ──────────────────────────────────────────────────

final class IdleState<T, E> extends ApiState<T, E> {
  const IdleState();
  @override String toString() => 'ApiState<$T,$E>.idle()';
  @override bool operator ==(Object o) => identical(this, o) || o is IdleState<T, E>;
  @override int get hashCode => (T).hashCode ^ (E).hashCode ^ 0;
}

final class LoadingState<T, E> extends ApiState<T, E> {
  const LoadingState();
  @override String toString() => 'ApiState<$T,$E>.loading()';
  @override bool operator ==(Object o) => identical(this, o) || o is LoadingState<T, E>;
  @override int get hashCode => (T).hashCode ^ (E).hashCode ^ 1;
}

final class SuccessState<T, E> extends ApiState<T, E> {
  final T data;
  const SuccessState(this.data);
  @override String toString() => 'ApiState<$T,$E>.success($data)';
  @override bool operator ==(Object o) =>
      identical(this, o) || (o is SuccessState<T, E> && o.data == data);
  @override int get hashCode => data.hashCode ^ (T).hashCode ^ (E).hashCode ^ 2;
}

/// Empty state – request succeeded but returned no data
final class EmptyState<T, E> extends ApiState<T, E> {
  const EmptyState();
  @override String toString() => 'ApiState<$T,$E>.empty()';
  @override bool operator ==(Object o) => identical(this, o) || o is EmptyState<T, E>;
  @override int get hashCode => (T).hashCode ^ (E).hashCode ^ 5;
}

final class FailedState<T, E> extends ApiState<T, E> {
  final FailureResponse<E> error;
  const FailedState(this.error);
  @override String toString() => 'ApiState<$T,$E>.failed($error)';
  @override bool operator ==(Object o) =>
      identical(this, o) || (o is FailedState<T, E> && o.error == error);
  @override int get hashCode => error.hashCode ^ (T).hashCode ^ (E).hashCode ^ 3;
}

final class NetworkErrorState<T, E> extends ApiState<T, E> {
  final FailureResponse<E> error;
  const NetworkErrorState(this.error);
  @override String toString() => 'ApiState<$T,$E>.networkError($error)';
  @override bool operator ==(Object o) =>
      identical(this, o) || (o is NetworkErrorState<T, E> && o.error == error);
  @override int get hashCode => error.hashCode ^ (T).hashCode ^ (E).hashCode ^ 4;
}

// ── Convenience extensions ──────────────────────────────────────────────────

extension ApiStateConvenience<T, E> on ApiState<T, E> {
  T? get dataOrNull       => data;
  FailureResponse<E>? get errorOrNull => error;

  bool get hasData        => data != null;
  bool get hasError       => error != null;

  bool get isIdle         => this is IdleState<T, E>;
  bool get isLoading      => this is LoadingState<T, E>;
  bool get isSuccess      => this is SuccessState<T, E>;
  bool get isEmpty        => this is EmptyState<T, E>;
  bool get isFailed       => this is FailedState<T, E>;
  bool get isNetworkError => this is NetworkErrorState<T, E>;

  /// True for any error state (failed OR networkError)
  bool get isError        => isFailed || isNetworkError;
}

// ── Flutter UI helpers ──────────────────────────────────────────────────────

extension ApiStateBuildWidget<T, E> on ApiState<T, E> {
  /// Build a Flutter widget directly from state – eliminates screen boilerplate.
  ///
  /// - [loading]       Shown while the request is in-flight (required)
  /// - [success]       Shown when data is available (required)
  /// - [empty]         Shown when data is empty – defaults to [loading] shimmer
  ///                   if omitted (optional)
  /// - [error]         Shown for failed / unknown error states (required)
  /// - [networkError]  Shown for connectivity failures – defaults to [error]
  ///                   if omitted (optional)
  /// - [idle]          Shown for idle state – defaults to SizedBox.shrink()
  ///                   if omitted (optional)
  ///
  /// Example:
  /// ```dart
  /// state.buildWidget(
  ///   loading:      () => const GalleryShimmer(),
  ///   success:      (items) => GalleryGrid(items),
  ///   empty:        () => const EmptyGalleries(),
  ///   error:        (msg) => ErrorView(msg, onRetry: _reload),
  ///   networkError: () => NoInternetView(onRetry: _reload),
  /// );
  /// ```
  Widget buildWidget({
    required Widget Function() loading,
    required Widget Function(T data) success,
    required Widget Function(String message) error,
    Widget Function()? empty,
    Widget Function()? networkError,
    Widget Function()? idle,
  }) {
    return switch (this) {
      IdleState<T, E>() =>
      idle?.call() ?? const SizedBox.shrink(),

      LoadingState<T, E>() =>
          loading(),

      SuccessState<T, E>(data: final d) =>
          success(d),

      EmptyState<T, E>() =>
      empty?.call() ?? const SizedBox.shrink(),

      NetworkErrorState<T, E>(error: final e) =>
      networkError?.call() ?? error(e.message),

      FailedState<T, E>(error: final e) =>
          error(e.message),
    };
  }
}

/// A declarative Flutter widget that renders based on [ApiState].
///
/// Drop-in replacement for the typical BlocBuilder pattern.
///
/// Example:
/// ```dart
/// ApiStateWidget<List<Gallery>, ApiError>(
///   state: state.apiState,
///   loadingBuilder:  () => const GalleryShimmer(),
///   emptyBuilder:    () => const EmptyGalleries(),
///   builder:         (items) => GalleryGrid(items),
///   errorBuilder:    (msg) => ErrorView(msg),
/// )
/// ```
class ApiStateWidget<T, E> extends StatelessWidget {
  final ApiState<T, E> state;

  /// Shown while request is in-flight (required)
  final Widget Function() loadingBuilder;

  /// Shown when data is available (required)
  final Widget Function(T data) builder;

  /// Shown when the request failed (required)
  final Widget Function(String message) errorBuilder;

  /// Shown when data is empty – optional, falls back to SizedBox.shrink()
  final Widget Function()? emptyBuilder;

  /// Shown for connectivity failures – optional, falls back to [errorBuilder]
  final Widget Function()? networkErrorBuilder;

  /// Shown for idle state – optional, falls back to SizedBox.shrink()
  final Widget Function()? idleBuilder;

  const ApiStateWidget({
    super.key,
    required this.state,
    required this.loadingBuilder,
    required this.builder,
    required this.errorBuilder,
    this.emptyBuilder,
    this.networkErrorBuilder,
    this.idleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return state.buildWidget(
      loading:      loadingBuilder,
      success:      builder,
      error:        errorBuilder,
      empty:        emptyBuilder,
      networkError: networkErrorBuilder,
      idle:         idleBuilder,
    );
  }
}