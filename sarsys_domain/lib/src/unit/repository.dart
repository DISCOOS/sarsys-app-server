import 'package:event_source/event_source.dart';

import 'aggregate.dart';
import 'commands.dart';
import 'events.dart';

class UnitRepository extends Repository<UnitCommand, Unit> {
  UnitRepository(EventStore store)
      : super(store: store, processors: {
          UnitCreated: (event) => UnitCreated(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitInformationUpdated: (event) => UnitInformationUpdated(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitMobilized: (event) => UnitMobilized(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitDeployed: (event) => UnitDeployed(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitRetired: (event) => UnitRetired(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitDeleted: (event) => UnitDeleted(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitMessageAdded: (event) => UnitMessageAdded(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitMessageUpdated: (event) => UnitMessageUpdated(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
          UnitMessageRemoved: (event) => UnitMessageRemoved(
                uuid: event.uuid,
                data: event.data,
                created: event.created,
              ),
        });

  @override
  Unit create(Map<String, Process> processors, String uuid, Map<String, dynamic> data) => Unit(
        uuid,
        processors,
        data: data,
      );
}