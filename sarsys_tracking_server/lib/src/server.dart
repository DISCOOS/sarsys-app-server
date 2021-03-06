import 'dart:io';

import 'package:event_source_grpc/event_source_grpc.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:sarsys_domain/sarsys_domain.dart';
import 'package:sarsys_core/sarsys_core.dart';

import 'config.dart';
import 'service.dart';

class SarSysTrackingServer {
  static RemoteLogger _remoteLogger;

  final Logger logger = Logger('SarSysTrackingServer');

  HttpServer _http;
  grpc.Server _grpc;
  TrackingService service;
  RepositoryManager manager;
  SarSysTrackingConfig config;
  StreamSubscription _subscription;

  bool get isOpen => _http != null;
  bool get isReady => isOpen && manager.isReady;
  bool get isBuilding => isOpen && !manager.isReady;

  /// Print [LogRecord] formatted
  static void printRecord(LogRecord rec, {bool debug = false, bool stdout = false}) {
    if (stdout) {
      Context.printRecord(rec, debug: debug);
    }
    _remoteLogger?.log(rec);
  }

  Future start(SarSysTrackingConfig config) async {
    // Start to listen for health checks
    _listen(config.healthPort);

    // Start tracking service
    await _build(config);

    // Start grpc service
    _grpc = grpc.Server([
      AggregateGrpcService(manager),
      RepositoryGrpcService(manager),
      SarSysTrackingGrpcService(this),
      SnapshotGrpcService(manager, config.data.path),
    ]);

    return _grpc.serve(
      port: config.grpcPort,
    );
  }

  void _listen(int port) async {
    // Start health check
    _http = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
    );

