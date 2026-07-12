import 'errors.dart';

/// Result type for operations that might fail.
sealed class Result<T> {
  const Result();

  /// Create a successful result.
  const factory Result.success(T value) = Success<T>;

  /// Create a failed result.
  const factory Result.failure(String error) = Failure<T>;

  /// Create a failed result while retaining the original error and stack.
  factory Result.failureFrom(Object error, [StackTrace? stackTrace]) =
      Failure<T>.fromObject;

  /// Whether this result is successful.
  bool get isSuccess => this is Success<T>;

  /// Whether this result failed.
  bool get isFailure => this is Failure<T>;

  /// Get the value if successful, otherwise throw.
  T get value => switch (this) {
        Success(value: final v) => v,
        Failure(error: final e, cause: final c, stackTrace: final s) =>
          throw ResultException(e, cause: c, stackTrace: s),
      };

  /// Get the error if failed, otherwise null.
  String? get error => switch (this) {
        Success() => null,
        Failure(error: final e) => e,
      };

  /// Original error object, if this failure was created with [failureFrom].
  Object? get cause => switch (this) {
        Success() => null,
        Failure(cause: final cause) => cause,
      };

  /// Stack trace captured for this failure, when available.
  StackTrace? get stackTrace => switch (this) {
        Success() => null,
        Failure(stackTrace: final stackTrace) => stackTrace,
      };

  /// Transform the value if successful.
  Result<U> map<U>(U Function(T) transform) => switch (this) {
        Success(value: final v) => Result.success(transform(v)),
        Failure(error: final e, cause: final c, stackTrace: final s) =>
          Failure<U>.withCause(e, cause: c, stackTrace: s),
      };

  /// Transform the result with a function that can also fail.
  Result<U> flatMap<U>(Result<U> Function(T) transform) => switch (this) {
        Success(value: final v) => transform(v),
        Failure(error: final e, cause: final c, stackTrace: final s) =>
          Failure<U>.withCause(e, cause: c, stackTrace: s),
      };

  /// Get the value or a default.
  T getOrElse(T defaultValue) => switch (this) {
        Success(value: final v) => v,
        Failure() => defaultValue,
      };

  /// Handle both success and failure cases.
  U fold<U>(U Function(String) onFailure, U Function(T) onSuccess) =>
      switch (this) {
        Success(value: final v) => onSuccess(v),
        Failure(error: final e) => onFailure(e),
      };
}

/// Successful result.
class Success<T> extends Result<T> {
  @override
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// Failed result.
class Failure<T> extends Result<T> {
  @override
  final String error;

  @override
  final Object? cause;

  @override
  final StackTrace? stackTrace;

  const Failure(this.error)
      : cause = null,
        stackTrace = null;

  const Failure.withCause(this.error, {this.cause, this.stackTrace});

  factory Failure.fromObject(Object error, [StackTrace? stackTrace]) {
    final effectiveStackTrace =
        stackTrace ?? (error is BibleError ? error.stackTrace : null);
    final message = error is BibleError ? error.message : error.toString();
    return Failure.withCause(
      message,
      cause: error,
      stackTrace: effectiveStackTrace,
    );
  }

  @override
  String toString() => 'Failure($error)';
}

/// Exception thrown when accessing value of failed result.
class ResultException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  ResultException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => 'ResultException: $message';
}
