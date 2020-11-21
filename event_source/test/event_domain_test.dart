import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:hive/hive.dart';
import 'package:json_patch/json_patch.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:async/async.dart';
import 'package:pedantic/pedantic.dart';

import 'package:event_source/event_source.dart';
import 'package:event_source/src/models/aggregate_root_model.dart';
import 'package:event_source/src/models/event_number_model.dart';
import 'package:event_source/src/models/snapshot_model.dart';

import 'bar.dart';
import 'foo.dart';
import 'harness.dart';

Future main() async {
  final harness = EventSourceHarness()
    ..withTenant()
    ..withPrefix()
    ..withLogger(debug: false)
    ..withSnapshot()
    ..withRepository<Foo>(
      (manager, store, instance) => FooRepository(store, instance),
      instances: 2,
    )
    ..withRepository<Bar>(
      (manager, store, instance) => BarRepository(
        store,
        instance,
        manager.get<FooRepository>(),
      ),
      instances: 2,
    )
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
    final events = foo.getLocalEvents();
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
    // Not given in patch, should be unchanged
    value3 = changed2.elementAt('property3');
    expect(value3, 'value3');
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
    expect(stream.toEvents().isEmpty, equals(true), reason: 'Events should not be committed yet');

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

  test('Repository should update field createdBy after create and push', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();

    // Act
    final uuid = Uuid().v4();
    final foo = repo.get(uuid);
    final createdBy = foo.createdBy;
    final createdLocally = createdBy.created;
    unawaited(repo.push(foo));

    // Allow subscription to catch up
    await repo.store.asStream().where(
      (event) {
        return event.remote;
      },
    ).first;
    final createdWhen = repo.get(uuid).createdWhen;

    // Assert
    expect(foo.createdBy, equals(createdBy), reason: 'createdBy should not change identity');
    expect(
      createdWhen,
      isNot(equals(createdLocally)),
      reason: 'createdBy should change created datetime',
    );
  });

  test('Repository should update field updatedBy after patch and push', () async {
    // Arrange
    final repository = harness.get<FooRepository>();
    await repository.readyAsync();

    // Act
    final uuid = Uuid().v4();
    final foo = repository.get(uuid);
    foo.patch({'property': 'patched'}, emits: FooUpdated);
    final createdBy = foo.createdBy;
    final changedBy = foo.changedBy;
    expect(
      createdBy,
      isNot(equals(changedBy)),
      reason: 'Patch should changed updatedBy',
    );
    unawaited(repository.push(foo));

    // Allow subscription to catch up
    await repository.store.asStream().take(4).toList();
    final changedWhen = repository.get(uuid).changedWhen;

    // Assert
    expect(
      identical(foo.changedBy, changedBy),
      isFalse,
      reason: 'changedBy should change identity',
    );
    expect(
      changedWhen,
      isNot(equals(changedBy.created)),
      reason: 'changedBy should not change created datetime',
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
    unawaited(repo1.push(foo1));
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
    unawaited(repo2.push(foo2));
    await repo1.store.asStream().where((event) {
      return event.type == 'FooUpdated';
    }).first;

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

  test('Repository should not push local aggregate with local concurrent modifications', () async {
    // Arrange - local aggregate
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 0});

    // Act on repo without waiting
    final request1 = repo.execute(
      UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1}),
    );
    final request2 = repo.execute(
      UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1}),
    );

    // Assert that exception is thrown
    await expectLater(
      // Will not on each command
      // before executing the next
      Future.wait<Iterable<DomainEvent>>(
        [request1, request2],
      ),
      throwsA(isA<ConcurrentWriteOperation>()),
    );

    // Assert
    expect(foo.isChanged, isFalse);
    expect(foo.getLocalEvents(), isEmpty);
    expect(foo.data, containsPair('property1', 1));
    expect(repo.count(), equals(1));
    expect(repo.inTransaction(uuid), isFalse);
  });

  test('Repository should not push remote aggregate with local concurrent modifications', () async {
    // Arrange - remote aggregate
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 0});
    await repo.push(foo);

    // Act on repo without waiting
    final request1 = repo.execute(
      UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1}),
    );
    final request2 = repo.execute(
      UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1}),
    );

    // Assert that exception is thrown
    await expectLater(
      // Will not on each command
      // before executing the next
      Future.wait<Iterable<DomainEvent>>(
        [request1, request2],
      ),
      throwsA(isA<ConcurrentWriteOperation>()),
    );

    // Assert
    expect(foo.isChanged, isFalse);
    expect(foo.getLocalEvents(), isEmpty);
    expect(foo.data, containsPair('property1', 1));
    expect(repo.count(), equals(1));
    expect(repo.inTransaction(uuid), isFalse);
  });

  test('Repository should resolve remote concurrent modification on push', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    final stream = harness.server().getStream(repo.store.aggregate);
    await repo.readyAsync();
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 'value1'});
    await repo.push(foo);
    expect(foo.number.value, equals(0));

    // Simulate concurrent modification
    // by manually updating remote stream
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
    expect(foo.number.value, equals(4), reason: 'Should be 4');
    expect(repo.number.value, equals(4), reason: 'Should be 4');
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
          'property3': 'remote',
        },
      )
    ]);
    foo.patch({'property3': 'local'}, emits: FooUpdated);

    // Assert
    await expectLater(
      repo.push(foo),
      throwsA(isA<ConflictNotReconcilable>()),
    );

    // Assert conflict unresolved
    expect(repo.count(), equals(1));
    expect(foo.data, containsPair('property1', 'value1'));
    expect(foo.data, containsPair('property2', 'value2'));
    expect(foo.data, containsPair('property3', 'remote'));
  });

  test('Repository should not push on execute in an transaction', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    final uuid = Uuid().v4();
    final trx = repo.getTransaction(uuid);
    final foo = repo.get(uuid, data: {'property1': 1});

    // Act on repo
    await repo.execute(
      UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1}),
    );

    // Act on transaction
    await trx.execute(
      UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1}),
    );

    // Assert
    expect(foo.isChanged, isTrue);
    expect(foo.getLocalEvents(), isNotEmpty);
    expect(await trx.push(), isA<Iterable<DomainEvent>>());
    expect(foo.isChanged, isFalse);
    expect(foo.getLocalEvents(), isEmpty);
    expect(repo.count(), equals(1));
    expect(repo.inTransaction(uuid), isFalse);
    expect(foo.data, containsPair('property1', 3));
  });

  test('Repository should commit transactions on push', () async {
    // Arrange
    final repo1 = harness.get<FooRepository>(instance: 1);
    final repo2 = harness.get<FooRepository>(instance: 2);
    await repo1.readyAsync();
    await repo2.readyAsync();

    final uuid1 = 'foo1';
    await repo1.push(repo1.get(uuid1, data: {'property1': 0}));
    final uuid2 = 'foo2';
    await repo2.push(repo2.get(uuid2, data: {'property1': 0}));
    final foo1 = repo1.get(uuid1);
    final foo2 = repo2.get(uuid2);

    await Future.delayed(Duration(seconds: 1));

    // Act on foo1 and foo2 concurrently
    for (var i = 1; i <= 5; i++) {
      final trx1 = repo1.getTransaction(uuid1);
      for (var j = 1; j <= 10; j++) {
        await repo1.execute(
          UpdateFoo({'uuid': uuid1, 'property1': repo1.get(uuid1).elementAt<int>('property1') + 1}),
        );
      }
      final trx2 = repo2.getTransaction(uuid2);
      for (var j = 1; j <= 10; j++) {
        await repo2.execute(
          UpdateFoo({'uuid': uuid2, 'property1': repo2.get(uuid2).elementAt<int>('property1') + 1}),
        );
      }
      await trx1.push();
      await trx2.push();
    }

    await Future.delayed(Duration(seconds: 1));

    // Assert state of foo1
    expect(foo1.isChanged, isFalse);
    expect(foo1.getLocalEvents(), isEmpty);
    expect(foo1.data, containsPair('property1', 50));

    // Assert state of foo2
    expect(foo2.isChanged, isFalse);
    expect(foo2.getLocalEvents(), isEmpty);
    expect(foo2.data, containsPair('property1', 50));

    // Assert state of repo1
    expect(repo1.count(), equals(2));
    expect(repo1.inTransaction(uuid1), isFalse);

    // Assert state of repo2
    expect(repo2.count(), equals(2));
    expect(repo2.inTransaction(uuid2), isFalse);

    // Assert events
    final stream = harness.server().getStream(typeOf<Foo>().toColonCase());
    expect(stream.instances[0].length, equals(51));
    expect(stream.instances[1].length, equals(51));
    expect(repo1.store.events[uuid1].length, equals(51));
    expect(repo1.store.events[uuid2].length, equals(51));
    expect(repo2.store.events[uuid1].length, equals(51));
    expect(repo2.store.events[uuid2].length, equals(51));

    // Assert event numbers
    expect(repo1.store.current().value, equals(101));
    expect(repo1.store.current(uuid: uuid1).value, equals(50));
    expect(repo1.store.current(uuid: uuid2).value, equals(50));
    expect(repo1.store.events[uuid1].last.number.value, equals(50));
    expect(repo2.store.current().value, equals(101));
    expect(repo2.store.current(uuid: uuid1).value, equals(50));
    expect(repo2.store.current(uuid: uuid2).value, equals(50));
    expect(repo2.store.events[uuid2].last.number.value, equals(50));
  });

  test('Transaction should fail on push when manual merge is needed', () async {
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
          'property3': 'remote',
        },
      )
    ]);

    // Act - make conflict patch
    final trx = repo.getTransaction(uuid);
    foo.patch({'property3': 'local'}, emits: FooUpdated);

    // Assert
    await expectLater(
      trx.push(),
      throwsA(isA<ConflictNotReconcilable>()),
    );

    // Assert conflict unresolved
    expect(repo.count(), equals(1));
    expect(repo.inTransaction(uuid), isFalse);
    expect(foo.data, containsPair('property1', 'value1'));
    expect(foo.data, containsPair('property2', 'value2'));
    expect(foo.data, containsPair('property3', 'remote'));
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

  test('Transaction should throw AggregateNotFound on push with unknown AggregateRoot', () async {
    // Arrange - start two empty repos both assuming stream-0 to be first write
    final repo1 = harness.get<FooRepository>(instance: 1);
    await repo1.readyAsync();
    final repo2 = harness.get<FooRepository>(instance: 2);
    await repo2.readyAsync();

    // Act
    final foo1 = repo1.get(Uuid().v4());

    // Assert
    final trx = repo2.getTransaction(foo1.uuid);
    await expectLater(() => trx.push(), throwsA(isA<AggregateNotFound>()));
    expect(repo2.inTransaction(foo1.uuid), isTrue);
  });

  test('Repository should enforce strict order of in-proc create aggregate operations', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();

    // Act - execute pushes without awaiting
    // the result. Note: Will not on each command
    // before executing the next
    final results = await Future.wait<Iterable<DomainEvent>>(
      _createMultipleAggregates(repo, 10).cast(),
    );

    // Assert - strict order
    final events = _assertResultStrictOrder(results);

    // Assert - unique events
    _assertUniqueEvents(repo, events);
  });

  test('Repository should enforce strict incremental order of in-proc command executions', () async {
    // Arrange1
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 0});
    final created = await repo.push(foo);

    // Act - execute pushes without awaiting the result
    final results = <Iterable<DomainEvent>>[];
    for (var i = 0; i < 10; i++) {
      results.add(await repo.execute(
        UpdateFoo({'uuid': uuid, 'property1': repo.get(uuid).elementAt<int>('property1') + 1}),
      ));
    }

    // Assert - strict order
    final events = [
      ...created,
      ..._assertMonotonePatch(results),
    ];

    // Assert - unique events
    _assertUniqueEvents(repo, events);
  });

  test('Repository should enforce strict order of event numbers', () async {
    // Arrange
    final uuid = Uuid().v4();
    final repo1 = harness.get<FooRepository>();
    final repo2 = harness.get<FooRepository>();
    await repo1.readyAsync();
    await repo2.readyAsync();

    // Act - execute
    unawaited(_createMultipleEvents(repo1, uuid, 10));
    final events = await takeLocal(repo2.store.asStream(), 10);
    expect(events.last.number.value, equals(9));

    // Assert - repo 1
    final events1 = _assertEventNumberStrictOrder(repo1, uuid);
    _assertUniqueEvents(repo1, events1);

    // Assert - repo 2
    final events2 = _assertEventNumberStrictOrder(repo2, uuid);
    _assertUniqueEvents(repo1, events2);
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
    expect(foo.hasConflicts, isFalse);
    expect(repo.number.value, equals(2));
  });

  test('Repository should enforce strict order of concurrent create aggregate operations ', () async {
    // Arrange
    final repo1 = harness.get<FooRepository>(port: 4000);
    final repo2 = harness.get<FooRepository>(port: 4001);
    await repo1.readyAsync();
    await repo2.readyAsync();
    final group = StreamGroup<Event>();
    await group.add(repo1.store.asStream());
    await group.add(repo2.store.asStream());

    // Act - execute pushes and await the results
    final requests1 = _createMultipleAggregates(repo1, 10, prefix: '4000');
    final requests2 = _createMultipleAggregates(repo2, 10, prefix: '4001');

    // Wait for subscriptions to catch up in both repos
    await takeRemote(group.stream, 2 * 2 * 10, distinct: false);
    await group.close();

    // Assert - strict order
    final results1 = await Future.wait<Iterable<DomainEvent>>(requests1);
    final results2 = await Future.wait<Iterable<DomainEvent>>(requests2);
    _assertResultStrictOrder(results1);
    _assertResultStrictOrder(results2);
    expect(repo1.number.value, equals(19));
    expect(repo2.number.value, equals(19));
  });

  test('Repository should rollback changes when command fails', () async {
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
    final command = UpdateFoo({
      'uuid': uuid,
      'property3': 'value4',
    });

    // Assert
    await expectLater(
      repo.execute(command),
      throwsA(isA<ConflictNotReconcilable>()),
    );
    expect(
      repo.isChanged,
      isFalse,
      reason: 'Repository should rollback changes when command fails',
    );
    expect(
      foo.isChanged,
      isFalse,
      reason: 'Repository should rollback changes when command fails',
    );
  });

  test('Repository should rollback changes when transaction fails', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    final stream = harness.server().getStream(repo.store.aggregate);
    await repo.readyAsync();
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {'property1': 'value1'});
    await repo.push(foo);
    final trx = repo.getTransaction(uuid);

    // Act - Simulate conflict by manually updating remote stream
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
    final command = UpdateFoo({
      'uuid': uuid,
      'property3': 'value4',
    });
    await trx.execute(command);

    // Assert
    await expectLater(
      trx.push(),
      throwsA(isA<ConflictNotReconcilable>()),
    );
    expect(repo.inTransaction(uuid), isFalse);
    expect(
      repo.isChanged,
      isFalse,
      reason: 'Repository should rollback changes when command fails',
    );
    expect(
      foo.isChanged,
      isFalse,
      reason: 'Repository should rollback changes when command fails',
    );
  });

  test('Repository should catchup before policy write', () async {
    // Arrange first server
    final foos1 = harness.get<FooRepository>(port: 4000);
    final bars1 = harness.get<BarRepository>(port: 4000);
    await foos1.readyAsync();
    await bars1.readyAsync();

    // Arrange second server
    final foos2 = harness.get<FooRepository>(port: 4001);
    final bars2 = harness.get<BarRepository>(port: 4001);
    await foos2.readyAsync();
    await bars2.readyAsync();

    final group = StreamGroup<Event>.broadcast();
    await group.add(foos1.store.asStream());
    await group.add(bars1.store.asStream());
    await group.add(foos2.store.asStream());
    await group.add(bars2.store.asStream());

    // Catch any events raised
    // before waiting on all
    // events to be seen
    final seen = <Event>[];
    group.stream.listen((event) {
      seen.add(event);
    });

    // Act on first server
    final fuuid = Uuid().v4();
    final fdata = {
      'uuid': fuuid,
      'property1': 'value1',
    };
    final foo = foos1.get(fuuid, data: fdata);
    // Ensure it exists before proceeding
    // (boo rule will not wait for catchup returns empty)
    await foos1.push(foo);

    // Act on second server
    final buuid = Uuid().v4();
    final bdata = {
      'uuid': buuid,
      // Bar has a rule that will match this
      'foo': {'uuid': fuuid}
    };
    final bar = bars2.get(buuid, data: bdata);
    unawaited(bars2.push(bar));

    // Wait for catchup
    // 3 local events
    // 3 _onReplace from subscription
    // 3 _onApply from subscription
    await group.stream.take(9 - seen.length).toList();
    // await group.close();

    // Assert all states are up to date
    fdata.addAll({'updated': 'value'});
    expect(foos1.get(fuuid).data, fdata, reason: 'Foo in instance 1 should be updated');
    expect(bars1.get(buuid).data, bdata, reason: 'Bar in instance 1 should be updated');
    expect(foos2.get(fuuid).data, fdata, reason: 'Foo in instance 2 should be updated');
    expect(bars2.get(buuid).data, bdata, reason: 'Bar in instance 2 should be updated');
  });

  test('Repository should build from last snapshot', () async {
    // Arrange
    await _testShouldBuildFromLastSnapshot(harness);
  });

  test('Repository push from last snapshot', () async {
    // Arrange
    await _testShouldBuildFromLastSnapshot(harness);
    final repo = harness.get<FooRepository>();
    final foo1 = repo.aggregates.first;
    final foo2 = repo.aggregates.last;

    // Act
    final event3 = foo1.patch({'property3': 'value3'}, emits: FooUpdated);
    await repo.push(foo1);
    final event4 = foo2.patch({'property3': 'value3'}, emits: FooUpdated);
    await repo.push(foo2);

    // Assert
    expect(repo.snapshot, isNotNull, reason: 'Should have a snapshot');
    expect(repo.number, repo.store.current(), reason: 'Should be equal');
    expect(repo.store.current(), equals(EventNumber(3)), reason: 'Should cumulate to (offset + events.length - 1)');
    expect(event3.number, repo.store.current(uuid: foo1.uuid), reason: 'Should be equal');
    expect(event4.number, repo.store.current(uuid: foo2.uuid), reason: 'Should be equal');

    expect(foo1.number, equals(event3.number));
    expect(foo2.number, equals(event4.number));
  });

  test('Repository should save snapshot manually', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    expect(repo.snapshot, isNull, reason: 'Should have NO snapshot');

    // Act
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {
      'property1': 'value1',
    });
    expect(foo.data, containsPair('property1', 'value1'));
    await repo.push(foo);
    expect(foo.applied.length, 1);

    // Act
    final snapshot = await repo.save();

    // Assert
    expect(repo.snapshot, isNotNull, reason: 'Should have a snapshot');
    expect(repo.snapshot.uuid, equals(snapshot.uuid), reason: 'Should have snapshot ${snapshot.uuid}');
    expect(repo.contains(uuid), isTrue, reason: 'Should contain aggregate root $uuid');
    final saved = repo.get(foo.uuid);
    expect(saved.number.value, equals(snapshot.number.value));
    expect(saved.data, equals(snapshot.aggregates.values.first.data));
    expect(saved.applied.length, 0, reason: 'Applied events should be cleared on save');
  });

  test('Repository should not save snapshot', () async {
    // Arrange
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    expect(repo.snapshot, isNull, reason: 'Should have NO snapshot');

    // Act
    final uuid = Uuid().v4();
    final foo = repo.get(uuid, data: {
      'property1': 'value1',
    });
    expect(foo.data, containsPair('property1', 'value1'));
    await repo.push(foo);

    // Act
    final snapshot1 = await repo.save();
    final snapshot2 = await repo.save();

    // Assert
    expect(snapshot1, equals(snapshot2), reason: 'Should not have a new snapshot');
  });

  test('Repository should save snapshot on threshold automatically', () async {
    // Arrange
    final threshold = 10;
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    repo.store.snapshots.keep = threshold;
    repo.store.snapshots.threshold = threshold;
    expect(repo.snapshot, isNull, reason: 'Should have NO snapshot');

    // Act
    final uuid = Uuid().v4();
    final foo = repo.get(uuid);
    for (var i = 1; i <= 100; i++) {
      foo.patch({'property1': 'value$i'}, emits: FooUpdated);
      await repo.push(foo);
    }
    final last = repo.get(foo.uuid);
    expect(last.data, containsPair('property1', 'value100'));
    expect(repo.number.value, equals(100));

    // Assert
    expect(repo.snapshot, isNotNull, reason: 'Should have snapshot');
    expect(repo.snapshot.number.value, equals(100), reason: 'Event number should be 100');
    expect(repo.store.snapshots.length, equals(10), reason: 'Should have 2 snapshots');
  });

  test('Repository should delete snapshots automatically', () async {
    // Arrange
    final keep = 5;
    final repo = harness.get<FooRepository>();
    await repo.readyAsync();
    expect(repo.snapshot, isNull, reason: 'Should have NO snapshot');
    repo.store.snapshots.keep = keep;
    repo.store.snapshots.threshold = 10;

    // Act
    final uuid = Uuid().v4();
    final foo = repo.get(uuid);
    for (var i = 1; i <= 100; i++) {
      foo.patch({'property1': 'value$i'}, emits: FooUpdated);
      await repo.push(foo);
    }
    expect(foo.data, containsPair('property1', 'value100'));
    expect(repo.number.value, equals(100));

    // Assert
    expect(repo.snapshot, isNotNull, reason: 'Should have snapshot');
    expect(repo.snapshot.number.value, equals(100), reason: 'Event number should be 100');
    expect(repo.store.snapshots.length, equals(keep), reason: 'Should have 2 snapshots');
  });
}

