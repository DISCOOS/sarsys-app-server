import 'package:sarsys_app_server/controllers/eventsource/aggregate_controller.dart';
import 'package:sarsys_app_server/domain/tenant/app_config.dart';
import 'package:sarsys_app_server/sarsys_app_server.dart';
import 'package:sarsys_app_server/validation/validation.dart';

/// A ResourceController that handles
/// [/api/app-config](http://localhost/api/client.html#/AppConfig) [Request]s
class AppConfigController extends AggregateController<AppConfigCommand, AppConfig> {
  AppConfigController(AppConfigRepository repository, RequestValidator validator)
      : super(repository, validator: validator, tag: 'Tenant');

  @override
  AppConfigCommand onCreate(Map<String, dynamic> data) => CreateAppConfig(data);

  @override
  AppConfigCommand onUpdate(Map<String, dynamic> data) => UpdateAppConfig(data);

  @override
  AppConfigCommand onDelete(Map<String, dynamic> data) => DeleteAppConfig(data);

  //////////////////////////////////
  // Documentation
  //////////////////////////////////

  @override
  String documentOperationDescription(APIDocumentContext context, Operation operation) {
    String desc = "${documentOperationSummary(context, operation)}. ";
    switch (operation.method) {
      case "GET":
        desc += operation.pathVariables.isEmpty
            ? "This operation is only allowed for admin users."
            : "A configuration is unique for each application regardless of which user is logged in.";
        break;
      case "POST":
        desc += "The field [uuid] MUST BE unique for each application. "
            "Use a OS-spesific device id or a [universally unique identifier]"
            "(https://en.wikipedia.org/wiki/Universally_unique_identifier).";
        break;
      case "PATCH":
        desc += "Only fields in request are updated. Existing values WILL BE overwritten, others remain unchanged.";
        break;
    }
    return desc;
  }

  /// AppConfig - Aggregate root
  @override
  APISchemaObject documentAggregateRoot(APIDocumentContext context) => APISchemaObject.object(
        {
          "uuid": APISchemaObject.string(format: 'uuid')
            ..format = 'uuid'
            ..description = "Unique application id",
          "demo": APISchemaObject.boolean()
            ..description = "Use demo-mode (no real data and any login)"
            ..defaultValue = true,
          "demoRole": APISchemaObject.string()
            ..description = "Role of logged in user in demo-mode"
            ..defaultValue = "Commander"
            ..enumerated = [
              'commander',
              'unitleader',
              'personnel',
            ],
          "onboarding": APISchemaObject.boolean()
            ..description = "Show onboarding before next login"
            ..defaultValue = true,
          "organization": APISchemaObject.string()
            ..description = "Default organization identifier"
            ..defaultValue = "61",
          "division": APISchemaObject.string()
            ..description = "Default division identifier"
            ..defaultValue = "140",
          "department": APISchemaObject.string()
            ..description = "Default department identifier"
            ..defaultValue = "141",
          "talkGroupCatalog": APISchemaObject.string()
            ..description = "Default talkgroup name"
            ..defaultValue = "Oslo",
          "storage": APISchemaObject.boolean()
            ..description = "Storage access is granted"
            ..defaultValue = false,
          "locationWhenInUse": APISchemaObject.boolean()
            ..description = "Location access when app is in use is granted"
            ..defaultValue = false,
          "mapCacheTTL": APISchemaObject.integer()
            ..description = "Number of days downloaded map tiles are cached locally"
            ..defaultValue = 30,
          "mapCacheCapacity": APISchemaObject.integer()
            ..description = "Maximum number map tiles cached locally"
            ..defaultValue = 15000,
          "locationAccuracy": APISchemaObject.string()
            ..description = "Requested location accuracy"
            ..defaultValue = 'high'
            ..enumerated = [
              'lowest',
              'low',
              'medium',
              'high',
              'best',
              'bestForNavigation',
            ],
          "locationFastestInterval": APISchemaObject.integer()
            ..description = "Fastest interval between location updates in milliseconds"
            ..defaultValue = 1000,
          "locationSmallestDisplacement": APISchemaObject.integer()
            ..description = "Smallest displacment in meters before update is received"
            ..defaultValue = 3,
          "keepScreenOn": APISchemaObject.boolean()
            ..description = "Keep screen on when maps are displayed"
            ..defaultValue = false,
          "callsignReuse": APISchemaObject.boolean()
            ..description = "Reuse callsigns for retired units"
            ..defaultValue = true,
          "sentryDns": APISchemaObject.string(format: 'uri')
            ..description = "Sentry DNS for remote error reporting"
            ..defaultValue = 'https://2d6130375010466b9652b9e9efc415cc@sentry.io/1523681',
        },
      )
        ..description = "SarSys application configuration"
        ..additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed
        ..required = ['uuid'];
}