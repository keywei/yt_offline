/// Domain-level error types. Data layer maps platform/library exceptions
/// into one of these so upper layers never see raw exceptions.
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType($message)';
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network unavailable']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found']);
}

final class ParseFailure extends Failure {
  const ParseFailure([super.message = 'Failed to parse response']);
}

final class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage error']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unknown error']);
}
