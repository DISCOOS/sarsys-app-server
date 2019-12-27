import 'package:sarsys_app_server/auth/oidc.dart';
import 'package:sarsys_app_server/controllers/health_controller.dart';
import 'package:sarsys_app_server/controllers/app_config_controller.dart';
import 'package:sarsys_app_server/domain/messages.dart';
import 'package:sarsys_app_server/eventstore/eventstore.dart';

import 'controllers/websocket_controller.dart';
import 'domain/app_config.dart';
import 'sarsys_app_server.dart';

/// MUST BE used when bootstrapping Aqueduct
const int isolateStartupTimeout = 120;

/// This type initializes an application.
///
/// Override methods in this class to set up routes and initialize services like
/// database connections. See http://aqueduct.io/docs/http/channel/.
class SarSysAppServerChannel extends ApplicationChannel {
  /// Validates oidc tokens against scopes
  final OIDCValidator validator = OIDCValidator();

  /// Channel responsible for distributing messages to client applications
  final MessageChannel messages = MessageChannel(
    handler: WebSocketMessageProcessor(),
  );

  /// Manages an [EventStore] for each registered event stream
  EventStoreManager manager;

  /// Logger instance
  @override
  final Logger logger = Logger("SarSysAppServerChannel")
    ..onRecord.listen(
      printRecord,
    );

  /// Initialize services in this method.
  ///
  /// Implement this method to initialize services, read values from [options]
  /// and any other initialization required before constructing [entryPoint].
  ///
  /// This method is invoked prior to [entryPoint] being accessed.
  @override
  Future prepare() async {
    final stopwatch = Stopwatch()..start();

    // Parse from config file, given by --config to main.dart or default config.yaml
    final config = SarSysConfig(options.configurationFilePath);

    // Set log level
    Logger.root.level = Level.LEVELS.firstWhere(
      (level) => level.name == config.level,
      orElse: () => Level.INFO,
    );
    logger.info("Log level set to ${Logger.root.level.name}");

    // Construct manager from configurations
    manager = EventStoreManager(
      MessageBus(),
      EventStoreConnection(
        host: config.eventstore.host,
        port: config.eventstore.port,
        credentials: UserCredentials(
          login: config.eventstore.login,
          password: config.eventstore.password,
        ),
      ),
      prefix: config.prefix,
    );

    // Register events handled by message broker
    messages.register<AppConfigCreated>(manager.bus);
    messages.register<AppConfigUpdated>(manager.bus);
    messages.build();

    // Register aggregate-root repositories
    manager.register<AppConfig>((store) => AppConfigRepository(store));
    await manager.build();
    logger.info("Built repositories in ${stopwatch.elapsedMilliseconds}ms");

    // Sanity check
    if (stopwatch.elapsed.inSeconds > isolateStartupTimeout * 0.8) {
      logger.severe("Approaching maximum duration to wait for each isolate to complete startup");
    }
  }

  /// Print [LogRecord] formatted
  static void printRecord(LogRecord rec) {
    print(
      "${rec.time}: ${rec.level.name}: ${rec.loggerName}: "
      "${rec.message} ${rec.error ?? ""} ${rec.stackTrace ?? ""}",
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
    final authorizer = Authorizer.bearer(validator, scopes: ['roles']);
    return Router()
      ..route('/').link(() => authorizer)
      ..route('/api/*').link(
        () => FileController("web")
          ..addCachePolicy(
            const CachePolicy(preventCaching: true),
            (p) => p.endsWith("client.html"),
          ),
      )
      ..route('/api/healthz').link(() => HealthController())
      ..route('/api/app-config[/:uuid]').link(() => AppConfigController(manager.get<AppConfig>()))
      ..route('/api/connect').link(() => WebSocketController(messages));
  }

  @override
  Future close() {
    manager?.dispose();
    messages?.dispose();
    manager?.connection?.close();
    return super.close();
  }

  @override
  void documentComponents(APIDocumentContext registry) {
    registry.securitySchemes.register(
      "id.discoos.io",
      APISecurityScheme.openID(Uri.parse("https://id.discoos.io")),
    );
    registry.responses
      ..register(
          "201",
          APIResponse(
            "Created. The POST-ed resource was created.",
          ))
      ..register(
          "204",
          APIResponse(
            "No Content. The resource was updated.",
          ))
      ..register(
          "401",
          APIResponse(
            "Unauthorized. The client must authenticate itself to get the requested response.",
          ))
      ..register(
          "403",
          APIResponse(
            "Forbidden. The client does not have access rights to the content.",
          ))
      ..register(
        "404",
        APIResponse("Not found. The requested resource does not exist in server."),
      )
      ..register(
          "405",
          APIResponse(
            "Method Not Allowed. The request method is known by the server but has been disabled and cannot be used.",
          ))
      ..register(
          "409",
          APIResponse(
            "Conflict. This response is sent when a request conflicts with the current state of the server.",
          ));
    super.documentComponents(registry);
  }
}

class SarSysConfig extends Configuration {
  SarSysConfig(String path) : super.fromFile(File(path));

  /// Stream prefix
  String prefix;

  /// Log level
  @optionalConfiguration
  String level = Level.INFO.name;

  /// [EventStore](www.eventstore.org) config values
  EvenStoreConfig eventstore;
}

class EvenStoreConfig extends Configuration {
  EvenStoreConfig();

  /// The host of the database to connect to.
  ///
  /// This property is required.
  String host;

  /// The port of the database to connect to.
  ///
  /// This property is required.
  int port;

  /// A username for authenticating to the database.
  ///
  /// This property is required.
  String login;

  /// A password for authenticating to the database.
  ///
  /// This property is required.
  String password;
}
