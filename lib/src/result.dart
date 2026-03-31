/// Result type for operations that might fail.
sealed class Result<T> {
  const Result();

  /// Create a successful result.
  const factory Result.success(T value) = Success<T>;

  /// Create a failed result.
  const factory Result.failure(String error) = Failure<T>;

  /// Whether this result is successful.
  bool get isSuccess => this is Success<T>;

  /// Whether this result failed.
  bool get isFailure => this is Failure<T>;

  /// Get the value if successful, otherwise throw.
  T get value => switch (this) {
        Success(value: final v) => v,
        Failure(error: final e) => throw ResultException(e),
      };

  /// Get the error if failed, otherwise null.
  String? get error => switch (this) {
        Success() => null,
        Failure(error: final e) => e,
      };

  /// Transform the value if successful.
  Result<U> map<U>(U Function(T) transform) => switch (this) {
        Success(value: final v) => Result.success(transform(v)),
        Failure(error: final e) => Result.failure(e),
      };

  /// Transform the result with a function that can also fail.
  Result<U> flatMap<U>(Result<U> Function(T) transform) => switch (this) {
        Success(value: final v) => transform(v),
        Failure(error: final e) => Result.failure(e),
      };

  /// Get the value or a default.
  T getOrElse(T defaultValue) => switch (this) {
        Success(value: final v) => v,
        Failure() => defaultValue,
      };

  /// Handle both success and failure cases.
  U fold<U>(U Function(String) onFailure, U Function(T) onSuccess) => switch (this) {
        Success(value: final v) => onSuccess(v),
        Failure(error: final e) => onFailure(e),
      };
}

/// Successful result.
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';
}

/// Failed result.
class Failure<T> extends Result<T> {
  final String error;
  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';
}

/// Exception thrown when accessing value of failed result.
class ResultException implements Exception {
  final String message;
  ResultException(this.message);

  @override
  String toString() => 'ResultException: $message';
}