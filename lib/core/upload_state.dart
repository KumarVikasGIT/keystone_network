import 'failure_response.dart';

/// Represents the state of a file / multipart upload.
///
/// States:
/// - idle:         No upload started
/// - uploading:    Bytes being sent; [progress] is 0.0 – 1.0
/// - processing:   All bytes sent, waiting for server response
/// - success:      Upload complete, server returned data
/// - failed:       Upload or server error
/// - networkError: Connectivity failure
///
/// Example:
/// ```dart
/// UploadState<Photo, ApiError> state = UploadState.idle();
///
/// ApiExecutor.uploadStream<Photo, ApiError>(
///   request: (onSendProgress) => dio.post(
///     '/photos',
///     data: formData,
///     onSendProgress: onSendProgress,
///   ),
///   parser: Photo.fromJson,
/// ).listen((state) {
///   state.when(
///     idle:         ()         => {},
///     uploading:    (progress) => updateProgressBar(progress),
///     processing:   ()         => showSpinner(),
///     success:      (photo)    => showPhoto(photo),
///     failed:       (error)    => showError(error.message),
///     networkError: ()         => showNoInternet(),
///   );
/// });
/// ```
sealed class UploadState<T, E> {
  const UploadState();

  const factory UploadState.idle() = UploadIdleState<T, E>;

  /// [progress] is in the range 0.0 – 1.0
  const factory UploadState.uploading(double progress) =
  UploadingState<T, E>;

  const factory UploadState.processing() = UploadProcessingState<T, E>;

  const factory UploadState.success(T data) = UploadSuccessState<T, E>;

  const factory UploadState.failed(FailureResponse<E> error) =
  UploadFailedState<T, E>;

  const factory UploadState.networkError() = UploadNetworkErrorState<T, E>;

  // ── Accessors ──────────────────────────────────────────────────────────

  /// Progress in 0.0 – 1.0 when uploading, null otherwise
  double? get progress => switch (this) {
    UploadingState<T, E>(progress: final p) => p,
    _ => null,
  };

  /// Success data, or null
  T? get data => switch (this) {
    UploadSuccessState<T, E>(data: final d) => d,
    _ => null,
  };

  /// Error payload, or null
  FailureResponse<E>? get error => switch (this) {
    UploadFailedState<T, E>(error: final e) => e,
    _ => null,
  };

  // ── Pattern matching ───────────────────────────────────────────────────

  R when<R>({
    required R Function() idle,
    required R Function(double progress) uploading,
    required R Function() processing,
    required R Function(T data) success,
    required R Function(FailureResponse<E> error) failed,
    required R Function() networkError,
  }) =>
      switch (this) {
        UploadIdleState<T, E>()                       => idle(),
        UploadingState<T, E>(progress: final p)       => uploading(p),
        UploadProcessingState<T, E>()                 => processing(),
        UploadSuccessState<T, E>(data: final d)       => success(d),
        UploadFailedState<T, E>(error: final e)       => failed(e),
        UploadNetworkErrorState<T, E>()               => networkError(),
      };

  R maybeWhen<R>({
    R Function()? idle,
    R Function(double progress)? uploading,
    R Function()? processing,
    R Function(T data)? success,
    R Function(FailureResponse<E> error)? failed,
    R Function()? networkError,
    required R Function() orElse,
  }) =>
      switch (this) {
        UploadIdleState<T, E>()                       => idle?.call() ?? orElse(),
        UploadingState<T, E>(progress: final p)       => uploading?.call(p) ?? orElse(),
        UploadProcessingState<T, E>()                 => processing?.call() ?? orElse(),
        UploadSuccessState<T, E>(data: final d)       => success?.call(d) ?? orElse(),
        UploadFailedState<T, E>(error: final e)       => failed?.call(e) ?? orElse(),
        UploadNetworkErrorState<T, E>()               => networkError?.call() ?? orElse(),
      };
}

// ── Concrete classes ────────────────────────────────────────────────────────

final class UploadIdleState<T, E> extends UploadState<T, E> {
  const UploadIdleState();
  @override String toString() => 'UploadState<$T,$E>.idle()';
}

final class UploadingState<T, E> extends UploadState<T, E> {
  final double progress;
  const UploadingState(this.progress)
      : assert(progress >= 0.0 && progress <= 1.0);
  @override String toString() =>
      'UploadState<$T,$E>.uploading(${(progress * 100).round()}%)';
}

final class UploadProcessingState<T, E> extends UploadState<T, E> {
  const UploadProcessingState();
  @override String toString() => 'UploadState<$T,$E>.processing()';
}

final class UploadSuccessState<T, E> extends UploadState<T, E> {
  final T data;
  const UploadSuccessState(this.data);
  @override String toString() => 'UploadState<$T,$E>.success($data)';
}

final class UploadFailedState<T, E> extends UploadState<T, E> {
  final FailureResponse<E> error;
  const UploadFailedState(this.error);
  @override String toString() => 'UploadState<$T,$E>.failed($error)';
}

final class UploadNetworkErrorState<T, E> extends UploadState<T, E> {
  const UploadNetworkErrorState();
  @override String toString() => 'UploadState<$T,$E>.networkError()';
}

// ── Convenience extensions ──────────────────────────────────────────────────

extension UploadStateX<T, E> on UploadState<T, E> {
  bool get isIdle         => this is UploadIdleState<T, E>;
  bool get isUploading    => this is UploadingState<T, E>;
  bool get isProcessing   => this is UploadProcessingState<T, E>;
  bool get isSuccess      => this is UploadSuccessState<T, E>;
  bool get isFailed       => this is UploadFailedState<T, E>;
  bool get isNetworkError => this is UploadNetworkErrorState<T, E>;
  bool get isError        => isFailed || isNetworkError;
  bool get isInProgress   => isUploading || isProcessing;
}