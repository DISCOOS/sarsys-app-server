import 'package:sarsys_app_server/eventsource/eventsource.dart';

import 'events.dart';

abstract class MissionCommand<T extends DomainEvent> extends Command<T> {
  MissionCommand(
    Action action, {
    String uuid,
    Map<String, dynamic> data = const {},
  }) : super(action, uuid: uuid, data: data);
}

//////////////////////////////////
// Mission aggregate commands
//////////////////////////////////

class CreateMission extends MissionCommand<MissionCreated> {
  CreateMission(
    Map<String, dynamic> data,
  ) : super(Action.create, data: data);
}

class UpdateMissionInformation extends MissionCommand<MissionInformationUpdated> {
  UpdateMissionInformation(
    Map<String, dynamic> data,
  ) : super(Action.update, data: data);
}

class DeleteMission extends MissionCommand<MissionAssigned> {
  DeleteMission(
    Map<String, dynamic> data,
  ) : super(Action.update, data: data);
}

//////////////////////////////////
// MissionPart entity commands
//////////////////////////////////

class MissionPartCommand<T extends DomainEvent> extends MissionCommand<T> implements EntityCommand<T> {
  MissionPartCommand(
    Action action,
    String uuid,
    Map<String, dynamic> data,
  ) : super(action, uuid: uuid, data: data);

  @override
  String get aggregateField => "parts";

  @override
  int get entityId => data[entityIdFieldName] as int;

  @override
  String get entityIdFieldName => 'id';
}

class AddMissionPart extends MissionPartCommand<MissionPartAdded> {
  AddMissionPart(
    String uuid,
    Map<String, dynamic> data,
  ) : super(Action.create, uuid, data);
}

class UpdateMissionPart extends MissionPartCommand<MissionPartUpdated> {
  UpdateMissionPart(
    String uuid,
    Map<String, dynamic> data,
  ) : super(Action.update, uuid, data);
}

class RemoveMissionPart extends MissionPartCommand<MissionPartRemoved> {
  RemoveMissionPart(
    String uuid,
    Map<String, dynamic> data,
  ) : super(Action.delete, uuid, data);
}

//////////////////////////////////
// MissionResult entity commands
//////////////////////////////////

class MissionResultCommand<T extends DomainEvent> extends MissionCommand<T> implements EntityCommand<T> {
  MissionResultCommand(
    Action action,
    String uuid,
    Map<String, dynamic> data,
  ) : super(action, uuid: uuid, data: data);

  @override
  String get aggregateField => "results";

  @override
  int get entityId => data[entityIdFieldName] as int;

  @override
  String get entityIdFieldName => 'id';
}

class AddMissionResult extends MissionResultCommand<MissionResultAdded> {
  AddMissionResult(
    String uuid,
    Map<String, dynamic> data,
  ) : super(Action.create, uuid, data);
}

class UpdateMissionResult extends MissionResultCommand<MissionResultUpdated> {
  UpdateMissionResult(
    String uuid,
    Map<String, dynamic> data,
  ) : super(Action.update, uuid, data);
}

class RemoveMissionResult extends MissionResultCommand<MissionResultRemoved> {
  RemoveMissionResult(
    String uuid,
    Map<String, dynamic> data,
  ) : super(Action.delete, uuid, data);
}