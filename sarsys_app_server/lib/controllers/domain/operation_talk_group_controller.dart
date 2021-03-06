import 'package:sarsys_domain/sarsys_domain.dart' as sar;
import 'package:sarsys_core/sarsys_core.dart';

/// A ResourceController that handles
/// [/api/incidents/{uuid}/subjects](http://localhost/api/client.html#/TalkGroup) requests
class TalkGroupController extends EntityController<sar.OperationCommand, sar.Operation> {
  TalkGroupController(sar.OperationRepository repository, JsonValidation validation)
      : super(repository, "TalkGroup", "talkgroups", validation: validation, tag: 'Operations > Talkgroups');

  @override
  @Operation.get('uuid')
  Future<Response> getAll(@Bind.path('uuid') String uuid) {
    return super.getAll(uuid);
  }

  @override
  @Operation.get('uuid', 'id')
  Future<Response> getById(
    @Bind.path('uuid') String uuid,
    @Bind.path('id') String id,
  ) {
    return super.getById(uuid, id);
  }

  @override
  @Operation.post('uuid')
  Future<Response> create(
    @Bind.path('uuid') String uuid,
    @Bind.body() Map<String, dynamic> data,
  ) {
    return super.create(uuid, data);
  }

  @override
  @Operation('PATCH', 'uuid', 'id')
  Future<Response> update(
    @Bind.path('uuid') String uuid,
    @Bind.path('id') String id,
    @Bind.body() Map<String, dynamic> data,
  ) {
    return super.update(uuid, id, data);
  }

  @override
  @Operation('DELETE', 'uuid', 'id')
  Future<Response> delete(
    @Bind.path('uuid') String uuid,
    @Bind.path('id') String id, {
    @Bind.body() Map<String, dynamic> data,
  }) {
    return super.delete(uuid, id, data: data);
  }

  @override
  sar.OperationCommand onCreate(String uuid, String type, Map<String, dynamic> data) =>
      sar.AddTalkGroupToOperation(uuid, data);

  @override
  sar.OperationCommand onUpdate(String uuid, String type, Map<String, dynamic> data) =>
      sar.UpdateOperationTalkGroup(uuid, data);

  @override
  sar.OperationCommand onDelete(String uuid, String type, Map<String, dynamic> data) =>
      sar.RemoveTalkGroupFromOperation(uuid, data);

  //////////////////////////////////
  // Documentation
  //////////////////////////////////

  /// TalkGroup - Entity object
  @override
  APISchemaObject documentEntityObject(APIDocumentContext context) => APISchemaObject.object(
        {
          "id": context.schema['ID']..description = "TalkGroup id (unique in Operation only)",
          "name": APISchemaObject.string()..description = "Talkgroup name",
          "type": documentType(),
        },
      )
        ..description = "TalkGroup Schema (value object)"
        ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed
        ..required = [
          'id',
          'name',
          'type',
        ];

  APISchemaObject documentType() => APISchemaObject.string()
    ..description = "Talkgroup type"
    ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed
    ..enumerated = [
      'tetra',
      'marine',
      'analog',
    ];
}
