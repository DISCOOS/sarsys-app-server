import 'package:sarsys_domain/sarsys_domain.dart';
import 'package:event_source/event_source.dart';
import 'package:uuid/uuid.dart';
import 'package:test/test.dart';

import 'harness.dart';

Future main() async {
  final harness = SarSysHarness()
    ..withEventStoreMock()
    ..install(restartForEachTest: true);

  test("POST /api/incident/{uuid}/subject adds subject to aggregate list", () async {
    await _install(harness);
    final incidentUuid = Uuid().v4();
    final incident = createIncident(incidentUuid);
    expectResponse(await harness.agent.post("/api/incidents", body: incident), 201, body: null);
    final subjectUuid = Uuid().v4();
    final subject = _createData(subjectUuid);
    expectResponse(
      await harness.agent.post("/api/incidents/$incidentUuid/subjects", body: subject),
      201,
      body: null,
    );
    await expectAggregateReference(
      harness,
      uri: '/api/subjects',
      childUuid: subjectUuid,
      child: subject,
      parentField: 'incident',
      parentUuid: incidentUuid,
    );
    await expectAggregateInList(
      harness,
      uri: '/api/incidents',
      uuid: incidentUuid,
      data: incident,
      listField: 'subjects',
      uuids: [
        'string',
        subjectUuid,
      ],
    );
  });

  test("GET /api/incident/{uuid}/subjects returns status code 200 with offset=1 and limit=2", () async {
    await _install(harness);
    final uuid = Uuid().v4();
    final incident = createIncident(uuid);
    expectResponse(await harness.agent.post("/api/incidents", body: incident), 201, body: null);
    await harness.agent.post("/api/incidents/$uuid/subjects", body: _createData(Uuid().v4()));
    await harness.agent.post("/api/incidents/$uuid/subjects", body: _createData(Uuid().v4()));
    await harness.agent.post("/api/incidents/$uuid/subjects", body: _createData(Uuid().v4()));
    await harness.agent.post("/api/incidents/$uuid/subjects", body: _createData(Uuid().v4()));
    final response = expectResponse(await harness.agent.get("/api/subjects?offset=1&limit=2"), 200);
    final actual = await response.body.decode();
    expect(actual['total'], equals(4));
    expect(actual['offset'], equals(1));
    expect(actual['limit'], equals(2));
    expect(actual['entries'].length, equals(2));
  });

  test("DELETE /api/subjects/{uuid} should remove {uuid} from subjects list in incident", () async {
    await _install(harness);
    final incidentUuid = Uuid().v4();
    final incident = createIncident(incidentUuid);
    expectResponse(await harness.agent.post("/api/incidents", body: incident), 201, body: null);
    final subjectUuid = Uuid().v4();
    final body = _createData(subjectUuid);
    expectResponse(await harness.agent.post("/api/incidents/$incidentUuid/subjects", body: body), 201, body: null);
    expectResponse(await harness.agent.delete("/api/subjects/$subjectUuid"), 204);
    final response = expectResponse(await harness.agent.get("/api/incidents/$incidentUuid"), 200);
    final actual = await response.body.decode();
    expect(actual['data'], equals(incident));
  });
}

Future _install(SarSysHarness harness) async {
  harness.eventStoreMockServer
    ..withStream(typeOf<Incident>().toColonCase())
    ..withStream(typeOf<Subject>().toColonCase());
  await harness.channel.manager.get<IncidentRepository>().readyAsync();
  await harness.channel.manager.get<SubjectRepository>().readyAsync();
}

Map<String, Object> _createData(String uuid) => createSubject(uuid);