import 'package:uuid/uuid.dart';
import 'package:test/test.dart';

import 'package:sarsys_app_server_test/sarsys_app_server_test.dart';

Future main() async {
  final harness = SarSysAppHarness()
    ..withEventStoreMock()
    ..install(restartForEachTest: true);

  test("POST /api/subjects not allowed", () async {
    await _prepare(harness);
    final uuid = Uuid().v4();
    final body = _createData(uuid);
    expectResponse(
      await harness.agent.post("/api/subjects/$uuid", body: body),
      405,
    );
  });

  test("POST /api/incidents/{uuid}/subjects/ returns status code 201 with empty body", () async {
    final iuuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = _createData(uuid);
    expectResponse(await harness.agent.post("/api/incidents/$iuuid/subjects", body: body), 201, body: null);
  });

  test("POST /api/subjects/ returns status code 400 when 'incident/uuid' is given", () async {
    final iuuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = _createData(uuid)
      ..addAll({
        'incident': {'uuid': 'string'}
      });
    expectResponse(
      await harness.agent.post("/api/incidents/$iuuid/subjects", body: body),
      400,
      body: 'Schema Subject has 1 errors: [/incident: is read only]',
    );
  });

  test("GET /api/subjects/{uuid} returns status code 200", () async {
    final iuuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = _createData(uuid);
    expectResponse(await harness.agent.post("/api/incidents/$iuuid/subjects", body: body), 201, body: null);
    final response = expectResponse(await harness.agent.get("/api/subjects/$uuid"), 200);
    final actual = await response.body.decode();
    expect(
      actual['data'],
      equals(body
        ..addAll({
          'incident': {'uuid': iuuid}
        })),
    );
  });

  test("GET /api/subjects returns status code 200 with offset=1 and limit=2", () async {
    final iuuid = await _prepare(harness);
    await harness.agent.post("/api/incidents/$iuuid/subjects", body: _createData(Uuid().v4()));
    await harness.agent.post("/api/incidents/$iuuid/subjects", body: _createData(Uuid().v4()));
    await harness.agent.post("/api/incidents/$iuuid/subjects", body: _createData(Uuid().v4()));
    await harness.agent.post("/api/incidents/$iuuid/subjects", body: _createData(Uuid().v4()));
    final response = expectResponse(await harness.agent.get("/api/subjects?offset=1&limit=2"), 200);
    final actual = await response.body.decode();
    expect(actual['total'], equals(4));
    expect(actual['offset'], equals(1));
    expect(actual['limit'], equals(2));
    expect(actual['entries'].length, equals(2));
  });

  test("PATCH /api/subjects/{uuid} is idempotent", () async {
    final iuuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = _createData(uuid);
    expectResponse(await harness.agent.post("/api/incidents/$iuuid/subjects", body: body), 201, body: null);
    expectResponse(await harness.agent.execute("PATCH", "/api/subjects/$uuid", body: body), 204, body: null);
    final response = expectResponse(await harness.agent.get("/api/subjects/$uuid"), 200);
    final actual = await response.body.decode();
    expect(
      actual['data'],
      equals(body
        ..addAll({
          'incident': {'uuid': iuuid}
        })),
    );
  });

  test("PATCH /api/subjects/{uuid} does not remove value objects", () async {
    final iuuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = _createData(uuid);
    expectResponse(await harness.agent.post("/api/incidents/$iuuid/subjects", body: body), 201, body: null);
    expectResponse(await harness.agent.execute("PATCH", "/api/subjects/$uuid", body: {}), 204, body: null);
    final response = expectResponse(await harness.agent.get("/api/subjects/$uuid"), 200);
    final actual = await response.body.decode();
    expect(
      actual['data'],
      equals(body
        ..addAll({
          'incident': {'uuid': iuuid}
        })),
    );
  });

  test("DELETE /api/subjects/{uuid} returns status code 204", () async {
    final iuuid = await _prepare(harness);
    final uuid = Uuid().v4();
    final body = _createData(uuid);
    expectResponse(await harness.agent.post("/api/incidents/$iuuid/subjects", body: body), 201, body: null);
    expectResponse(await harness.agent.delete("/api/subjects/$uuid"), 204);
  });
}

Future<String> _prepare(SarSysAppHarness harness) async {
  final iuuid = Uuid().v4();
  expectResponse(await harness.agent.post("/api/incidents", body: createIncident(iuuid)), 201);
  return iuuid;
}

Map<String, Object> _createData(String uuid) => createSubject(uuid);
