import 'package:event_source/event_source.dart';
import 'package:sarsys_app_server/sarsys_app_server.dart';

class HealthController extends ResourceController {
  HealthController(this.manager);
  final RepositoryManager manager;

  @Operation.get()
  Future<Response> check() async {
    return manager.isReady ? Response.ok("Status OK") : serviceUnavailable(body: "Status Not ready");
  }

  @override
  List<String> documentOperationTags(APIDocumentContext context, Operation operation) {
    return ['System'];
  }
}
