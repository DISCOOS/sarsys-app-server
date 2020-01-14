import 'package:sarsys_app_server/controllers/entity_controller.dart';
import 'package:sarsys_app_server/domain/operation/aggregate.dart' as sar;
import 'package:sarsys_app_server/domain/operation/commands.dart';
import 'package:sarsys_app_server/domain/operation/repository.dart';
import 'package:sarsys_app_server/sarsys_app_server.dart';
import 'package:sarsys_app_server/validation/validation.dart';

/// A ResourceController that handles
/// [/api/incidents/{uuid}/subjects](http://localhost/api/client.html#/TalkGroup) requests
class TalkGroupController extends EntityController<OperationCommand, sar.Operation> {
  TalkGroupController(OperationRepository repository, RequestValidator validator)
      : super(repository, "TalkGroup", "talkgroups", validator: validator);

  @override
  OperationCommand create(String uuid, String type, Map<String, dynamic> data) => AddTalkGroup(uuid, data);

  @override
  OperationCommand update(String uuid, String type, Map<String, dynamic> data) => UpdateTalkGroup(uuid, data);

  @override
  OperationCommand delete(String uuid, String type, Map<String, dynamic> data) => RemoveTalkGroup(uuid, data);

  //////////////////////////////////
  // Documentation
  //////////////////////////////////

  /// TalkGroup - Entity object
  @override
  APISchemaObject documentEntityObject(APIDocumentContext context) => APISchemaObject.object(
        {
          "id": APISchemaObject.integer()..description = "TalkGroup id (unique in Operation only)",
          "name": APISchemaObject.boolean()..description = "Talkgroup name",
          "type": APISchemaObject.string()
            ..description = "Talkgroup type"
            ..enumerated = [
              'tetra',
              'marine',
              'analog',
            ],
        },
      )
        ..description = "TalkGroup Schema (value object)"
        ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed
        ..required = [
          'id',
          'name',
          'type',
        ];
}