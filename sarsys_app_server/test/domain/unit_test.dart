import 'package:uuid/uuid.dart';
import 'package:test/test.dart';

import 'package:sarsys_app_server_test/sarsys_app_server_test.dart';

Future main() async {
  final harness = SarSysAppHarness()
    ..withEventStoreMock()
    ..install(restartForEachTest: true);

  test("POST /api/units returns 405", () async {
    await _prepare(harness);
    final uuid = Uuid().v4();
    final body = createUnit(uuid);
    expectResponse(await harness.agent.post("/api/units", body: body), 405, body: null);
  });

  test("GET /api/units/{uuid} returns 200", () async {
    final ouuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = createUnit(uuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: body), 201, body: null);
    final response = expectResponse(await harness.agent.get("/api/units/$uuid"), 200);
    final actual = await response.body.decode();
    expect(
      actual['data'],
      equals(body
        ..addAll({
          'operation': {'uuid': ouuid},
          // Default collections
          'personnels': [],
        })),
    );
  });

  test("GET /api/units returns 200 with offset=1 and limit=2", () async {
    final ouuid = await _prepare(harness);
    await harness.agent.post("/api/operations/$ouuid/units", body: createUnit(Uuid().v4()));
    await harness.agent.post("/api/operations/$ouuid/units", body: createUnit(Uuid().v4()));
    await harness.agent.post("/api/operations/$ouuid/units", body: createUnit(Uuid().v4()));
    await harness.agent.post("/api/operations/$ouuid/units", body: createUnit(Uuid().v4()));
    final response = expectResponse(await harness.agent.get("/api/units?offset=1&limit=2"), 200);
    final actual = await response.body.decode();
    expect(actual['total'], equals(4));
    expect(actual['offset'], equals(1));
    expect(actual['limit'], equals(2));
    expect(actual['entries'].length, equals(2));
  });

  test("PATCH /api/units/{uuid} is idempotent", () async {
    final ouuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = createUnit(uuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: body), 201, body: null);
    expectResponse(await harness.agent.execute("PATCH", "/api/units/$uuid", body: body), 204, body: null);
    final response = expectResponse(await harness.agent.get("/api/units/$uuid"), 200);
    final actual = await response.body.decode();
    expect(
      actual['data'],
      equals(body
        ..addAll({
          'operation': {'uuid': ouuid},
          // Default collections
          'personnels': [],
        })),
    );
  });

  test("PATCH /api/units/{uuid} returns 200 with personnels that exists", () async {
    final ouuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final tuuid = Uuid().v4();
    final puuid1 = Uuid().v4();
    final puuid2 = Uuid().v4();
    await _createPersonnel(harness, ouuid, puuid1);
    await _createPersonnel(harness, ouuid, puuid2);
    final body = createUnit(uuid, tuuid: tuuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: body), 201, body: null);
    final next = Map.from(body)
      ..addAll({
        'personnels': [puuid1, puuid2]
      });
    expectResponse(await harness.agent.execute("PATCH", "/api/units/$uuid", body: next), 200, body: null);
  });

  test("PATCH /api/units/{uuid} returns 404 with personnels that does not exists", () async {
    final ouuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final tuuid = Uuid().v4();
    final puuid1 = Uuid().v4();
    final puuid2 = Uuid().v4();
    await _createPersonnel(harness, ouuid, puuid1);
    final body = createUnit(uuid, tuuid: tuuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: body), 201, body: null);
    final next = Map.from(body)
      ..addAll({
        'personnels': [puuid1, puuid2]
      });
    expectResponse(await harness.agent.execute("PATCH", "/api/units/$uuid", body: next), 404, body: null);
  });

  test("PATCH /api/units/{uuid} does not remove value objects", () async {
    final ouuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = createUnit(uuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: body), 201, body: null);
    expectResponse(await harness.agent.execute("PATCH", "/api/units/$uuid", body: {}), 204, body: null);
    final response = expectResponse(await harness.agent.get("/api/units/$uuid"), 200);
    final actual = await response.body.decode();
    expect(
      actual['data'],
      equals(body
        ..addAll({
          'operation': {'uuid': ouuid},
          // Default collections
          'personnels': [],
        })),
    );
  });

  test("PATCH /api/units/{uuid} created tracking if not exists", () async {
    final uuid = Uuid().v4();
    final tuuid = Uuid().v4();
    final ouuid = await _prepare(harness);
    final existing = createUnit(uuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: existing), 201, body: null);
    final response1 = expectResponse(
      await harness.agent.execute(
        "PATCH",
        "/api/units/$uuid",
        body: {
          'tracking': {'uuid': tuuid}
        },
      ),
      200,
    );
    final personnel = await response1.body.decode();
    expect(
      personnel['data'],
      equals(existing
        ..addAll({
          'personnels': [],
          'tracking': {'uuid': tuuid},
          'operation': {'uuid': ouuid},
        })),
    );
    final response2 = expectResponse(await harness.agent.get("/api/trackings/$tuuid"), 200);
    final tracking = await response2.body.decode();
    expect(
      tracking['data'],
      equals({
        'uuid': tuuid,
        'tracks': [],
        'sources': [
          {'uuid': uuid, 'type': 'trackable'}
        ]
      }),
    );
  });

  test("PATCH /api/units/{uuid} not allowed if tracking already exist", () async {
    final uuid = Uuid().v4();
    final tuuid1 = Uuid().v4();
    final tuuid2 = Uuid().v4();
    final ouuid = await _prepare(harness);
    final existing = createUnit(uuid, tuuid: tuuid1);
    final updated = Map.from(existing)
      ..addAll({
        'tracking': {'uuid': tuuid2},
        'operation': {'uuid': ouuid},
      });
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: existing), 201, body: null);
    final response = expectResponse(
      await harness.agent.execute("PATCH", "/api/units/$uuid", body: updated),
      409,
    );
    final actual = Map.from(await response.body.decode());
    expect(
      actual,
      equals({
        'mine': null,
        'yours': null,
        'base': Map.from(existing)
          ..addAll({
            'personnels': [],
            'tracking': {'uuid': tuuid1},
            'operation': {'uuid': ouuid},
          }),
        'type': 'exists',
        'code': 'duplicate_tracking_uuid',
        'error': 'Unit $uuid is already tracked by $tuuid1',
      }),
    );
  });

  test("DELETE /api/units/{uuid} returns 204", () async {
    final ouuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = createUnit(uuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: body), 201, body: null);
    expectResponse(await harness.agent.delete("/api/units/$uuid"), 204);
  });

  test("DELETE /api/units/{uuid} returns 204 with tracking enabled", () async {
    final ouuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final tuuid = Uuid().v4();
    final body = createUnit(uuid, tuuid: tuuid);
    expectResponse(await harness.agent.post("/api/operations/$ouuid/units", body: body), 201, body: null);
    expectResponse(await harness.agent.delete("/api/units/$uuid"), 204);
  });
}

