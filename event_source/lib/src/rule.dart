import 'dart:async';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';
import 'package:collection_x/collection_x.dart';

import 'core.dart';
import 'error.dart';
import 'domain.dart';

/// Rule (invariant) builder function for given [repository]
///
/// Should always return an [AggregateRule]
typedef RuleBuilder = AggregateRule Function(Repository repository);

/// [Command] builder function for given [source] and [uuid] of target [AggregateRoot]
///
/// If function returns a [Command] it must be executed. Return null if
/// nothing should be execution.
typedef CommandBuilder = Command Function(DomainEvent source, String uuid);

/// [AggregateRoot] target resolver function
typedef TargetResolver = Repository Function();

/// Number range class
class Range {
  const Range({this.max, this.min});

  factory Range.lower(int min) => Range(min: min);
  factory Range.upper(int max) => Range(max: max);

  static const many = Range();
  static const one = Range(min: 1, max: 1);
  static const none = Range(min: 0, max: 0);

  final int max;
  final int min;

  bool get isOne => min == 1 && max == 1;
  bool get isNone => min == 0 && max == 0;
  bool get isMany => min == null && max == null;

  bool get isBound => !isMany;
  bool get isLowerBound => min != null;
  bool get isUpperBound => max != null;

  String toUML() {
    if (isNone) {
      return '0..0';
    } else if (isMany) {
      return '1..*';
    } else if (isOne) {
      return '1';
    } else if (isLowerBound && !isUpperBound) {
      return '$min';
    } else if (isUpperBound && !isLowerBound) {
      return '0..$max';
    } else if (isUpperBound && isLowerBound) {
      return '$min..$max';
    }
    // isMany
    return '0..*';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Range && runtimeType == other.runtimeType && max == other.max && min == other.min;

  @override
  int get hashCode => max.hashCode ^ min.hashCode;

  @override
  String toString() {
    return 'Range{max: $max, min: $min}';
  }
}

enum CardinalityType {
  any,
  o2o,
  o2m,
  m2o,
  m2m,
  none,
}

/// Cardinality class
/// see https://en.wikipedia.org/wiki/Cardinality_(data_modeling)
class Cardinality {
  const Cardinality({this.left = Range.many, this.right = Range.many});
  final Range left;
  final Range right;

  /// Many-to-many cardinality
  static const m2m = Cardinality();

  /// Any type of cardinality
  static const any = Cardinality(left: null, right: null);

  /// No cardinality allowed
  static const none = Cardinality(left: Range.none, right: Range.none);

  /// One-to-one cardinality
  static const o2o = Cardinality(left: Range.one, right: Range.one);

  /// one-to-many cardinality
  static const o2m = Cardinality(left: Range.one, right: Range.many);

  /// Many-to-one cardinality
  static const m2o = Cardinality(left: Range.many, right: Range.one);

  bool get isAny => this == any;
  bool get isO2O => this == o2o;
  bool get isO2M => this == o2m;
  bool get isM2O => this == m2o;
  bool get isM2M => this == m2m;
  bool get isNone => this == none;

  CardinalityType get type {
    if (isAny) {
      return CardinalityType.any;
    } else if (isO2O) {
      return CardinalityType.o2o;
    } else if (isO2M) {
      return CardinalityType.o2m;
    } else if (isM2O) {
      return CardinalityType.o2m;
    } else if (isM2M) {
      return CardinalityType.o2m;
    }
    return CardinalityType.none;
  }

  String toUML() => isAny ? 'any' : '${left.toUML()} <-> ${right.toUML()}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cardinality && runtimeType == other.runtimeType && left == other.left && right == other.right;

  @override
  int get hashCode => left.hashCode ^ right.hashCode;

