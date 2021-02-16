import 'dart:convert';

import 'package:event_source/event_source.dart';
import 'package:fixnum/fixnum.dart';
import 'generated/any.pb.dart';
import 'generated/aggregate.pb.dart';
import 'generated/event.pb.dart';
import 'generated/repository.pb.dart';
import 'generated/timestamp.pb.dart';

const _codec = Utf8Codec();

Any toAnyFromJson(
  dynamic json, {
  String scheme = 'org.discoos.es',
  String type,
}) =>
    Any()
      ..typeUrl = '$scheme/${type ?? (json is List ? 'json.list' : 'json.map')}'
      ..value = _codec.encode(jsonEncode(json));

dynamic toJsonFromAny<T>(Any json) {
  final type = json.typeUrl.split('/').last;
  switch (type) {
    case 'json.list':
      return List.from(
        jsonDecode(_codec.decode(json.value)),
      );
    case 'json.map':
    default:
      return Map.from(
        jsonDecode(_codec.decode(json.value)),
      );
  }
}

RepositoryMeta toRepoMeta(
  Map<String, dynamic> repo,
  EventStore store,
) {
  final type = repo.elementAt<String>('type');
  final lastEvent = store.isEmpty ? null : store.getEvent(store.eventMap.keys.last);
  return RepositoryMeta()
    ..type = repo.elementAt<String>('type')
    ..lastEvent = toEventMetaFromEvent(lastEvent, store)
    ..queue = toRepoQueueMeta(
      repo.mapAt<String, dynamic>('queue'),
    )
    ..metrics = toRepoMetricsMeta(
      type,
      repo.mapAt<String, dynamic>('metrics'),
    );
}

RepositoryQueueMeta toRepoQueueMeta(Map<String, dynamic> queue) {
  final meta = RepositoryQueueMeta();
  if (queue != null) {
    final status = queue.mapAt<String, dynamic>('status');
    if (status != null) {
      meta.status = (RepositoryQueueStatusMeta()
        ..idle = status.elementAt<bool>('idle')
        ..ready = status.elementAt<bool>('ready')
        ..disposed = status.elementAt<bool>('disposed'));
    }
    final pressure = queue.mapAt<String, dynamic>('pressure');
    if (pressure != null) {
      meta.pressure = (RepositoryQueuePressureMeta()
        ..total = pressure.elementAt<int>('total')
        ..maximum = pressure.elementAt<int>('maximum')
        ..commands = pressure.elementAt<int>('command')
        ..exceeded = pressure.elementAt<bool>('exceeded'));
    }
  }
  return meta;
}

RepositoryMetricsMeta toRepoMetricsMeta(
  String type,
  Map<String, dynamic> metrics,
) {
  final meta = RepositoryMetricsMeta();
  if (metrics != null) {
    meta.events = Int64(metrics.elementAt<int>('events'));
    final aggregates = metrics.mapAt<String, dynamic>('aggregates');
    if (aggregates != null) {
      meta.aggregates = (RepositoryMetricsAggregateMeta()
        ..count = aggregates.elementAt<int>('count')
        ..changed = aggregates.elementAt<int>('changed')
        ..tainted = toAggregateMetaList(
          type,
          metrics.elementAt<int>('tainted/count', defaultValue: 0),
          metrics.listAt('tainted/items', defaultList: []),
          (item) => AggregateMeta()
            ..uuid = item['uuid']
            ..tainted = toAnyFromJson(item['value']),
        )
        ..cordoned = toAggregateMetaList(
          type,
          metrics.elementAt<int>('cordoned/count', defaultValue: 0),
          metrics.listAt('cordoned/items', defaultList: []),
          (item) => AggregateMeta()
            ..uuid = item['uuid']
            ..cordoned = toAnyFromJson(item['value']),
        ));
    }
  }
  return meta;
}

AggregateMetaList toAggregateMetaList(
  String type,
  int count,
  List items,
  AggregateMeta Function(dynamic) map,
) {
  final list = AggregateMetaList()
    ..count = count
    ..items.addAll([
      if (items.isNotEmpty) ...items.map(map),
    ]);

  return list;
}

EventMeta toEventMetaFromEvent(Event event, EventStore store) {
  final meta = EventMeta()
    ..number = Int64(EventNumber.none.value)
    ..position = Int64(EventNumber.none.value);
  if (event != null) {
    meta
      ..uuid = event.uuid
      ..type = event.type
      ..remote = event.remote
      ..number = Int64(event.number.value)
      ..position = Int64(store.toPosition(event))
      ..timestamp = Timestamp.fromDateTime(event.created);
  }
  return meta;
}

//
// EventMeta toEventMetaFromMap(Map<String, dynamic> event) {
//   final meta = EventMeta()
//     ..number = Int64(EventNumber.none.value)
//     ..position = Int64(EventNumber.none.value);
//   if (event != null) {
//     meta
//       ..uuid = event.uuid
//       ..type = event.type
//       ..remote = event.remote
//       ..number = Int64(event.number.value)
//       ..position = Int64(store.toPosition(event))
//       ..timestamp = toTimestamp(event.created);
//   }
//   return meta;
// }