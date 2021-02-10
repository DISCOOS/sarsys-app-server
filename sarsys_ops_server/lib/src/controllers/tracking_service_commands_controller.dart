import 'package:grpc/grpc.dart' hide Response;
import 'package:grpc/grpc_connection_interface.dart';
import 'package:sarsys_ops_server/sarsys_ops_server.dart';
import 'package:sarsys_ops_server/src/config.dart';
import 'package:sarsys_tracking_server/sarsys_tracking_server.dart';

import 'operations_base_controller.dart';

class TrackingServiceCommandsController extends OperationsBaseController {
  TrackingServiceCommandsController(
    this.k8s,
    this.channels,
    SarSysOpsConfig config,
    Map<String, dynamic> context,
  ) : super(
          'TrackingService',
          config,
          options: [
            'repo',
          ],
          actions: [
            'stop_all',
            'start_all',
          ],
          instanceOptions: [
            'repo',
          ],
          instanceActions: [
            'stop',
            'start',
            'add_trackings',
            'remove_trackings',
          ],
          tag: 'Tracking',
          context: context,
        );

  static const String module = 'sarsys-tracking-server';

  final K8sApi k8s;
  final Map<String, ClientChannel> channels;
  final Map<String, SarSysTrackingServiceClient> _clients = {};

  @override
  @Operation.get()
  Future<Response> getMeta({
    @Bind.query('expand') String expand,
  }) {
    return super.getMeta(expand: expand);
  }

  @override
  Future<Response> doGetMeta(String expand) async {
    final pods = await k8s.getPodsFromNs(
      k8s.namespace,
      labels: [
        'module=$module',
      ],
    );
    final metas = <Map<String, dynamic>>[];
    for (var pod in pods) {
      final meta = await _doGetMetaByName(pod, expand);
      metas.add(meta);
    }
    return _toResponse(
      name: 'name',
      body: metas,
      method: 'doGetMeta',
      args: {'expand': expand},
      statusCode: toStatusCode(
        metas,
      ),
    );
  }

  @override
  @Operation.get('name')
  Future<Response> getMetaByName(
    @Bind.path('name') String name, {
    @Bind.query('expand') String expand,
  }) {
    return super.getMetaByName(name, expand: expand);
  }

  @override
  Future<Response> doGetMetaByName(String name, String expand) async {
    final pod = await _getPod(
      name,
    );
    if (pod == null) {
      return _toResponse(
        name: name,
        args: {'expand': expand},
        method: 'doGetMetaByName',
        statusCode: HttpStatus.notFound,
        body: "$type instance '$name' not found",
      );
    }
    final meta = await _doGetMetaByName(
      pod,
      expand,
    );
    return _toResponse(
      name: name,
      body: meta,
      args: {'expand': expand},
      method: 'doGetMetaByName',
      statusCode: meta.elementAt<int>(
        'error/statusCode',
        defaultValue: HttpStatus.ok,
      ),
    );
  }

  Future<Map<String, dynamic>> _doGetMetaByName(
    Map<String, dynamic> pod,
    String expand,
  ) async {
    final meta = await toClient(pod).getMeta(GetMetaRequest()
      ..expand.addAll([
        if (shouldExpand(expand, 'repo')) ExpandFields.EXPAND_FIELDS_REPO,
      ]));
    return _toJsonMeta(
      k8s.toPodName(pod),
      meta,
      expand,
    );
  }

  @override
  @Operation.post()
  Future<Response> execute(
    @Bind.body() Map<String, dynamic> body, {
    @Bind.query('expand') String expand,
  }) =>
      super.execute(body, expand: expand);

  @override
  Future<Response> doExecute(
    String command,
    Map<String, dynamic> body,
    String expand,
  ) async {
    final pods = await k8s.getPodsFromNs(
      k8s.namespace,
      labels: [
        'module=$module',
      ],
    );
    switch (command) {
      case 'start_all':
        return doStartAll(pods, expand);
      case 'stop_all':
        return doStopAll(pods, expand);
    }
    return _toResponse(
      name: 'all',
      method: 'execute',
      statusCode: HttpStatus.notFound,
      body: "$type command '$command' not found",
      args: {'command': command, 'expand': expand},
    );
  }

