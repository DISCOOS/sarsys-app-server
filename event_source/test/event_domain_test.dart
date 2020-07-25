import 'package:event_source/event_source.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'foo.dart';
import 'harness.dart';

Future main() async {
  final harness = EventSourceHarness()
    ..withTenant()
    ..withPrefix()
    ..withLogger()
    ..withRepository<Foo>((store) => FooRepository(store), instances: 2)
    ..withProjections(projections: ['\$by_category', '\$by_event_type'])
    ..addServer(port: 4000)
    ..addServer(port: 4001)
    ..addServer(port: 4002)
    ..install();

  test('Repository should support build operation', () async {
    final repository = harness.get<FooRepository>();
    final ready = await repository.readyAsync();
    // Assert repository state
    expect(ready, equals(true), reason: 'Repository should be ready');
    expect(repository.count(), equals(0), reason: 'Repository should be empty');
  });

  test('Repository should emit events with correct patches', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();

    // Act
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {
      'property1': 'value1',
      'property2': 'value2',
      'property3': 'value3',
      'list1': [
        {'name': 'item1'},
        {'name': 'item2'},
      ]
    });
    foo.patch({
      'property1': 'patched',
      'property2': 'value2',
      'list1': [
        {'name': 'item3'},
      ],
    }, emits: FooUpdated);

    // Assert state
    final events = foo.getUncommittedChanges();
    expect(events.length, equals(2), reason: 'Events should contain two events');

    // Assert first event
    final changed1 = events.first.changed;
    final value1 = changed1.elementAt('property1');
    expect(value1, equals('value1'));
    var value2 = changed1.elementAt('property2');
    expect(value2, equals('value2'));
    var value3 = changed1.elementAt('property3');
    expect(value3, equals('value3'));
    var list1 = changed1.elementAt('list1');
    expect(list1, isA<List>());
    final item1 = changed1.elementAt('list1/0');
    expect(item1, isA<Map>());
    final item2 = changed1.elementAt('list1/1');
    expect(item2, isA<Map>());
    final name1 = changed1.elementAt('list1/0/name');
    expect(name1, equals('item1'));
    final name2 = changed1.elementAt('list1/1/name');
    expect(name2, equals('item2'));

    // Assert last event
    final changed2 = events.last.changed;
    final patched = changed2.elementAt('property1');
    expect(patched, equals('patched'));
    // Not given in patch, should not be in changes
    value3 = changed2.elementAt('property3');
    expect(value3, isNull);
    list1 = changed2.elementAt('list1');
    expect(list1, isA<List>());
    final item3 = changed2.elementAt('list1/0');
    expect(item3, isA<Map>());
    final name3 = changed2.elementAt('list1/0/name');
    expect(name3, equals('item3'));
  });

  test('Repository should support create -> patch -> push operations', () async {
    // Arrange
    final repository = harness.get<FooRepository>();
    final stream = harness.server().getStream(repository.store.aggregate);
    await repository.readyAsync();

    // Assert create operation
    final uuid = Uuid().v4();
    final foo = repository.get(uuid);
    expect(foo.uuid, equals(uuid), reason: 'Foo uuid should be $uuid');
    expect(foo.isNew, equals(true), reason: "Foo should be flagged as 'New'");
    expect(foo.isChanged, equals(true), reason: "Foo should be flagged as 'Changed'");
    expect(foo.isDeleted, equals(false), reason: "Foo should not be flagged as 'Deleted'");
    expect(stream.toEvents().isEmpty, equals(true), reason: 'Events should not be commited yet');

    // Assert patch operation
    foo.patch({'property': 'patched'}, emits: FooUpdated);
    expect(foo.data, containsPair('property', 'patched'), reason: "Foo should contain value 'patched'");
    expect(foo.isNew, equals(true), reason: "Foo should be flagged as 'New'");
    expect(foo.isChanged, equals(true), reason: "Foo should be flagged as 'Changed'");
    expect(foo.isDeleted, equals(false), reason: "Foo should not be flagged as 'Deleted'");
    expect(stream.toEvents().isEmpty, equals(true), reason: 'Events should not be commited yet');

    // Assert push operation
    final events = await repository.push(foo);
    expect(events.length, equals(2), reason: 'Push should return 2 events');
    expect(foo.isNew, equals(false), reason: "Foo should not be flagged as 'New' after push");
    expect(foo.isChanged, equals(false), reason: "Foo should not be flagged as 'Changed' after push");
    expect(foo.isDeleted, equals(false), reason: "Foo should not be flagged as 'Deleted' after push");
    expect(stream.toEvents().length, equals(2), reason: 'Stream should contain 2 events after push');
    expect(
      stream.toEvents().keys,
      equals(
        events.map((event) => event.uuid),
      ),
      reason: 'Stream should only contain events returned by push',
    );
  });

  test('Repository should only apply operations [add, replace, move] when patching local changes', () async {
    // Arrange
    final repository = harness.get<FooRepository>();
    await repository.readyAsync();

    // Act
    final uuid = Uuid().v4();
    final foo = repository.get(uuid, data: {
      'property1': 'value1',
      'property2': 'value2',
      'list1': ['item1', 'item2'],
      'object1': {
        'member1': 'value1',
        'member2': 'value2',
      }
    });
    foo.patch({
      'property3': 'value3',
      'property2': 'value4',
      'list1': ['item3'],
      'object1': {
        'member2': 'value4',
        'member3': 'value3',
      }
    }, emits: FooUpdated);

    // Assert
    expect(foo.data, containsPair('property1', 'value1')); // keep
    expect(foo.data, containsPair('property3', 'value3')); // add value
    expect(foo.data, containsPair('property2', 'value4')); // replace value
    expect(foo.data, containsPair('list1', ['item3'])); // replace list of values
    expect(
        foo.data,
        containsPair('object1', {
          'member1': 'value1',
          'member2': 'value4',
          'member3': 'value3',
        }));
  });

  test('Repository should only apply operations [add, replace, move] when patching remote changes', () async {
    // Arrange
    final repo1 = harness.get<FooRepository>(port: 4000);
    final repo2 = harness.get<FooRepository>(port: 4001);
    await repo1.readyAsync();
    await repo2.readyAsync();

    // Act
    final uuid = Uuid().v4();
    final foo1 = repo1.get(uuid, data: {
      'property1': 'value1',
      'property2': 'value2',
      'list1': ['item1', 'item2'],
      'object1': {
        'member1': 'value1',
        'member2': 'value2',
      }
    });
    await repo1.push(foo1);
    await repo2.store.asStream().first;
    final foo2 = repo2.get(uuid);
    foo2.patch({
      'property3': 'value3',
      'property2': 'value4',
      'list1': ['item3'],
      'object1': {
        'member2': 'value4',
        'member3': 'value3',
      }
    }, emits: FooUpdated);
    await repo2.push(foo2);
    await repo1.store.asStream().first;

    // Assert
    expect(foo1.data, containsPair('property1', 'value1')); // keep
    expect(foo1.data, containsPair('property3', 'value3')); // add value
    expect(foo1.data, containsPair('property2', 'value4')); // replace value
    expect(foo1.data, containsPair('list1', ['item3'])); // replace list of values
    expect(
        foo1.data,
        containsPair('object1', {
          'member1': 'value1',
          'member2': 'value4',
          'member3': 'value3',
        })); // keep, add and replace member values
  });

  test('Repository should catch-up to head of events in remote stream', () async {
    // Arrange
    final repo1 = harness.get<FooRepository>(port: 4000);
    final repo2 = harness.get<FooRepository>(port: 4001);
    final repo3 = harness.get<FooRepository>(port: 4002);
    await repo1.readyAsync();
    await repo2.readyAsync();
    await repo3.readyAsync();

    await _assertCatchUp(repo1, repo2, repo3, 1);
    await _assertCatchUp(repo1, repo2, repo3, 2);
    await _assertCatchUp(repo1, repo2, repo3, 3);
    await _assertCatchUp(repo1, repo2, repo3, 4);
    await _assertCatchUp(repo1, repo2, repo3, 5);
    await _assertCatchUp(repo1, repo2, repo3, 6);
  });

  test('Repository should resolve concurrent remote modification on push', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    final stream = harness.server().getStream(repo.store.aggregate);
    await repo.readyAsync();

    // Act - Simulate concurrent modification by manually updating remote stream
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 'value1'});
    await repo.push(foo);
    stream.append('${stream.instanceStream}-0', [
      TestStream.asSourceEvent<FooUpdated>(
        uuid,
        {'property1': 'value1'},
        {
          'property1': 'value1',
          'property2': 'value2',
          'property3': 'value3',
        },
      )
    ]);

    // Act
    foo.patch({'property3': 'value3'}, emits: FooUpdated);
    await repo.push(foo);
    foo.patch({'property4': 'value4'}, emits: FooUpdated);
    await repo.push(foo);
    foo.patch({'property5': 'value5'}, emits: FooUpdated);
    await repo.push(foo);

    // Assert conflict resolved
    expect(repo.count(), equals(1));
    expect(foo.data, containsPair('property1', 'value1'));
    expect(foo.data, containsPair('property2', 'value2'));
    expect(foo.data, containsPair('property3', 'value3'));
    expect(foo.data, containsPair('property4', 'value4'));
    expect(foo.data, containsPair('property5', 'value5'));
  });

  test('Repository should fail on push when manual merge is needed', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    final stream = harness.server().getStream(repo.store.aggregate);
    await repo.readyAsync();

    // Act - Simulate conflict by manually updating remote stream
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 'value1'});
    await repo.push(foo);
    stream.append('${stream.instanceStream}-0', [
      TestStream.asSourceEvent<FooUpdated>(
        uuid,
        {'property1': 'value1'},
        {
          'property1': 'value1',
          'property2': 'value2',
          'property3': 'value3',
        },
      )
    ]);
    foo.patch({'property3': 'value4'}, emits: FooUpdated);

    // Assert
    await expectLater(repo.push(foo), throwsA(const TypeMatcher<ConflictNotReconcilable>()));

    // Assert conflict resolved
    expect(repo.count(), equals(1));
    expect(foo.data, containsPair('property1', 'value1'));
    expect(foo.data, containsPair('property2', 'value2'));
    expect(foo.data, containsPair('property3', 'value3'));
  });

  test('Repository should consume events with strategy RoundRobin', () async {
    // Arrange
    final repo1 = harness.get<FooRepository>(instance: 1)..compete(consume: 1);
    final repo2 = harness.get<FooRepository>(instance: 2)..compete(consume: 1);
    harness.server().withSubscription(repo1.store.aggregate, group: '${repo1.aggregateType}');
    final stream = harness.server().getStream(repo1.store.aggregate);
    await repo1.readyAsync();
    await repo2.readyAsync();

    // Act
    final uuid1 = Uuid().v4();
    stream.append('${stream.instanceStream}-0', [
      TestStream.asSourceEvent<FooCreated>(
        uuid1,
        {},
        {'property1': 'value1'},
      )
    ]);
    final uuid2 = Uuid().v4();
    stream.append('${stream.instanceStream}-1', [
      TestStream.asSourceEvent<FooCreated>(
        uuid2,
        {},
        {'property2': 'value2'},
      )
    ]);

    // Assert
    await repo1.store.asStream().first;
    final foo1 = repo1.get(uuid1);
    expect(repo1.count(), equals(1));
    expect(foo1.data, containsPair('property1', 'value1'));

    await repo2.store.asStream().first;
    final foo2 = repo2.get(uuid2);
    expect(repo2.count(), equals(1));
    expect(foo2.data, containsPair('property2', 'value2'));
  });

  test('Repository should throw AggregateNotFound on push with unknown AggregateRoot', () async {
    // Arrange - start two empty repos both assuming stream-0 to be first write
    final repo1 = harness.get<FooRepository>(instance: 1);
    await repo1.readyAsync();
    final repo2 = harness.get<FooRepository>(instance: 2);
    await repo2.readyAsync();

    // Act
    final foo1 = repo1.get(Uuid().v4());

    // Assert
    await expectLater(() => repo2.push(foo1), throwsA(isA<AggregateNotFound>()));
  });

  test('Repository should enforce strict order of in-proc create aggregate operations', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();

    // Act - execute pushes without awaiting the result
    final results = await Future.wait<Iterable<DomainEvent>>(_createMultiple(repo).cast());

    // Assert - strict order
    final events = _assertStrictOrder(results);

    // Assert - unique events
    _assertUniqueEvents(repo, events);
  });

  test('Repository should enforce strict incremental order of in-proc command executions', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 0});
    final created = await repo.push(foo);

    // Act - execute pushes without awaiting the result
    final results = await Future.wait<Iterable<DomainEvent>>(
      List.generate(
        10,
        (_) => repo.execute(UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1})),
      ),
    );

    // Assert - strict order
    final events = [
      ...created,
      ..._assertMonotonePatch(results),
    ];

    // Assert - unique events
    _assertUniqueEvents(repo, events);
  });

  test('Repository should resolve concurrent remote modification on command execute', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    final stream = harness.server().getStream(repo.store.aggregate);
    await repo.readyAsync();

    // Act - Simulate concurrent modification by manually updating remote stream
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 'value1'});
    await repo.push(foo);
    stream.append('${stream.instanceStream}-0', [
      TestStream.asSourceEvent<FooUpdated>(
        uuid,
        {'property1': 'value1'},
        {
          'property1': 'value1',
          'property2': 'value2',
          'property3': 'value3',
        },
      )
    ]);

    // Act
    await repo.execute(UpdateFoo({'uuid': uuid, 'property3': 'value3'}));

    // Assert conflict resolved
    expect(repo.count(), equals(1));
    expect(foo.data, containsPair('property1', 'value1'));
    expect(foo.data, containsPair('property2', 'value2'));
    expect(foo.data, containsPair('property3', 'value3'));
  });

  test('Repository should enforce strict order of concurrent create aggregate operations ', () async {
    // Arrange
    final repo1 = harness.get<FooRepository>(port: 4000);
    final repo2 = harness.get<FooRepository>(port: 4001);
    await repo1.readyAsync();
    await repo2.readyAsync();

    // Act - execute pushes and await the results
    final requests1 = _createMultiple(repo1);
    final requests2 = _createMultiple(repo2);
    final requests = List.from(requests1)..addAll(requests2);
    final results = await Future.wait<Iterable<DomainEvent>>(requests.cast());

    // Assert - strict order
    _assertStrictOrder(results);
  });
}

