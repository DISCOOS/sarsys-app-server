import 'package:meta/meta.dart';

import 'package:event_source/event_source.dart';
import 'package:sarsys_domain/src/incident/repository.dart';

import 'aggregate.dart';
import 'commands.dart';
import 'events.dart';

class SubjectRepository extends Repository<SubjectCommand, Subject> {
  SubjectRepository(
    EventStore store, {
    @required this.incidents,
  }) : super(store: store, processors: {
          SubjectRegistered: (event) => SubjectRegistered(event),
          SubjectUpdated: (event) => SubjectUpdated(event),
          SubjectDeleted: (event) => SubjectDeleted(event)
        });

  final IncidentRepository incidents;

  @override
  void willStartProcessingEvents() {
    // Remove Subject from 'subjects' list when deleted
    rule<SubjectDeleted>(incidents.newRemoveSubjectRule);

    super.willStartProcessingEvents();
  }

  @override
  Subject create(Map<Type, ProcessCallback> processors, String uuid, Map<String, dynamic> data) => Subject(
        uuid,
        processors,
        data: data,
      );
}
