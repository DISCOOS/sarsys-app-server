import 'package:event_source/event_source.dart';

import 'aggregate.dart';
import 'events.dart';

abstract class OrganisationCommand<T extends DomainEvent> extends Command<T> {
  OrganisationCommand(
    Action action, {
    String uuid,
    Map<String, dynamic> data = const {},
  }) : super(action, uuid: uuid, data: data);
}

//////////////////////////////////
// Organisation aggregate commands
//////////////////////////////////

class CreateOrganisation extends OrganisationCommand<OrganisationCreated> {
  CreateOrganisation(
    Map<String, dynamic> data,
  ) : super(Action.create, data: data);
}

class UpdateOrganisation extends OrganisationCommand<OrganisationInformationUpdated> {
  UpdateOrganisation(
    Map<String, dynamic> data,
  ) : super(Action.update, data: data);
}

class AddDivisionToOrganisation extends OrganisationCommand<DivisionAddedToOrganisation> {
  AddDivisionToOrganisation(
    Organisation organisation,
    String duuid,
  ) : super(
          Action.update,
          uuid: organisation.uuid,
          data: Command.addToList<String>(organisation.data, 'divisions', [duuid]),
        );
}

class RemoveDivisionFromOrganisation extends OrganisationCommand<DivisionRemovedFromOrganisation> {
  RemoveDivisionFromOrganisation(
    Organisation organisation,
    String duuid,
  ) : super(
          Action.update,
          uuid: organisation.uuid,
          data: Command.removeFromList<String>(organisation.data, 'divisions', [duuid]),
        );
}

class DeleteOrganisation extends OrganisationCommand<OrganisationDeleted> {
  DeleteOrganisation(
    Map<String, dynamic> data,
  ) : super(Action.delete, data: data);
}