  @override
  String toString() => 'Cardinality{left: $left, right: $right}';
}

/// General [AggregateRule] failure
class RuleException extends EventSourceException {
  RuleException(String message) : super(message);
}

/// [Cardinality] violation exception
class CardinalityException extends RuleException {
  CardinalityException(String message) : super(message);
}

/// Abstract class for [AggregateRoot] rule-based execution
abstract class AggregateRule {
  AggregateRule(
    this.builder,
    this.target, {
    this.local = true,
  }) : logger = Logger('AggregateRule[${target.runtimeType}]');
  final Logger logger;

  /// Process events with state local (not committed)
  final bool local;

  /// Target [Repository] for executing commands
  final Repository target;

  /// [Command] builder function
  final CommandBuilder builder;

  /// Returns list of [AggregateRoot.uuid]
  /// that this rule should be applied on
  Future<Iterable<String>> appliesTo(DomainEvent event);

  /// Framework calls this method
  Future<Iterable<DomainEvent>> call(Object source, DomainEvent event) async {
    if (_shouldProcess(event)) {
      final uuids = await appliesTo(event);
      logger.fine(
        '$runtimeType matched $event to ${target.aggregateType} uuids: $uuids',
      );
      final events = <DomainEvent>[];
      for (var uuid in uuids) {
        final result = await execute(
          event,
          uuid,
        );
        events.addAll(result);
      }
      return events;
    }
    logger.fine(
      '$runtimeType did not process: $event',
    );
    return null;
  }

  bool _shouldProcess(DomainEvent event) {
    return event.local == local;
  }

  /// Execute rule for given aggregate
  Future<Iterable<DomainEvent>> execute(DomainEvent event, String uuid) async {
    final command = builder(event, uuid);
    logger.fine(
      '$runtimeType executes command: ${command?.runtimeType ?? 'none'}',
    );
    if (command != null) {
      final shouldExecute = await _shouldExecute(command, uuid);
      logger.fine(
        '$runtimeType should execute command $command on ${target.runtimeType}: $shouldExecute',
      );
      // Try to catch up before executing
      if (shouldExecute) {
        final result = await target.execute(
          command,
        );
        logger.fine(
          '$runtimeType executed command on ${target.runtimeType}: $result',
        );
        return result;
      }
    }
    return [];
  }

  /// Check if exist if command action is update.
  /// Preform catchup if not found before checking again.
  Future<bool> _shouldExecute(Command command, String uuid) async {
    if (command.action != Action.create) {
      if (!target.exists(uuid)) {
        await target.catchup(
          master: true,
          uuids: [uuid],
        );
      }
      return target.exists(uuid);
    }
    return true;
  }
}

/// Rule for managing a [AggregateRoot] association
/// between [source] and [target] Repository
class AssociationRule extends AggregateRule {
  AssociationRule(
    CommandBuilder builder, {
    @required this.intent,
    @required Repository source,
    @required String sourceField,
    @required Repository target,
    @required this.targetField,

    /// Only apply rule to local events
    /// (default true)
    bool local = true,

    /// Resolve previous
    /// [AggregateRoot.data] using
    /// [AggregateRoot.toData] if
    /// [DomainEvent.isTerse]
    /// (default false).
    this.resolve = false,

    /// Association [Cardinality]
    /// enforced by this rule.
    this.cardinality = Cardinality.any,
  })  : source = source ?? target,
        sourceField = sourceField ?? (source ?? target).uuidFieldName,
        super(
          builder,
          target,
          local: local,
        );

  /// If [true] resolve previous
  /// [AggregateRoot.data] using
  /// [AggregateRoot.toData]
  final bool resolve;

  /// Source [Repository] which events are applied
  final Repository source;

  /// Get intended action if rule applies
  final Action intent;

  /// [MapX] path to field in [source] repository
  final String sourceField;

  /// [MapX] path to field in [target] repository
  final String targetField;

  /// Get expected cardinality between source and target
  final Cardinality cardinality;