Future _testShouldBuildFromLastSnapshot(EventSourceHarness harness) async {
  final repo = harness.get<FooRepository>();
  final stream = harness.server().getStream(repo.store.aggregate);
  await repo.readyAsync();
  expect(repo.snapshot, isNull, reason: 'Should have NO snapshot');
  final box = await Hive.openBox<StorageState>(repo.store.snapshots.filename);

  // Foo1
  final fuuid1 = Uuid().v4();
  final data1 = {
    'uuid': fuuid1,
    'parameter1': 'value1',
  };
  final event1 = Event(
    uuid: Uuid().v4(),
    data: {
      'patches': JsonPatch.diff({}, data1),
    },
    local: false,
    type: '$FooCreated',
    number: EventNumber(0),
    created: DateTime.now(),
  );
  stream.append(
    '${stream.instanceStream}-0',
    [TestStream.asSourceEvent<FooCreated>(fuuid1, {}, data1)],
  );

  // Foo2
  final fuuid2 = Uuid().v4();
  final data2 = {
    'uuid': fuuid2,
    'parameter2': 'value2',
  };
  final event2 = Event(
    uuid: Uuid().v4(),
    data: {
      'patches': JsonPatch.diff({}, data2),
    },
    local: false,
    type: '$FooCreated',
    number: EventNumber(0),
    created: DateTime.now(),
  );
  stream.append(
    '${stream.instanceStream}-1',
    [TestStream.asSourceEvent<FooCreated>(fuuid2, {}, data2)],
  );

  // Create snapshot
  final timestamp = DateTime.now();
  final suuid1 = Uuid().v4();
  final snapshot1 = SnapshotModel(
    uuid: suuid1,
    timestamp: timestamp,
    number: EventNumberModel.from(EventNumber.none),
  );
  await box.put(
    suuid1,
    StorageState(value: snapshot1),
  );
  final suuid2 = Uuid().v4();
  final snapshot2 = SnapshotModel(
    uuid: suuid2,
    timestamp: timestamp,
    number: EventNumberModel(value: 1),
    aggregates: LinkedHashMap.from({
      fuuid1: AggregateRootModel(
        uuid: fuuid1,
        createdBy: event1,
        changedBy: event1,
        data: data1,
        number: EventNumberModel.from(event1.number),
      ),
      fuuid2: AggregateRootModel(
        uuid: fuuid2,
        createdBy: event2,
        changedBy: event2,
        data: data2,
        number: EventNumberModel.from(event2.number),
      ),
    }),
  );
  await box.put(
    suuid2,
    StorageState(value: snapshot2),
  );
  await repo.store.snapshots.load();

  // Act
  final count = await repo.replay();

  // Assert
  expect(count, equals(0), reason: 'Should replay 0 events');
  expect(repo.snapshot, isNotNull, reason: 'Should have a snapshot');
  expect(repo.snapshot.uuid, equals(suuid2), reason: 'Should have snapshot $suuid2');
  expect(repo.number, repo.store.current(), reason: 'Should be equal');
  expect(repo.store.current(), equals(EventNumber(1)), reason: 'Should cumulate to (events.length - 1)');
  expect(event1.number, repo.store.current(uuid: fuuid1), reason: 'Should be equal');
  expect(event2.number, repo.store.current(uuid: fuuid2), reason: 'Should be equal');

  expect(repo.contains(fuuid1), isTrue, reason: 'Should contain aggregate root $fuuid1');
  final foo1 = repo.get(fuuid1);
  expect(foo1.number, equals(event1.number));
  expect(foo1.data, equals(data1));
  expect(repo.contains(fuuid2), isTrue, reason: 'Should contain aggregate root $fuuid2');
  final foo2 = repo.get(fuuid2);
  expect(foo2.number, equals(event2.number));
  expect(foo2.data, equals(data2));
}

