import 'dart:async';
import 'dart:io';

import 'package:aqueduct/aqueduct.dart';
import 'package:event_source/event_source.dart';
import 'package:sarsys_app_server/sarsys_app_server.dart';
import 'package:uuid/uuid.dart';

class WebSocketController extends Controller {
  WebSocketController(this.channel);
  final MessageChannel channel;

  @override
  FutureOr<RequestOrResponse> handle(Request request) async {
    final socket = await WebSocketTransformer.upgrade(request.raw);
    final xAppId = request.raw.headers.value('x-app-id');
    final appId = xAppId ?? Uuid().v4();
    if (xAppId == null) {
      logger.info("Header 'x-app-id' not set, using $appId");
    }
    final heartbeat = request.raw.headers.value('x-with-heartbeat') ?? 'false';
    final data = await request.body.decode();
    final messages = data is Map<String, dynamic> && data['message'] is List<String>
        ? (data['message'] as List<String>).toSet()
        : const <String>{};
    channel.listen(
      "$appId",
      socket,
      messages: messages,
      withHeartbeat: heartbeat?.toLowerCase() == "true",
    );
    return null /* Required by Aqueduct, see https://aqueduct.io/docs/snippets/http/ */;
  }
}