    // This will bloc until stop is called
    await for (HttpRequest request in _http) {
      final handle = '${request.method.toUpperCase()} ${request.uri.path}';
      logger.finer(Context.toMethod('_listen', ['handle: $handle']));
      switch (handle) {
        case 'GET /api/healthz/alive':
          _onHandleAlive(request);
          break;
        case 'GET /api/healthz/ready':
          _onHandleReady(request);
          break;
        default:
          request.response
            ..statusCode = 404
            ..write('Not found');
      }

      logger.info(
        '$handle ${request.response.statusCode} ${request.response.reasonPhrase}',
      );

      await request.response.close();
    }
  }

  void _onHandleAlive(HttpRequest request) {
    request.response
      ..statusCode = 200
      ..write('OK');
    logger.info(
      '${request.method.toUpperCase()} ${request.uri.path} 200 OK',
    );
  }

  void _onHandleReady(HttpRequest request) {
    if (isReady) {
      request.response
        ..statusCode = 200
        ..write('OK');
    } else {
      request.response
        ..statusCode = 503
        ..write('Manager is not ready');
    }
  }

  Future stop() async {
    if (isOpen) {
      await _grpc.shutdown();
      await _http.close();
      await _subscription.cancel();
      _http = null;
      _grpc = null;
    }
  }

  Future<void> _build(SarSysModuleConfig config) async {
    try {
      final stopwatch = Stopwatch()..start();

      await _loadConfig(config);
      _initHive();
      _buildRepoManager();
      _buildRepos(
        stopwatch,
        catchError: _terminateOnFailure,
        whenComplete: _buildDomainServices,
      );
    } catch (e, stackTrace) {
      _terminateOnFailure(e, stackTrace);
    }
  }

  Future<void> _loadConfig(SarSysTrackingConfig config) async {
    this.config = config;
    config.host = Platform.localHostname;
    final level = LoggerConfig.toLevel(
      config.logging.level,
    );
    Logger.root.level = level;
    _subscription = logger.onRecord.where((event) => logger.level >= level).listen(
          (record) => printRecord(
            record,
            debug: config.debug,
            stdout: config.logging.stdout,
          ),
        );
    logger.info("Server log level set to ${Logger.root.level.name}");
    if (config.logging.sentry != null) {
      _remoteLogger = RemoteLogger(
        config.logging.sentry,
        config.tenant,
      );
      await _remoteLogger.init();
      logger.info("Sentry DSN is ${config.logging.sentry.dsn}");
      logger.info("Sentry log level set to ${_remoteLogger.level}");
    }

    logger.info("SERVER url is ${config.url}");
    logger.info("EVENTSTORE url is ${config.eventstore.url}");
    logger.info("EVENTSTORE_PORT is ${config.eventstore.port}");
    logger.info("EVENTSTORE_LOGIN is ${config.eventstore.login}");
    logger.info("EVENTSTORE_REQUIRE_MASTER is ${config.eventstore.requireMaster}");

    if (config.debug == true) {
      logger.info("Debug mode enabled");
      if (Platform.environment.containsKey("IMAGE")) {
        logger.info("IMAGE is '${Platform.environment["IMAGE"]}'");
      }
      if (Platform.environment.containsKey("PREFIX")) {
        logger.info("PREFIX is '${Platform.environment["PREFIX"]}'");
      }
      if (Platform.environment.containsKey("NODE_NAME")) {
        logger.info("NODE_NAME is '${Platform.environment["NODE_NAME"]}'");
      }
      if (Platform.environment.containsKey("POD_NAME")) {
        logger.info("POD_NAME is '${Platform.environment["POD_NAME"]}'");
      }
      if (Platform.environment.containsKey("POD_NAMESPACE")) {
        logger.info("POD_NAMESPACE is '${Platform.environment["POD_NAMESPACE"]}'");
      }
    }
    logger.info("TENANT is '${config.tenant == null ? 'not set' : '${config.tenant}'}'");

    logger.info("AUTHORIZATION is ${config.auth.enabled ? 'ENABLED' : 'DISABLED'}");
    if (config.auth.enabled) {
      logger.info("OpenID Connect Provider BASE URL is ${config.auth.baseUrl}");
      logger.info("OpenID Connect Provider Issuer is ${config.auth.issuer}");
      logger.info("OpenID Connect Provider Audience is ${config.auth.audience}");
      logger.info("OpenID Connect Provider Roles Claims are ${config.auth.rolesClaims}");
    }

    // Ensure that data path exists?
    if (config.data.enabled) {
      final dir = Directory(config.data.path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
        logger.info("Created data path ${config.data.path}");
      } else {
        logger.info("Data path is ${config.data.path}");
      }
      if (config.data.snapshots.enabled) {
        logger.info("Snapshot keep is ${config.data.snapshots.keep}");
        logger.info("Snapshot threshold is ${config.data.snapshots.threshold}");
      } else {
        logger.info("Snapshots DISABLED");
      }
    } else {
      logger.info("Data is DISABLED");
    }
  }

  void _buildRepoManager() {
    final namespace = EventStore.toCanonical([
      config.tenant,
      config.prefix,
    ]);

    // Construct manager from configurations
    manager = RepositoryManager(
      MessageBus(),
      EventStoreConnection(
        host: config.eventstore.host,
        port: config.eventstore.port,
        scheme: config.eventstore.scheme,
        credentials: UserCredentials(
          login: config.eventstore.login,
          password: config.eventstore.password,
        ),
        requireMaster: config.eventstore.requireMaster,
      ),
      prefix: namespace,
    );
  }

  void _buildRepos(
    Stopwatch stopwatch, {
    Function() whenComplete,
    Function(Object error, StackTrace stackTrace) catchError,
  }) {
    // Register independent repositories
    register<Device>((store) => DeviceRepository(store));
    register<Tracking>((store) => TrackingRepository(store));

    // Defer repository builds so that isolates are
    // not killed on eventstore connection timeouts
    Future.microtask(() => _buildReposAsync(stopwatch))
      ..then((_) => whenComplete())
      ..catchError(catchError);
  }

  void register<T extends AggregateRoot>(
    Repository<Command, T> Function(EventStore store) create, {
    String prefix,
    String stream,
    bool useInstanceStreams = true,
  }) {
    final snapshots = config.data.snapshots.enabled
        ? Storage.fromType<T>(
            keep: config.data.snapshots.keep,
            threshold: config.data.snapshots.threshold,
          )
        : null;
    manager.register<T>(
      create,
      prefix: prefix,
      stream: stream,
      snapshots: snapshots,
      useInstanceStreams: useInstanceStreams,
    );
  }

  void _initHive() {
    if (config.data.enabled) {
      final hiveDir = Directory(config.data.path);
      hiveDir.createSync(recursive: true);
      Hive.init(hiveDir.path);
    }
  }

  Future _buildReposAsync(Stopwatch stopwatch) async {
    // Initialize
    await Storage.init();

    await manager.prepare(withProjections: [
      '\$by_category',
      '\$by_event_type',
    ]);
    final count = await manager.build();
    logger.info("Processed $count events!");
    logger.info(
      "Built repositories in ${stopwatch.elapsedMilliseconds}ms => ready for aggregate requests!",
    );
  }

  Future<TrackingService> _buildDomainServices() async {
    service = TrackingService(
      manager.get<TrackingRepository>(),
      dataPath: config.data.path,
      snapshot: config.data.enabled,
      devices: manager.get<DeviceRepository>(),
    );
    await service.build(
      start: config.startup,
    );
    return service;
  }

  void _terminateOnFailure(Object error, StackTrace stackTrace) {
    if (isOpen) {
      if (error is ClientException || error is SocketException) {
        logger.severe(
          "Failed to connect to eventstore with ${manager.connection}",
          error,
          Trace.from(stackTrace),
        );
      } else {
        logger.severe(
          "Failed to build repositories: $error: $stackTrace",
          error,
          Trace.from(stackTrace),
        );
      }
    }
    logger.severe(
      "Terminating server safely...",
      error,
      Trace.from(stackTrace),
    );
    _http?.close();
    _grpc?.shutdown();
  }
}
