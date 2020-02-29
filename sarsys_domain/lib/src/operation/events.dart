import 'package:meta/meta.dart';
import 'package:event_source/event_source.dart';

//////////////////////////////////////
// Operation Domain Events
//////////////////////////////////////

class OperationRegistered extends DomainEvent {
  OperationRegistered({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationRegistered',
          created: created,
          data: data,
        );
}

class OperationInformationUpdated extends DomainEvent {
  OperationInformationUpdated({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationInformationUpdated',
          created: created,
          data: data,
        );
}

class MissionAddedToOperation extends DomainEvent {
  MissionAddedToOperation({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$MissionAddedToOperation',
          created: created,
          data: data,
        );
}

class MissionRemovedFromOperation extends DomainEvent {
  MissionRemovedFromOperation({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$MissionRemovedFromOperation',
          created: created,
          data: data,
        );
}

class UnitAddedToOperation extends DomainEvent {
  UnitAddedToOperation({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$UnitAddedToOperation',
          created: created,
          data: data,
        );
}

class UnitRemovedFromOperation extends DomainEvent {
  UnitRemovedFromOperation({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$UnitRemovedFromOperation',
          created: created,
          data: data,
        );
}

class OperationStarted extends DomainEvent {
  OperationStarted({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationStarted',
          created: created,
          data: data,
        );
}

class OperationCancelled extends DomainEvent {
  OperationCancelled({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationCancelled',
          created: created,
          data: data,
        );
}

class OperationFinished extends DomainEvent {
  OperationFinished({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationFinished',
          created: created,
          data: data,
        );
}

class OperationDeleted extends DomainEvent {
  OperationDeleted({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationDeleted',
          created: created,
          data: data,
        );
}

//////////////////////////////////////
// Objective Domain Events
//////////////////////////////////////

class ObjectiveAdded extends DomainEvent {
  ObjectiveAdded({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$ObjectiveAdded',
          created: created,
          data: data,
        );
}

class ObjectiveUpdated extends DomainEvent {
  ObjectiveUpdated({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$ObjectiveUpdated',
          created: created,
          data: data,
        );
}

class ObjectiveRemoved extends DomainEvent {
  ObjectiveRemoved({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$ObjectiveRemoved',
          created: created,
          data: data,
        );
}

//////////////////////////////////////
// TalkGroup Domain Events
//////////////////////////////////////

class TalkGroupAdded extends DomainEvent {
  TalkGroupAdded({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$TalkGroupAdded',
          created: created,
          data: data,
        );
}

class TalkGroupUpdated extends DomainEvent {
  TalkGroupUpdated({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$TalkGroupUpdated',
          created: created,
          data: data,
        );
}

class TalkGroupRemoved extends DomainEvent {
  TalkGroupRemoved({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$TalkGroupRemoved',
          created: created,
          data: data,
        );
}

//////////////////////////////////
// Operation Message Domain Events
//////////////////////////////////

class OperationMessageAdded extends DomainEvent {
  OperationMessageAdded({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationMessageAdded',
          created: created,
          data: data,
        );
}

class OperationMessageUpdated extends DomainEvent {
  OperationMessageUpdated({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationMessageUpdated',
          created: created,
          data: data,
        );
}

class OperationMessageRemoved extends DomainEvent {
  OperationMessageRemoved({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: '$OperationMessageRemoved',
          created: created,
          data: data,
        );
}