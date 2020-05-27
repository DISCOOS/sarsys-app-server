import 'package:meta/meta.dart';

import 'core.dart';

/// Base class for failures
abstract class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() {
    return '$runtimeType{message: $message}';
  }
}

/// Thrown when an invalid operation is attempted
class InvalidOperation extends Failure {
  const InvalidOperation(String message) : super(message);
}

/// Thrown when an required projection is not available
class ProjectionNotAvailable extends InvalidOperation {
  const ProjectionNotAvailable(String message) : super(message);
}

/// Thrown when an required repository is not available
class RepositoryNotAvailable extends InvalidOperation {
  const RepositoryNotAvailable(String message) : super(message);
}

/// Thrown when an uuid is null
class UUIDIsNull extends InvalidOperation {
  const UUIDIsNull(String message) : super(message);
}

/// Thrown when an [Command] is attempted on an [AggregateRoot] not found
class AggregateNotFound extends InvalidOperation {
  const AggregateNotFound(String message) : super(message);
}

/// Thrown when an [Command.action] with [Action.create] is attempted on an existing [AggregateRoot]
class AggregateExists extends InvalidOperation {
  const AggregateExists(String message) : super(message);
}

/// Thrown when an [Command] is attempted on an [EntityObject] not found
class EntityNotFound extends InvalidOperation {
  const EntityNotFound(String message) : super(message);
}

/// Thrown when an [Command.action] with [Action.create] is attempted on an existing [EntityObject]
class EntityExists extends InvalidOperation {
  const EntityExists(String message) : super(message);
}

/// Thrown when writing events and 'ES-ExpectedVersion' differs from 'ES-CurrentVersion'
class WrongExpectedEventVersion extends InvalidOperation {
  const WrongExpectedEventVersion(
    String message, {
    @required this.expected,
    @required this.actual,
  }) : super(message);
  final ExpectedVersion expected;
  final EventNumber actual;

  @override
  String toString() {
    return '$runtimeType{expected: ${expected.value}, actual: ${actual.value}, message: $message}';
  }
}

/// Thrown when automatic merge resolution is not possible
class ConflictNotReconcilable extends InvalidOperation {
  const ConflictNotReconcilable(
    String message, {
    @required this.local,
    @required this.remote,
  }) : super(message);
  final Iterable<Map<String, dynamic>> local;
  final Iterable<Map<String, dynamic>> remote;

  @override
  String toString() {
    return '$runtimeType{local: $local, remote: $remote}';
  }
}

/// Thrown when an write failed
class WriteFailed extends Failure {
  const WriteFailed(String message) : super(message);
}

/// Thrown when a concurrent write operation was attempted
class ConcurrentWriteOperation extends WriteFailed implements Exception {
  ConcurrentWriteOperation(String message) : super(message);
}

/// Thrown when catchup ended in mismatch between current number and number in remote event stream
class EventNumberMismatch extends WriteFailed implements Exception {
  EventNumberMismatch(String stream, EventNumber current, EventNumber actual, String message)
      : super('$message: stream $stream current event number ($current) not equal to actual ($actual)');
}

/// Thrown when [MergeStrategy] fails to reconcile [WrongExpectedEventVersion] after maximum number of attempts
class EventVersionReconciliationFailed extends WriteFailed {
  const EventVersionReconciliationFailed(WrongExpectedEventVersion cause, int attempts)
      : super('Failed to reconcile $cause after $attempts attempts');
}

/// Thrown when more then one [AggregateRoot] has changes concurrently
class MultipleAggregatesWithChanges extends WriteFailed {
  const MultipleAggregatesWithChanges(String message) : super(message);
}

/// Thrown when an stream [AtomFeed] operation failed
class FeedFailed extends Failure {
  const FeedFailed(String message) : super(message);
}

/// Thrown when an stream [Event] subscription failed
class SubscriptionFailed extends Failure {
  const SubscriptionFailed(String message) : super(message);
}