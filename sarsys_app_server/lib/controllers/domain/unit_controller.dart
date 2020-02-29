import 'package:sarsys_app_server/controllers/eventsource/aggregate_controller.dart';
import 'package:sarsys_domain/sarsys_domain.dart';
import 'package:sarsys_app_server/sarsys_app_server.dart';
import 'package:sarsys_app_server/validation/validation.dart';

/// A ResourceController that handles
/// [/api/incidents/{uuid}/units](http://localhost/api/client.html#/Unit) requests
class UnitController extends AggregateController<UnitCommand, Unit> {
  UnitController(UnitRepository repository, JsonValidation validation)
      : super(repository,
            validation: validation,
            readOnly: const [
              'operation',
              'messages',
              'tracking',
              'transitions',
            ],
            tag: 'Units');

  @override
  UnitCommand onCreate(Map<String, dynamic> data) => CreateUnit(data);

  @override
  UnitCommand onUpdate(Map<String, dynamic> data) => UpdateUnitInformation(data);

  @override
  UnitCommand onDelete(Map<String, dynamic> data) => DeleteUnit(data);

  //////////////////////////////////
  // Documentation
  //////////////////////////////////

  @override
  APISchemaObject documentAggregateRoot(APIDocumentContext context) => APISchemaObject.object(
        {
          "uuid": context.schema['UUID']..description = "Unique unit id",
          "operation": APISchemaObject.object({
            "uuid": context.schema['UUID'],
          })
            ..isReadOnly = true
            ..description = "Operation which this unit belongs to"
            ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed,
          "type": documentType(),
          "number": APISchemaObject.integer()..description = "Unit number",
          "affiliation": context.schema["Affiliation"],
          "phone": APISchemaObject.string()..description = "Unit phone number",
          "callsign": APISchemaObject.string()..description = "Unit callsign",
          "status": documentStatus(),
          "tracking": APISchemaObject.object({
            "uuid": context.schema['UUID'],
          })
            ..description = "Tracking object for this unit"
            ..isReadOnly = true,
          "transitions": APISchemaObject.array(ofSchema: documentTransition())
            ..isReadOnly = true
            ..description = "State transitions (read only)",
          "personnels": APISchemaObject.array(ofSchema: context.schema['UUID'])
            ..description = "List of uuid of Personnels assigned to this unit",
          "messages": APISchemaObject.array(ofSchema: context.schema['Message'])
            ..isReadOnly = true
            ..description = "List of messages added to Incident",
        },
      )
        ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed
        ..required = [
          'uuid',
          'type',
          'status',
          'number',
          'callsign',
        ];

  APISchemaObject documentTransition() => APISchemaObject.object({
        "status": documentStatus(),
        "timestamp": APISchemaObject.string()
          ..description = "When transition occured"
          ..format = 'date-time',
      })
        ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed;

  /// Unit type - Value Object
  APISchemaObject documentType() => APISchemaObject.string()
    ..description = "Unit type"
    ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed
    ..enumerated = [
      'team',
      'k9',
      'boat',
      'vehicle',
      'snowmobile',
      'atv',
      'commandpost',
      'other',
    ];

  /// Unit Status - Value Object
  APISchemaObject documentStatus() => APISchemaObject.string()
    ..description = "Unit status"
    ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed
    ..defaultValue = "mobilized"
    ..enumerated = [
      'mobilized',
      'deployed',
      'retired',
    ];
}