  @override
  @Operation.post('name')
  Future<Response> executeByName(
    @Bind.path('name') String name,
    @Bind.body() Map<String, dynamic> body, {
    @Bind.query('expand') String expand,
  }) {
    return super.executeByName(name, body, expand: expand);
  }

  @override
  Future<Response> doExecuteByName(
    String name,
    String command,
    Map<String, dynamic> body,
    String expand,
  ) async {
    final pod = await _getPod(name);
    if (pod == null) {
      return _toResponse(
        name: name,
        method: 'doExecuteByName',
        statusCode: HttpStatus.notFound,
        body: "$type instance '$name' not found",
        args: {'command': command, 'expand': expand},
      );
    }
    switch (command) {
      case 'start':
        return doStart(pod, expand);
      case 'stop':
        return doStop(pod, expand);
      case 'add_trackings':
        return doAddTrackings(
          pod,
          body.listAt<String>(
            'uuids',
            defaultList: [],
          ),
          expand,
        );
      case 'remove_trackings':
        return doRemoveTrackings(
          pod,
          body.listAt<String>(
            'uuids',
            defaultList: [],
          ),
          expand,
        );
    }
    return _toResponse(
      name: name,
      method: 'doExecuteByName',
      statusCode: HttpStatus.notFound,
      args: {'command': command, 'expand': expand},
      body: "$type command instance '$command' not found",
    );
  }

  Future<Response> doStartAll(
    List<Map<String, dynamic>> pods,
    String expand,
  ) async {
    final metas = <Map<String, dynamic>>[];
    for (var pod in pods) {
      final meta = await _doStart(pod, expand);
      metas.add(meta);
    }
    return _toResponse(
      name: 'all',
      body: metas,
      method: 'doStartAll',
      args: {'expand': expand},
      statusCode: toStatusCode(metas),
    );
  }

  Future<Response> doStopAll(
    List<Map<String, dynamic>> pods,
    String expand,
  ) async {
    final metas = <Map<String, dynamic>>[];
    for (var pod in pods) {
      final meta = await _doStop(pod, expand);
      metas.add(meta);
    }
    return _toResponse(
      name: 'all',
      body: metas,
      method: 'doStopAll',
      args: {'expand': expand},
      statusCode: toStatusCode(metas),
    );
  }

  int toStatusCode(List<Map<String, dynamic>> metas) {
    final errors = metas
        .where((meta) => meta.hasPath('error'))
        .map(
          (meta) => meta.elementAt<int>('error/statusCode'),
        )
        .toList();
    return errors.isEmpty ? HttpStatus.ok : (errors.length == 1 ? errors.first : HttpStatus.partialContent);
  }

  Future<Response> doStart(
    Map<String, dynamic> pod,
    String expand,
  ) async {
    final meta = await _doStart(pod, expand);
    return _toResponse(
      body: meta,
      method: 'doStart',
      name: k8s.toPodName(pod),
      args: {'expand': expand},
      statusCode: toStatusCode([meta]),
    );
  }

  Future<Map<String, dynamic>> _doStart(
    Map<String, dynamic> pod,
    String expand,
  ) async {
    final response = await toClient(pod).start(
      StartTrackingRequest()
        ..expand.addAll([
          if (shouldExpand(expand, 'repo')) ExpandFields.EXPAND_FIELDS_REPO,
        ]),
    );
    return {
      'meta': _toJsonMeta(
        k8s.toPodName(pod),
        response.meta,
        expand,
      ),
      if (response.statusCode != HttpStatus.ok)
        'error': {
          'statusCode': response.statusCode,
          'reasonPhrase': response.reasonPhrase,
        }
    };
  }

  Future<Response> doStop(
    Map<String, dynamic> pod,
    String expand,
  ) async {
    final meta = await _doStop(pod, expand);
    return _toResponse(
      body: meta,
      method: 'doStop',
      name: k8s.toPodName(pod),
      args: {'expand': expand},
      statusCode: toStatusCode([meta]),
    );
  }

