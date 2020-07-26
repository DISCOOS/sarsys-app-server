import 'package:event_source/event_source.dart';
import 'package:sarsys_app_server/controllers/event_source/controllers.dart';
import 'package:sarsys_domain/sarsys_domain.dart' hide Operation;
import 'package:sarsys_app_server/sarsys_app_server.dart';
import 'package:sarsys_app_server/validation/validation.dart';

class DevicePositionController extends DevicePositionControllerBase {
  DevicePositionController(DeviceRepository repository, JsonValidation validation)
      : super(
          repository,
          validation,
        );

  @override
  @Operation.get('uuid')
  Future<Response> get(@Bind.path('uuid') String uuid) {
    return super.get(uuid);
  }

  @override
  @Operation('PATCH', 'uuid')
  Future<Response> update(
    @Bind.path('uuid') String uuid,
    @Bind.body() Map<String, dynamic> data,
  ) =>
      super.update(
        uuid,
        data,
      );
}

class DevicePositionControllerBase extends ValueController<DeviceCommand, Device> {
  DevicePositionControllerBase(DeviceRepository repository, JsonValidation validation)
      : super(
          repository,
          "Position",
          "position",
          validation: validation,
          tag: "Device > Position",
        );

  @override
  Future<Response> update(
    @Bind.path('uuid') String uuid,
    @Bind.body() Map<String, dynamic> data,
  ) async {
    if (!await exists(uuid)) {
      return Response.notFound(body: "$aggregateType $uuid not found");
    }
    final aggregate = repository.get(uuid);
    final currProps = aggregate.data.elementAt('$aggregateField/properties');
    final nextProps = data.elementAt('properties') ?? {};
    // Enforce defaults?
    if (currProps == null) {
      nextProps['timestamp'] ??= DateTime.now().toIso8601String();
    }
    nextProps['source'] ??= 'manual';
    data['properties'] = nextProps;
    return super.update(
      uuid,
      data,
    );
  }

  @override
  DeviceCommand onUpdate(String uuid, String type, Map<String, dynamic> data) => UpdateDevicePosition(data);
}
