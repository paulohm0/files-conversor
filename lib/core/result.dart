/// Resultado de uma operação que pode falhar sem lançar exceção.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(String message) failure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>() => success(self.value),
      Failure<T>() => failure(self.message),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.message);

  final String message;
}