  Future<Map<String, dynamic>> _doStop(
    Map<String, dynamic> pod,
    String expand,
  ) async {
    final response = await toClient(pod).stop(
      StopTrackingRequest()
        ..expand.addAll([
          if (shouldExpand(expand, 'repo')) ExpandFields.EXPAND_FIELDS_REPO,
        ]),
    );
    return {
      'meta': _toJsonMeta(
        k8s.toPodName(pod),
        response.meta,
        expand,
      ),
      if (response.statusCode != HttpStatus.ok)
        'error': {
          'statusCode': response.statusCode,
          'reasonPhrase': response.reasonPhrase,
        }
    };
  }

  Future<Response> doAddTrackings(
    Map<String, dynamic> pod,
    List<String> uuids,
    String expand,
  ) async {
    final name = k8s.toPodName(pod);
    final args = {'command': 'add_trackings', 'expand': expand};
    if (uuids.isEmpty) {
      return _toResponse(
        name: name,
        args: args,
        method: 'doExecuteByName',
        statusCode: HttpStatus.badRequest,
        body: "One ore more tracing uuids are required ('uuids' was empty)",
      );
    }
    final response = await toClient(pod).addTrackings(
      AddTrackingsRequest()
        ..uuids.addAll(uuids)
        ..expand.addAll([
          if (shouldExpand(expand, 'repo')) ExpandFields.EXPAND_FIELDS_REPO,
        ]),
    );
    return _toResponse(
      name: name,
      args: args,
      method: 'doAddTrackings',
      body: {
        'meta': _toJsonMeta(
          k8s.toPodName(pod),
          response.meta,
          expand,
        ),
        if (response.failed.isNotEmpty)
          'error': {
            'failed': response.failed,
            'statusCode': response.statusCode,
            'reasonPhrase': response.reasonPhrase,
          }
      },
      statusCode: response.statusCode,
    );
  }

  Future<Response> doRemoveTrackings(
    Map<String, dynamic> pod,
    List<String> uuids,
    String expand,
  ) async {
    final name = k8s.toPodName(pod);
    final args = {'command': 'remove_trackings', 'expand': expand};
    if (uuids.isEmpty) {
      return _toResponse(
        name: name,
        args: args,
        method: 'doExecuteByName',
        statusCode: HttpStatus.badRequest,
        body: "One ore more tracing uuids are required ('uuids' was empty)",
      );
    }
    final response = await toClient(pod).removeTrackings(
      RemoveTrackingsRequest()
        ..uuids.addAll(uuids)
        ..expand.addAll([
          if (shouldExpand(expand, 'repo')) ExpandFields.EXPAND_FIELDS_REPO,
        ]),
    );
    return _toResponse(
      name: name,
      args: args,
      method: 'doRemoveTrackings',
      body: {
        'meta': _toJsonMeta(
          k8s.toPodName(pod),
          response.meta,
          expand,
        ),
        if (response.failed.isNotEmpty)
          'error': {
            'failed': response.failed,
            'statusCode': response.statusCode,
            'reasonPhrase': response.reasonPhrase,
          }
      },
      statusCode: response.statusCode,
    );
  }

  SarSysTrackingServiceClient toClient(Map<String, dynamic> pod) {
    final uri = k8s.toPodUri(
      pod,
      deployment: module,
      port: config.tracking.grpcPort,
    );
    final channel = channels.putIfAbsent(
      uri.authority,
      () => ClientChannel(
        uri.host,
        port: uri.port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      ),
    );
    final client = _clients.putIfAbsent(
      uri.authority,
      () => SarSysTrackingServiceClient(
        channel,
        options: CallOptions(
          timeout: const Duration(
            seconds: 30,
          ),
        ),
      ),
    );
    logger.fine(
      Context.toMethod('toClient', [
        'host: ${channel.host}',
        'port: ${channel.port}',
      ]),
    );
    return client;
  }

  Future<Map<String, dynamic>> _getPod(String name) async {
    final pods = await k8s.getPodsFromNs(
      k8s.namespace,
      labels: [
        'module=$module',
      ],
    );
    final Map<String, dynamic> pod = pods.firstWhere(
      (pod) => name == k8s.toPodName(pod),
      orElse: () => null,
    );
    return pod;
  }

