import 'failures.dart';

/// Either-like result: use cases return values instead of throwing across layers.
sealed class Result<T> {
  const Result();

  R when<R>({required R Function(T value) ok, required R Function(Failure failure) err}) => switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
