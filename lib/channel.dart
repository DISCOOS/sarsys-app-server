import 'package:sarsys_app_server/auth/access_validator.dart';
import 'package:sarsys_app_server/controllers/app_config_controller.dart';

import 'sarsys_app_server.dart';

/// This type initializes an application.
///
/// Override methods in this class to set up routes and initialize services like
/// database connections. See http://aqueduct.io/docs/http/channel/.
class SarSysAppServerChannel extends ApplicationChannel {
  /// Authorization validator
  final AccessValidator validator = AccessValidator();

  /// Initialize services in this method.
  ///
  /// Implement this method to initialize services, read values from [options]
  /// and any other initialization required before constructing [entryPoint].
  ///
  /// This method is invoked prior to [entryPoint] being accessed.
  @override
  Future prepare() async {
    logger.onRecord.listen(
      (rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"),
    );
  }

  /// Construct the request channel.
  ///
  /// Return an instance of some [Controller] that will be the initial receiver
  /// of all [Request]s.
  ///
  /// This method is invoked after [prepare].
  @override
  Controller get entryPoint {
    final router = Router();
    final authorizer = Authorizer.bearer(validator);

    router
      ..route('/').link(() => authorizer)
      ..route('/healthz').linkFunction((req) async => Response.noContent())
      ..route('/app-config/:id').link(() => AppConfigController())
      ..route('/api/*').link(() => FileController("web"));

    return router;
  }
}