Future<List<Event>> takeLocal(Stream<Event> stream, int count, {bool distinct = true}) {
  final seen = <Event>[];
  return stream
      .where((event) {
        final take = !distinct || !seen.contains(event);
        if (event.local) {
          seen.add(event);
        }
        return event.local && take;
      })
      .take(count)
      .toList();
}

Future<List<Event>> takeRemote(
  Stream<Event> stream,
  int count, {
  @required bool distinct,
}) {
  final seen = <Event>[];
  return stream
      .where((event) {
        final take = !distinct || !seen.contains(event);
        if (event.remote) {
          seen.add(event);
        }
        return event.remote && take;
      })
      .take(count)
      .toList();
}

Future<List<Event>> takeDistinct(
  Stream<Event> stream,
  int count,
) {
  final seen = <Event>[];
  final distinct = <Event>[];
  return stream
      .where((event) {
        final take = !seen.contains(event);
        seen.add(event);
        if (take) {
          distinct.add(event);
        }
        return take;
      })
      .take(count)
      .toList();
}

Future _assertCatchUp(FooRepository repo1, FooRepository repo2, FooRepository repo3, int count) async {
  // Act
  final uuid = Uuid().v4();
  final foo1 = repo1.get(uuid, data: {'property1': 'value1'});

  // Prepare join
  final group = StreamGroup<Event>();
  await group.add(repo2.store.asStream());
  await group.add(repo3.store.asStream());

  // Push to repo 1
  final events = await repo1.push(foo1);
  final domain1 = events.first;

  // Wait for repo 2 and 3 catching up
  await takeRemote(group.stream, 2, distinct: false);
  await group.close();

  // Get actual source events
  final source2 = repo2.store.events[uuid].last;
  final source3 = repo3.store.events[uuid].last;

  // Get actual aggregates
  final foo2 = repo2.get(uuid);
  final foo3 = repo3.get(uuid);

  // Get actual domain events
  final domain2 = repo2.toDomainEvent(source2);
  final domain3 = repo3.toDomainEvent(source3);

  // Assert catch-up event from repo1
  expect(repo2.count(), equals(count));
  expect(repo3.count(), equals(count));
  expect([source2], containsAll(events));
  expect([source3], containsAll(events));
  expect([domain2], containsAll(events));
  expect([domain3], containsAll(events));

  // Assert change and state information critical for automatic merge resolution
  expect(domain2.mapAt('changed'), equals(domain1.mapAt('changed')));
  expect(domain2.mapAt('previous'), equals(domain1.mapAt('previous')));
  expect(domain2.listAt('patches'), equals(domain1.listAt('patches')));
  expect(domain3.mapAt('changed'), equals(domain1.mapAt('changed')));
  expect(domain3.mapAt('previous'), equals(domain1.mapAt('previous')));
  expect(domain3.listAt('patches'), equals(domain1.listAt('patches')));

  final check = repo1.get(uuid);
  expect(identical(check, foo1), isTrue);

  // Assert even numbers
  expect(domain1.number.value, equals(0));
  expect(source2.number.value, equals(0));
  expect(source2.number.value, equals(0));
  expect(foo1.number.value, equals(0));
  expect(foo2.number.value, equals(0));
  expect(foo3.number.value, equals(0));
  expect(repo1.number.value, equals(count - 1));
  expect(repo2.number.value, equals(count - 1));
  expect(repo3.number.value, equals(count - 1));

  // Assert data
  expect(foo1.data, containsPair('property1', 'value1'));
  expect(foo2.data, containsPair('property1', 'value1'));
  expect(foo3.data, containsPair('property1', 'value1'));
}

