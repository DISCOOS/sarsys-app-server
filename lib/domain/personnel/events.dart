import 'package:meta/meta.dart';
import 'package:sarsys_app_server/eventsource/eventsource.dart';

//////////////////////////////////////
// Personnel Domain Events
//////////////////////////////////////

class PersonnelCreated extends DomainEvent {
  PersonnelCreated({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: "$PersonnelCreated",
          created: created,
          data: data,
        );
}

class PersonnelInformationUpdated extends DomainEvent {
  PersonnelInformationUpdated({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: "$PersonnelInformationUpdated",
          created: created,
          data: data,
        );
}

class PersonnelMobilized extends DomainEvent {
  PersonnelMobilized({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: "$PersonnelMobilized",
          created: created,
          data: data,
        );
}

class PersonnelDeployed extends DomainEvent {
  PersonnelDeployed({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: "$PersonnelDeployed",
          created: created,
          data: data,
        );
}

class PersonnelRetired extends DomainEvent {
  PersonnelRetired({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: "$PersonnelRetired",
          created: created,
          data: data,
        );
}

class PersonnelDeleted extends DomainEvent {
  PersonnelDeleted({
    @required String uuid,
    @required DateTime created,
    @required Map<String, dynamic> data,
  }) : super(
          uuid: uuid,
          type: "$PersonnelDeleted",
          created: created,
          data: data,
        );
}