  Map<String, Object> _toJsonMeta(String name, GetMetaResponse meta, String expand) {
    return {
      'name': name,
      'status': _toStatus(meta),
      'managerOf': _toJsonManagerOf(meta),
      'metrics': {
        'trackings': _toJsonTrackingsMeta(meta.trackings),
        'positions': _toJsonPositionsMeta(meta.positions),
      },
      if (shouldExpand(expand, 'repo')) 'repo': _toJsonRepoMeta(meta.repo),
    };
  }

  String _toStatus(GetMetaResponse meta) {
    return capitalize(
      enumName(meta.status).split('_').last,
    );
  }

  List<Map<String, dynamic>> _toJsonManagerOf(GetMetaResponse meta) => meta.managerOf
      .map((meta) => <String, dynamic>{
            'uuid': meta.uuid,
            'trackCount': meta.trackCount,
            'positionCount': meta.positionCount,
            if (meta.lastEvent.uuid.isNotEmpty) 'lastEvent': _toJsonEventMeta(meta.lastEvent),
          })
      .toList();

  Map<String, dynamic> _toJsonRepoMeta(RepositoryMeta meta) => {
        'type': meta.type,
      };

  Map<String, dynamic> _toJsonEventMeta(EventMeta meta) => {
        'type': meta.type,
        'uuid': meta.uuid,
        'remote': meta.remote,
        'number': meta.number,
        'position': meta.position,
      };

  Map<String, dynamic> _toJsonTrackingsMeta(TrackingsMeta meta) => {
        'total': meta.total,
        'fractionManaged': meta.fractionManaged,
        'eventsPerMinute': meta.eventsPerMinute,
        'lastEvent': _toJsonEventMeta(meta.lastEvent),
        'averageProcessingTimeMillis': meta.averageProcessingTimeMillis,
      };

  Map<String, dynamic> _toJsonPositionsMeta(PositionsMeta meta) => {
        'total': meta.total,
        'eventsPerMinute': meta.eventsPerMinute,
        'lastEvent': _toJsonEventMeta(meta.lastEvent),
        'averageProcessingTimeMillis': meta.averageProcessingTimeMillis,
      };

  Response _toResponse({
    @required String name,
    @required String method,
    @required int statusCode,
    @required Map<String, dynamic> args,
    dynamic body,
  }) {
    logger.fine(
      Context.toMethod('method', [
        'name: $name',
        ...args.entries.map((entry) => '${entry.key}: ${entry.value}'),
        'response: $body',
      ]),
    );
    return Response(
      statusCode,
      {},
      body,
    );
  }

  //////////////////////////////////
  // Documentation
  //////////////////////////////////

  @override
  Map<String, APISchemaObject> documentCommandParams(APIDocumentContext context) => {};

  @override
  Map<String, APISchemaObject> documentInstanceCommandParams(APIDocumentContext context) => {
        'uuids': APISchemaObject.array(ofType: APIType.string)
          ..description = 'List of aggregate uuids which command applies to',
      };

  @override
  APISchemaObject documentMeta(APIDocumentContext context) {
    return APISchemaObject.object({
      'name': APISchemaObject.string()
        ..description = 'Tracking service instance name'
        ..isReadOnly = true,
      'status': APISchemaObject.string()
        ..description = 'Tracking service status'
        ..enumerated = [
          'none',
          'ready',
          'competing',
          'paused',
          'disposed',
        ]
        ..isReadOnly = true,
      'trackings': documentTrackingsMeta(context),
      'positions': documentPositionsMeta(context),
      'managerOf': APISchemaObject.array(
        ofSchema: documentTrackingMeta(context),
      )
        ..description = 'List of metadata for managed tracking objects'
        ..isReadOnly = true,
      'repository': documentRepositoryMeta(context)
    });
  }

