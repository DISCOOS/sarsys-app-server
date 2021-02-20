import 'dart:async';
import 'dart:io';

import 'package:event_source/event_source.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc/src/server/call.dart';
import 'package:logging/logging.dart';

import 'generated/aggregate.pbgrpc.dart';
import 'utils.dart';

class AggregateGrpcService extends AggregateGrpcServiceBase {
  AggregateGrpcService(this.manager);
  final RepositoryManager manager;
  final logger = Logger('$AggregateGrpcService');

  @override
  Future<GetAggregateMetaResponse> getMeta(ServiceCall call, GetAggregateMetaRequest request) async {
    final response = GetAggregateMetaResponse()
      ..type = request.type
      ..uuid = request.uuid
      ..statusCode = HttpStatus.ok
      ..reasonPhrase = 'OK';
    if (call.isTimedOut) {
      final reason = _timeout('getMeta');
      response
        ..reasonPhrase = reason
        ..statusCode = StatusCode.deadlineExceeded;
      call.sendTrailers(
        message: reason,
        status: StatusCode.deadlineExceeded,
      );
      return response;
    }
    final type = request.type;
    final uuid = request.uuid;
    final repo = manager.getFromTypeName(type);
    if (repo == null) {
      _notFound(
        'getMeta',
        'Repository for aggregate $type not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Repository for aggregate $type not found';
    }
    final aggregate = await _tryGet(type, uuid);
    if (aggregate == null) {
      _notFound(
        'getMeta',
        'Aggregate $type $uuid not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Aggregate $type $uuid not found';
    }
    response.meta = toAggregateMetaFromRoot(
      aggregate,
      repo.store,
      expand: request.expand,
    );
    _log(
      'getMeta',
      response.statusCode,
      response.reasonPhrase,
    );
    return response;
  }

  @override
  Future<ReplaceAggregateDataResponse> replaceData(
    ServiceCall call,
    ReplaceAggregateDataRequest request,
  ) async {
    final response = ReplaceAggregateDataResponse()
      ..type = request.type
      ..uuid = request.uuid
      ..statusCode = HttpStatus.ok
      ..reasonPhrase = 'OK';
    if (call.isTimedOut) {
      final reason = _timeout('replaceData');
      response
        ..reasonPhrase = reason
        ..statusCode = StatusCode.deadlineExceeded;
      call.sendTrailers(
        message: reason,
        status: StatusCode.deadlineExceeded,
      );
      return response;
    }
    final type = request.type;
    final uuid = request.uuid;
    final repo = manager.getFromTypeName(type);
    if (repo == null) {
      _notFound(
        'replaceData',
        'Repository for aggregate $type not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Repository for aggregate $type not found';
    }
    var aggregate = await _tryGet(type, uuid);
    if (aggregate == null) {
      _notFound(
        'replaceData',
        'Aggregate $type $uuid not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Aggregate $type $uuid not found';
    }

    // Reset error states
    repo.store.untaint(uuid);
    repo.store.uncordon(uuid);

    // Replace with data or patches
    final data = request.hasField(4) ? request.data.toProto3Json() : null;
    final patches = request.hasField(5) ? request.patches.map((v) => v.toProto3Json()) : null;
    aggregate = repo.replace(
      uuid,
      strict: false,
      patches: patches,
      data: Map<String, dynamic>.from(data),
    );
    response.meta = toAggregateMetaFromRoot(
      aggregate,
      repo.store,
      expand: request.expand,
    );
    _log(
      'replaceData',
      response.statusCode,
      response.reasonPhrase,
    );
    return response;
  }

  @override
  Future<CatchupAggregateEventsResponse> catchupEvents(
    ServiceCall call,
    CatchupAggregateEventsRequest request,
  ) async {
    final type = request.type;
    final uuid = request.uuid;
    final response = CatchupAggregateEventsResponse()
      ..type = type
      ..uuid = uuid
      ..statusCode = HttpStatus.ok
      ..reasonPhrase = 'OK';
    if (call.isTimedOut) {
      final reason = _timeout('catchupEvents');
      response
        ..reasonPhrase = reason
        ..statusCode = StatusCode.deadlineExceeded;
      call.sendTrailers(
        message: reason,
        status: StatusCode.deadlineExceeded,
      );
      return response;
    }

    final repo = manager.getFromTypeName(type);
    if (repo == null) {
      _notFound(
        'catchupEvents',
        'Repository for aggregate $type not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Repository for aggregate $type not found';
    }
    final aggregate = await _tryGet(type, uuid);
    if (aggregate == null) {
      _notFound(
        'catchupEvents',
        'Aggregate $type $uuid not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Aggregate $type $uuid not found';
    }

    // Execute
    await repo.catchup(
      uuids: [uuid],
      strict: false,
    );

    // Return result
    response.meta = toAggregateMetaFromRoot(
      aggregate,
      repo.store,
      expand: request.expand,
    );
    _log(
      'catchupEvents',
      response.statusCode,
      response.reasonPhrase,
    );
    return response;
  }

  @override
  Future<ReplayAggregateEventsResponse> replayEvents(
    ServiceCall call,
    ReplayAggregateEventsRequest request,
  ) async {
    final type = request.type;
    final uuid = request.uuid;
    final response = ReplayAggregateEventsResponse()
      ..type = type
      ..uuid = uuid
      ..statusCode = HttpStatus.ok
      ..reasonPhrase = 'OK';
    if (call.isTimedOut) {
      final reason = _timeout('replayEvents');
      response
        ..reasonPhrase = reason
        ..statusCode = StatusCode.deadlineExceeded;
      call.sendTrailers(
        message: reason,
        status: StatusCode.deadlineExceeded,
      );
      return response;
    }

    final repo = manager.getFromTypeName(type);
    if (repo == null) {
      _notFound(
        'replayEvents',
        'Repository for aggregate $type not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Repository for aggregate $type not found';
    }
    final aggregate = await _tryGet(type, uuid);
    if (aggregate == null) {
      _notFound(
        'replayEvents',
        'Aggregate $type $uuid not found',
      );
      return response
        ..statusCode = HttpStatus.notFound
        ..reasonPhrase = 'Aggregate $type $uuid not found';
    }

    // Execute
    await repo.replay(
      uuids: [uuid],
      strict: false,
    );

    // Return result
    response.meta = toAggregateMetaFromRoot(
      aggregate,
      repo.store,
      expand: request.expand,
    );
    _log(
      'replayEvents',
      response.statusCode,
      response.reasonPhrase,
    );
    return response;
  }

  FutureOr<AggregateRoot> _tryGet(String type, String uuid) async {
    final repo = manager.getFromTypeName(type);
    if (!repo.exists(uuid)) {
      await repo.catchup(
        master: true,
        uuids: [uuid],
      );
    }
    // Only get aggregate if is exists in storage!
    return repo.store.contains(uuid) ? repo.get(uuid) : null;
  }

  String _timeout(String method) {
    return _log(
      method,
      HttpStatus.gatewayTimeout,
      'Gateway Timeout Error',
    );
  }

  String _notFound(String method, String message) {
    return _log(
      method,
      HttpStatus.notFound,
      message,
    );
  }

  String _log(String method, int statusCode, String reasonPhrase, [Object error, StackTrace stackTrace]) {
    final message = '$method $statusCode $reasonPhrase';
    if (statusCode > 500) {
      logger.severe(
        message,
        error,
        stackTrace,
      );
    } else {
      logger.info(
        '$method $statusCode $reasonPhrase',
        error,
        stackTrace,
      );
    }
    return message;
  }
}
