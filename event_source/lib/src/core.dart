import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'domain.dart';
import 'extension.dart';

/// Message interface
class Message {
  const Message({
    @required this.uuid,
    @required this.local,
    this.created,
    String type,
    this.data,
  }) : _type = type;

  /// Massage uuid
  ///
  final String uuid;

  /// Flag indicating that event has local origin.
  /// Allow handlers to decide if event should be processed0
  ///
  final bool local;

  /// Message creation time
  /// *NOTE*: Not stable until read from remote stream
  ///
  final DateTime created;

  /// Message data
  ///
  final Map<String, dynamic> data;

  /// Message type
  ///
  String get type => _type ?? '$runtimeType';
  final String _type;

  @override
  String toString() {
    return '$runtimeType{uuid: $uuid, type: $type}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Message && runtimeType == other.runtimeType && uuid == other.uuid;
  /* &&
          // DO NOT COMPARE - equality is guaranteed by type and uuid
          // data == other.data &&
          // _type == other._type &&
          // DO NOT COMPARE - is not stable until read from remote stream
          // created == other.created;
   */

  @override
  int get hashCode => uuid.hashCode; /* ^ data.hashCode ^ _type.hashCode ^ created.hashCode; */
}

/// Event class
class Event extends Message {
  const Event({
    @required String uuid,
    @required String type,
    @required bool local,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: type,
          data: data,
          local: local,
          created: created,
        );

  /// Create an event with uuid
  factory Event.unique({
    @required bool local,
    @required String type,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) =>
      Event(
        uuid: Uuid().v4(),
        type: type,
        data: data,
        local: local,
        created: created,
      );

  /// Get element at given path in [changed]. If not found, [previous] is used instead
  Map<String, dynamic> elementAt(String path) => changed.elementAt(path) ?? previous.elementAt(path);

  /// Test if all data is deleted by evaluating if `data['deleted'] == 'true'`
  bool get isDeleted => data['deleted'] == true;

  /// Get changed fields from `data['changed']`
  Map<String, dynamic> get changed => Map<String, dynamic>.from(data['changed']);

  /// Get changed fields from `data['previous']`. If empty, `data['changed']`is returned instead
  Map<String, dynamic> get previous => Map<String, dynamic>.from(data['previous'] ?? data['changed']);

  /// Get list of JSON Patch methods from `data['patches']`
  List<Map<String, dynamic>> get patches => List<Map<String, dynamic>>.from(data['patches'] as List<dynamic>);

  @override
  String toString() {
    return '$runtimeType{uuid: $uuid, type: $type, created: $created}';
  }
}

/// Base class for domain events
class DomainEvent extends Event {
  DomainEvent({
    @required bool local,
    @required String uuid,
    @required String type,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: type,
          data: data,
          local: local,
          created: created ?? DateTime.now(),
        );

  @override
  String toString() {
    return '$runtimeType{uuid: $uuid, type: $type, created: $created, data: $data}';
  }
}

class EntityObjectEvent extends DomainEvent {
  EntityObjectEvent({
    @required bool local,
    @required String uuid,
    @required String type,
    @required DateTime created,
    @required this.aggregateField,
    @required Map<String, dynamic> data,
    int index,
    this.idFieldName = 'id',
  }) : super(
          uuid: uuid,
          type: type,
          local: local,
          created: created,
          data: {'index': index}..addAll(data),
        );

  final String idFieldName;
  final String aggregateField;

  int get index => data['index'];
  String get id => entity.elementAt('id');
  Map<String, dynamic> get entity => elementAt('$aggregateField/$index');
  EntityObject get entityObject => EntityObject(id, entity, idFieldName);
}

class ValueObjectEvent<T> extends DomainEvent {
  ValueObjectEvent({
    @required bool local,
    @required String uuid,
    @required String type,
    @required DateTime created,
    @required this.valueField,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: type,
          local: local,
          created: created,
          data: data,
        );

  final String valueField;

  T get value => elementAt('$valueField') as T;
}

/// Base class for events sourced from an event stream.
///
/// A [Repository] folds [SourceEvent]s into [DomainEvent]s with [Repository.get].
class SourceEvent extends Event {
  SourceEvent({
    @required String uuid,
    @required String type,
    @required this.number,
    @required this.streamId,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: type,
          data: data,
          local: false,
          created: created ?? DateTime.now(),
        );
  final String streamId;
  final EventNumber number;

  @override
  String toString() {
    return '$runtimeType{uuid: $uuid, type: $type, number: $number, data: $data}';
  }
}

/// Command action types
enum Action {
  create,
  update,
  delete,
}

/// Command interface
abstract class Command<T extends DomainEvent> extends Message {
  Command(
    this.action, {
    String uuid,
    this.uuidFieldName = 'uuid',
    Map<String, dynamic> data = const {},
  })  : _uuid = uuid,
        super(
          uuid: uuid,
          data: data,
          local: true,
        );

  /// Command action
  final Action action;

  /// Aggregate uuid
  final String _uuid;

  /// Get [AggregateRoot.uuid] value
  @override
  String get uuid => _uuid ?? data[uuidFieldName] as String;

  /// [AggregateRoot.uuid] field name in [data]
  final String uuidFieldName;

  /// Get [DomainEvent] type emitted after command is executed
  Type get emits => typeOf<T>();

  /// Add value to list in given field
  static Map<String, dynamic> addToList<T>(Map<String, dynamic> data, String field, T value) => Map.from(data)
    ..update(
      field,
      (operations) => List<T>.from(operations as List)..add(value),
      ifAbsent: () => [value],
    );

  /// Remove value from list in given field
  static Map<String, dynamic> removeFromList<T>(Map<String, dynamic> data, String field, T value) => Map.from(data)
    ..update(
      field,
      (operations) => List<T>.from(operations as List)..remove(value),
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Command && runtimeType == other.runtimeType && uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;

  @override
  String toString() {
    return '$runtimeType{uuid: $uuid, action: $action}';
  }
}

/// Command interface
abstract class EntityCommand<T extends DomainEvent> extends Command<T> {
  EntityCommand(
    Action action,
    this.aggregateField, {
    String uuid,
    String entityId,
    String uuidFieldName = 'uuid',
    this.entityIdFieldName = 'id',
    Map<String, dynamic> data = const {},
  })  : _id = entityId,
        super(
          action,
          uuid: uuid,
          uuidFieldName: uuidFieldName,
          data: data,
        );

  /// Aggregate field name storing entities
  final String aggregateField;

  /// [EntityObject.id] value
  final String _id;

  /// Get [EntityObject.id] value
  String get entityId => _id ?? data[entityIdFieldName] as String;

  /// [EntityObject.id] field name in [data]
  final String entityIdFieldName;

  @override
  String toString() {
    return '$runtimeType{uuid: $uuid, action: $action, entityId: $entityId}';
  }
}

/// Command handler interface
abstract class CommandHandler<T extends Command> {
  FutureOr<Iterable<Event>> execute(T command);
}

/// Message notifier interface
abstract class MessageNotifier {
  void notify(Message message);
}

/// Event publisher interface
abstract class EventPublisher<T extends Event> {
  void publish(T event);
}

/// Command sender interface
abstract class CommandSender {
  void send(Command command);
}

/// Message handler interface
abstract class MessageHandler<T extends Message> {
  void handle(T message);
}

/// Event number in stream
class EventNumber extends Equatable {
  const EventNumber(this.value);

  factory EventNumber.from(ExpectedVersion current) => EventNumber(current.value);

  // First event in stream
  static const first = EventNumber(0);

  // Empty stream
  static const none = EventNumber(-1);

  // Last event in stream
  static const last = EventNumber(-2);

  /// Test if event number is NONE
  bool get isNone => this == none;

  /// Test if first event number in stream
  bool get isFirst => this == first;

  /// Test if last event number in stream
  bool get isLast => this == last;

  /// Event number value
  final int value;

  @override
  List<Object> get props => [value];

  EventNumber operator +(int number) => EventNumber(value + number);
  bool operator >(EventNumber number) => value > number.value;
  bool operator <(EventNumber number) => value < number.value;
  bool operator >=(EventNumber number) => value >= number.value;
  bool operator <=(EventNumber number) => value <= number.value;

  @override
  String toString() {
    return (isLast ? 'HEAD' : value).toString();
  }
}

/// Event traversal direction
enum Direction { forward, backward }

/// When you write to a stream you often want to use
/// [ExpectedVersion] to allow for optimistic concurrency
/// with a stream. You commonly use this for a domain
/// object projection.
class ExpectedVersion {
  const ExpectedVersion(this.value);

  factory ExpectedVersion.from(EventNumber number) => ExpectedVersion(number.value);

  /// Stream should exist but be empty when writing.
  static const empty = ExpectedVersion(0);

  /// Stream should not exist when writing.
  static const none = ExpectedVersion(-1);

  /// Write should not conflict with anything and should always succeed.
  /// This disables the optimistic concurrency check.
  static const any = ExpectedVersion(-2);

  /// Stream should exist, but does not expect the stream to be at a specific event version number.
  static const exists = ExpectedVersion(-4);

  /// The event version number that you expect the stream to currently be at.
  final int value;

  /// Adds [other] to [value] and returns new Expected version
  ExpectedVersion operator +(int other) => ExpectedVersion(value + other);

  @override
  String toString() {
    return 'ExpectedVersion{value: $value}';
  }
}

/// Get enum value name
String enumName(Object o) => o.toString().split('.').last;

/// Type helper class
Type typeOf<T>() => T;