  APISchemaObject documentTrackingsMeta(APIDocumentContext context) => APISchemaObject.object({
        'total': APISchemaObject.integer()
          ..description = 'Total number of trackings heard'
          ..isReadOnly = true,
        'fractionManaged': APISchemaObject.integer()
          ..description = 'Number of managed tracking object to total number of tracking objects'
          ..isReadOnly = true,
        'eventsPerMinute': APISchemaObject.integer()
          ..description = 'Number of tracking events processed per minute'
          ..isReadOnly = true,
        'averageProcessingTimeMillis': APISchemaObject.number()
          ..description = 'average processing time in milliseconds'
          ..isReadOnly = true,
        'lastEvent': documentEvent(context)
          ..description = 'Last event applied to tracking object'
          ..isReadOnly = true,
      })
        ..description = 'Tracking processing metadata'
        ..isReadOnly = true;

  APISchemaObject documentPositionsMeta(APIDocumentContext context) => APISchemaObject.object({
        'total': APISchemaObject.integer()
          ..description = 'Total number of positions heard'
          ..isReadOnly = true,
        'eventsPerMinute': APISchemaObject.integer()
          ..description = 'Number of positions processed per minute'
          ..isReadOnly = true,
        'averageProcessingTimeMillis': APISchemaObject.number()
          ..description = 'verage processing time in milliseconds'
          ..isReadOnly = true,
        'lastEvent': documentEvent(context)
          ..description = 'Last event applied to track in tracking object'
          ..isReadOnly = true,
      })
        ..description = 'Position processing metadata'
        ..isReadOnly = true;

  APISchemaObject documentTrackingMeta(APIDocumentContext context) => APISchemaObject.object({
        'uuid': documentUUID()
          ..description = 'Tracking uuid'
          ..isReadOnly = true,
        'trackCount': APISchemaObject.integer()
          ..description = 'Number of tracks in tracking object'
          ..isReadOnly = true,
        'positionCount': APISchemaObject.integer()
          ..description = 'Total number of positions in tracking object'
          ..isReadOnly = true,
        'lastEvent': documentEvent(context)
          ..description = 'Last event applied to tracking object'
          ..isReadOnly = true,
      })
        ..description = 'Tracking object metadata'
        ..isReadOnly = true;

  APISchemaObject documentRepositoryMeta(APIDocumentContext context) => APISchemaObject.object({
        'type': APISchemaObject.string()
          ..description = 'Repository type'
          ..isReadOnly = true,
        'lastEvent': documentEvent(context)
          ..description = 'Last event applied to repository'
          ..isReadOnly = true,
        'queue': documentRepositoryQueueMeta(context),
      })
        ..description = 'List of metadata for managed tracking objects'
        ..isReadOnly = true;

  APISchemaObject documentRepositoryQueueMeta(APIDocumentContext context) => APISchemaObject.object({
        'pressure': documentRepositoryQueuePressureMeta(context),
        'status': documentRepositoryQueueStatusMeta(context),
      })
        ..description = 'Repository queue metadata'
        ..isReadOnly = true;

  APISchemaObject documentRepositoryQueuePressureMeta(APIDocumentContext context) => APISchemaObject.object({
        'push': APISchemaObject.integer()
          ..description = 'Number of pending pushes'
          ..isReadOnly = true,
        'commands': APISchemaObject.integer()
          ..description = 'Number of pending commands'
          ..isReadOnly = true,
        'total': APISchemaObject.integer()
          ..description = 'Total number of pending pushes and commands'
          ..isReadOnly = true,
        'maximum': APISchemaObject.integer()
          ..description = 'Maximum allowed queue pressure'
          ..isReadOnly = true,
        'exceeded': APISchemaObject.boolean()
          ..description = 'True if maximum queue pressure is exceeded'
          ..isReadOnly = true,
      })
        ..description = 'Repository queue pressure metadata'
        ..isReadOnly = true;

  APISchemaObject documentRepositoryQueueStatusMeta(APIDocumentContext context) => APISchemaObject.object({
        'idle': APISchemaObject.boolean()
          ..description = 'True if queue is idle'
          ..isReadOnly = true,
        'ready': APISchemaObject.boolean()
          ..description = 'True if queue is ready to process requests'
          ..isReadOnly = true,
        'disposed': APISchemaObject.boolean()
          ..description = 'True if queue is disposed'
          ..isReadOnly = true,
      })
        ..description = 'Repository queue status metadata'
        ..isReadOnly = true;
}