Future _assertCatchUp(FooRepository repo1, FooRepository repo2, FooRepository repo3, int count) async {
  // Act
  final uuid = Uuid().v4();
  final foo1 = repo1.get(uuid, data: {'property1': 'value1'});
  final events = await repo1.push(foo1);
  final remote1 = await repo2.store.asStream().first;
  final remote2 = await repo3.store.asStream().first;
  final foo2 = repo2.get(uuid);
  final foo3 = repo3.get(uuid);

  // Assert catch-up event from repo1
  expect(repo2.count(), equals(count));
  expect(repo3.count(), equals(count));
  expect([remote1], containsAll(events));
  expect([remote2], containsAll(events));
  expect(foo1.data, containsPair('property1', 'value1'));
  expect(foo2.data, containsPair('property1', 'value1'));
  expect(foo3.data, containsPair('property1', 'value1'));
}

Iterable<DomainEvent> _assertStrictOrder(List<Iterable<DomainEvent>> results) {
  final events = <DomainEvent>[];
  for (var i = 0; i < 10; i++) {
    expect(
      results[i].length,
      equals(1),
      reason: 'Should contain one event',
    );
    final event = results[i].first;
    events.add(event);
    expect(event, isA<FooCreated>());
    expect((event as FooCreated).index, equals(i));
  }
  return events;
}

Iterable<DomainEvent> _assertMonotonePatch(List<Iterable<DomainEvent>> results) {
  final events = <DomainEvent>[];
  for (var i = 0; i < 10; i++) {
    expect(
      results[i].length,
      equals(1),
      reason: 'Result $i should contain one event',
    );
    final event = results[i].first;
    events.add(event);
    expect(event, isA<FooUpdated>());
    expect(
      (event as FooUpdated).data.elementAt('changed/property1'),
      equals(i + 1),
      reason: 'Result ${results[i]} should be an monotone increment',
    );
  }
  return events;
}

void _assertUniqueEvents(Repository repo, Iterable<DomainEvent> events) {
  final actual = repo.store.events.values.fold(
    <String>[],
    (uuids, items) => uuids..addAll(items.map((e) => e.uuid)),
  );
  final expected = events.map((e) => e.uuid).toList();
  expect(expected, equals(actual));
}

List<Future<Iterable<DomainEvent>>> _createMultiple(FooRepository repo) {
  final operations = <Future<Iterable<DomainEvent>>>[];
  for (var i = 0; i < 10; i++) {
    operations.add(repo.push(repo.get(Uuid().v4(), data: {'index': i})));
  }
  return operations;
}
