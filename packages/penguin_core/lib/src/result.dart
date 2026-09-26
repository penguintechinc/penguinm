import 'failure.dart';

/// Outcome of an operation that may fail: either a success value of type
/// [T] ([Result.ok]) or a typed [Failure] ([Result.err]). Used across every
/// penguinm package for a consistent, exception-free error-handling shape.
sealed class Result<T> {
  const Result();

  /// Wraps a successful [value].
  const factory Result.ok(T value) = Ok<T>;

  /// Wraps a [Failure] describing what went wrong.
  const factory Result.err(Failure f) = Err<T>;

  /// Reduces this result to a single value: [ok] runs on success, [err] on
  /// failure — the standard way to consume a [Result] without a type check.
  R fold<R>(R Function(T value) ok, R Function(Failure failure) err);

  /// Transforms a successful value with [transform]; failures pass through
  /// unchanged.
  Result<R> map<R>(R Function(T value) transform);

  /// True when this is a successful [Ok] result.
  bool get isOk;

  /// The success value, or null when this is an [Err].
  T? get valueOrNull;
}

/// Successful [Result] wrapping a value.
class Ok<T> extends Result<T> {
  /// Creates a successful result wrapping [value].
  const Ok(this.value);

  /// The wrapped success value.
  final T value;

  @override
  R fold<R>(R Function(T value) ok, R Function(Failure failure) err) =>
      ok(value);

  @override
  Result<R> map<R>(R Function(T value) transform) => Ok<R>(transform(value));

  @override
  bool get isOk => true;

  @override
  T? get valueOrNull => value;
}

/// Failed [Result] wrapping a [Failure].
class Err<T> extends Result<T> {
  /// Creates a failed result wrapping [failure].
  const Err(this.failure);

  /// The failure describing what went wrong.
  final Failure failure;

  @override
  R fold<R>(R Function(T value) ok, R Function(Failure failure) err) =>
      err(failure);

  @override
  Result<R> map<R>(R Function(T value) transform) => Err<R>(failure);

  @override
  bool get isOk => false;

  @override
  T? get valueOrNull => null;
}