  @override
  Future<Iterable<String>> appliesTo(DomainEvent event) async {
    // Ensure distinct target uuids
    var targets = <String>{};
    final key = _lookup(event);
    if (key != null) {
      final uuids = find(target, targetField, key);
      if (uuids.isNotEmpty == true) {
        targets.addAll(uuids);
      }
      switch (intent) {
        case Action.create:
          if (_shouldCreate(key, targets)) {
            targets = {
              targetField == target.uuidFieldName ? key : Uuid().v4(),
            };
          } else {
            targets.clear();
          }
          break;
        case Action.update:
          // TODO: Handle replaced aggregate reference
          break;
        case Action.delete:
          if (!_shouldDelete(key, targets)) {
            targets.clear();
          }
          break;
      }
    }
    return targets;
  }

  String _lookup(DomainEvent event) {
    final uuid = source.toAggregateUuid(event);
    if (sourceField != source.uuidFieldName) {
      // Lookup value in source aggregate
      final aggregate = source.peek(uuid);
      var value = _toValue(event, aggregate, sourceField);
      if (value == null && target != source) {
        // Lookup target aggregate
        final aggregate = target.peek(uuid);
        value = _toValue(event, aggregate, targetField);
      }
      return value;
    }
    return uuid;
  }

  String _toValue(DomainEvent event, AggregateRoot aggregate, String field) {
    var value = aggregate?.data?.elementAt<String>(field);
    if (value != null) {
      return value;
    }

    // Was value deleted?
    if (event.isTerse) {
      if (resolve && aggregate.isApplied(event)) {
        final previous = aggregate.toData(event);
        value = previous.elementAt(field);
        if (value != null) {
          return value;
        }
      }
    }
    return event.previous.elementAt<String>(field);
  }

  Iterable<String> find(Repository repo, String field, String match) => repo.aggregates
      .where((aggregate) => !aggregate.isDeleted)
      .where((aggregate) => contains(aggregate, field, match))
      .map((aggregate) => aggregate.uuid)
      .toList();

  bool contains(AggregateRoot aggregate, String field, String match) {
    final value = aggregate.data.elementAt(field);
    if (value is List) {
      return value.contains(match);
    } else if (value is String) {
      return value == match;
    }
    return false;
  }

  bool _shouldCreate(String reference, Iterable<String> targets) {
    // Prevent aggregate being created
    // with uuid from same reference value
    if (targetField == target.uuidFieldName && target.contains(reference)) {
      return false;
    }

    switch (cardinality.type) {
      case CardinalityType.any:
      case CardinalityType.m2m:
        // Always create targets
        return true;
      case CardinalityType.m2o:
      case CardinalityType.o2o:
        // Do not create when targets exists already
        return targets.isEmpty;
      case CardinalityType.o2m:
        // Only create targets if one
        // source exists with given reference value
        return find(source, sourceField, reference).length == 1;
      case CardinalityType.none:
      default:
        // Do not create if an relation will
        // be created (same as distinct)
        return find(source, sourceField, reference).isEmpty && targets.isEmpty;
    }
  }

  bool _shouldDelete(String reference, Iterable<String> targets) {
    // Prevent that does not exist being deleted
    if (targetField == target.uuidFieldName && !target.contains(reference)) {
      return false;
    }

    switch (cardinality.type) {
      case CardinalityType.o2o:
      case CardinalityType.o2m:
      case CardinalityType.m2o:
      case CardinalityType.m2m:
        // Do not delete until last source is deleted
        return find(source, sourceField, reference).isEmpty && targets.isNotEmpty;
      case CardinalityType.any:
      case CardinalityType.none:
      default:
        // Only delete if relation exists
        return targets.isNotEmpty;
    }
  }

  @override
  String toString() {
    return 'AssociationRule{\n'
        '  intent: $intent,\n'
        '  source: ${source.runtimeType},\n'
        '  sourceField: $sourceField,\n'
        '  target: ${target.runtimeType},\n'
        '  targetField: $targetField,\n'
        '  cardinality: ${cardinality.toUML()}\n'
        '}';
  }
}