Iterable<Event> _assertResultStrictOrder(List<Iterable<Event>> results) {
  final events = <Event>[];
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

Future<List<DomainEvent>> _createMultipleEvents(FooRepository repo, String uuid, int count) async {
  final operations = <DomainEvent>[];
  final foo = repo.get(uuid, data: {'index': 0});
  // Create
  final events = await repo.push(foo);
  operations.addAll(
    events.toList(),
  );
  // Patch
  for (var i = 1; i < count; i++) {
    final events = await repo.push(
      foo..patch({'index': i}, emits: FooUpdated),
    );
    operations.addAll(
      events.toList(),
    );
  }
  return operations;
}

Iterable<DomainEvent> _assertEventNumberStrictOrder(Repository repo, String uuid) {
  final events = repo.get(uuid).applied.toList();
  for (var i = 0; i < events.length; i++) {
    expect(
      events[i].number.value,
      equals(i),
      reason: 'Event number should be $i',
    );
  }
  return events;
}

void _assertUniqueEvents(Repository repo, Iterable<Event> events) {
  final actual = repo.store.events.values.fold(
    <String>[],
    (uuids, items) => uuids..addAll(items.map((e) => e.uuid)),
  );
  final expected = events.map((e) => e.uuid).toList();
  expect(expected, equals(actual));
  expect(repo.number.value, equals(events.length - 1));
}

List<Future<Iterable<DomainEvent>>> _createMultipleAggregates(FooRepository repo, int count, {String prefix}) {
  final operations = <Future<Iterable<DomainEvent>>>[];
  for (var i = 0; i < count; i++) {
    final uuid = '${prefix == null ? '' : '$prefix:'}foo:$i:${Uuid().v4()}';
    operations.add(repo.push(repo.get(uuid, data: {'index': i})));
  }
  return operations;
}