Future _createPersonnel(SarSysAppHarness harness, String ouuid, String puuid) async {
  final auuid = Uuid().v4();
  await _createAffiliation(harness, puuid, auuid);
  expectResponse(
    await harness.agent.post("/api/operations/$ouuid/personnels", body: createPersonnel(puuid, auuid: auuid)),
    201,
    body: null,
  );
}

Future<String> _createAffiliation(SarSysAppHarness harness, String puuid, String auuid) async {
  expectResponse(await harness.agent.post("/api/persons", body: createPerson(puuid)), 201);
  final orguuid = Uuid().v4();
  expectResponse(await harness.agent.post("/api/organisations", body: createOrganisation(orguuid)), 201);
  expectResponse(
      await harness.agent.post("/api/affiliations",
          body: createAffiliation(
            auuid,
            puuid: puuid,
            orguuid: orguuid,
          )),
      201);
  return auuid;
}

Future<String> _prepare(SarSysAppHarness harness) async {
  final iuuid = Uuid().v4();
  expectResponse(await harness.agent.post("/api/incidents", body: createIncident(iuuid)), 201);
  final ouuid = Uuid().v4();
  expectResponse(await harness.agent.post("/api/incidents/$iuuid/operations", body: createOperation(ouuid)), 201);
  return ouuid;
}
