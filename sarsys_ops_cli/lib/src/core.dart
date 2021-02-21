import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:args/args.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:args/command_runner.dart';
import 'package:dart_app_data/dart_app_data.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;
import 'package:event_source/event_source.dart' hide Command;

final highlight = AnsiPen()..gray();
final red = AnsiPen()..red(bold: true);
final gray = AnsiPen()..gray(level: 0.5);
final green = AnsiPen()..green(bold: true);
final fill = (int length, [String delimiter = ' ']) => List.filled(length, delimiter).join();
final pad = (String text, int indent, int max) => '${fill(indent)}$text${fill(math.max(0, max - '$text'.length))}';

String sprint(
  int length, {
  @required StringBuffer buffer,
  int indent = 2,
  String Function(String) format,
}) {
  final separator = fill(length, '-');
  final spaces = fill(indent);
  buffer.writeln(
    format == null ? '$spaces$separator' : format('$spaces$separator'),
  );
  return separator;
}

void vprint(
  String label,
  Object value, {
  @required StringBuffer buffer,
  int max = 52,
  int left = 16,
  int indent = 2,
  String unit = '',
}) {
  final _value = (value ?? '').toString();
  final length = left + _value.length + 2;
  final hasUnit = (unit ?? '').isNotEmpty;
  final prefix = '${pad('$label:', indent, left)}${green(_value)}';
  final rest = hasUnit ? math.max(0, max - length - '$unit'.length) : 0;
  buffer.writeln(
    '$prefix${hasUnit ? '${fill(rest)}${gray('($unit)')}' : ''}',
  );
}

const defaultConfig = {
  'ops': {
    'scheme': 'https',
    'host': 'sarsys.app',
    'port': 443,
  },
  'auth': {
    'client_id': 'sarsys-app',
    'discovery_uri': 'https://id.discoos.io/auth/realms/DISCOOS',
  }
};

String get homeDir {
  var home = '';
  final envVars = Platform.environment;
  if (Platform.isMacOS) {
    home = envVars['HOME'];
  } else if (Platform.isLinux) {
    home = envVars['HOME'];
  } else if (Platform.isWindows) {
    home = envVars['UserProfile'];
  }
  return home;
}

String get appDataDir {
  return AppData.findOrCreate('sarsysctl').path;
}

File get defaultConfigFile => File(
      p.join(appDataDir, 'config.yaml'),
    );

AppData findOrCreateDataDir(String name) {
  return AppData.findOrCreate(name);
}

String usage(String command, String description, ArgParser parser, [List<String> commands]) {
  final buffer = StringBuffer();
  final withCommands = commands?.isNotEmpty == true;
  buffer.writeln(description);
  buffer.writeln();
  buffer.writeln('Usage:');
  buffer.writeln('  $command ${withCommands ? '[command] ' : ''}[options]');
  buffer.writeln();
  if (withCommands) {
    buffer.writeln('Available commands:');
    commands..map((l) => '  $l').forEach(buffer.writeln);
    buffer.writeln();
  }
  buffer.writeln('Global options:');
  buffer.writeln(parser.usage.split('\n').map((l) => '  $l').join('\n'));
  return buffer.toString();
}

File toConfigFile(BaseCommand command) {
  return File(
    command.globalResults['config'] ?? defaultConfigFile,
  );
}

Map<String, dynamic> ensureConfig(
  File file, {
  Map<String, dynamic> defaultMap = defaultConfig,
}) {
  var config = <String, dynamic>{};
  if (file.existsSync()) {
    config = Map<String, dynamic>.from(loadYaml(file.readAsStringSync()) ?? {});
  }
  if (config.isEmpty) {
    config = Map<String, dynamic>.from(
      defaultMap,
    );
  }
  return config;
}

void writeConfig(File file, Map<String, dynamic> config) {
  file.writeAsStringSync(jsonEncode(config));
}

abstract class BaseCommand extends Command<String> {
  final buffer = StringBuffer();
  final client = HttpClient();
  bool silent = false;

  Map<String, dynamic> _config;
  Map<String, dynamic> get config {
    return _config ??= ensureConfig(toConfigFile(this));
  }

  int get port => config.elementAt<int>('ops/port');
  String get host => config.elementAt<String>('ops/host');
  String get scheme => config.elementAt<String>('ops/scheme');

  Uri get baseUrl => Uri.parse('$scheme://$host:$port');
  Uri toURL(String uri) => uri.startsWith('/') ? Uri.parse('$baseUrl$uri') : Uri.parse('$baseUrl/$uri');

  @override
  FutureOr<String> run() async {
    switch (argResults['output'] as String) {
      case 'json':
        silent = true;
        final json = await onJson();
        silent = false;
        write(json, stdout);
        break;
      default:
        await onPrint();
        break;
    }
    return buffer.toString();
  }

  Future onPrint() => throw UnimplementedError('onPrint not implemented');
  FutureOr<String> onJson() => throw UnimplementedError('onJson not implemented');

  Future<String> get(
    HttpClient client,
    String uri,
    String Function(dynamic) map, {
    String Function(String) format,
    String token,
  }) async {
    final tic = DateTime.now();
    final buffer = StringBuffer();
    final url = toURL(uri);
    final request = await client.getUrl(url);
    if (token != null) {
      request.headers.add('Authorization', 'Bearer $token');
    }
    final response = await request.close();
    final result = '${response.statusCode} ${response.reasonPhrase} in ';
    if (HttpStatus.ok == response.statusCode) {
      final content = map(await toContent(response));
      buffer.writeln(
        format == null ? green(content) : format(content),
      );
      if (!silent) {
        buffer.write('  ');
      }
    } else {
      buffer.write(red('  Failure '));
    }
    if (!silent) {
      buffer.write(gray('($result${DateTime.now().difference(tic).inMilliseconds} ms)'));
    }
    return buffer.toString();
  }

  Future<String> post(
    HttpClient client,
    String uri,
    dynamic json,
    String Function(dynamic) map, {
    String Function(String) format,
    String token,
  }) async {
    final tic = DateTime.now();
    final buffer = StringBuffer();
    final url = toURL(uri);
    final request = await client.postUrl(url);
    if (token != null) {
      request.headers.add('Authorization', 'Bearer $token');
    }
    request.headers.add('Content-Type', 'application/json; charset=utf-8');
    request.write(jsonEncode(json));
    final response = await request.close();
    final result = '${response.statusCode} ${response.reasonPhrase} in ';
    if (HttpStatus.ok == response.statusCode) {
      final content = map(await toContent(response));
      buffer.writeln(
        format == null ? green(content) : format(content),
      );
      buffer.write('  ');
    } else {
      buffer.write(red('  Failure '));
    }
    buffer.write(gray('($result${DateTime.now().difference(tic).inMilliseconds} ms)'));
    return buffer.toString();
  }

  Future<String> isOK(
    HttpClient client,
    String uri, {
    String access = 'Yes',
    String failure = 'No',
    String token,
  }) async {
    final tic = DateTime.now();
    final buffer = StringBuffer();
    final url = toURL(uri);
    final request = await client.getUrl(url);
    if (token != null) {
      request.headers.add('Authorization', 'Bearer $token');
    }
    final response = await request.close();
    final reason = '${response.statusCode} ${response.reasonPhrase} in ';
    if (HttpStatus.ok == response.statusCode) {
      buffer.write(green('$access'));
    } else {
      buffer.write(red('$failure'));
    }
    buffer.write(gray(' ($reason${DateTime.now().difference(tic).inMilliseconds} ms)'));
    return buffer.toString();
  }

  static Future<dynamic> toContent(HttpClientResponse response) async {
    final completer = Completer<String>();
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen(
          contents.write,
          onDone: () => completer.complete(contents.toString()),
        );
    final json = await completer.future;
    return jsonDecode(json);
  }

  String write(String message, IOSink sink) {
    if (!silent) {
      buffer.write(message);
      sink.write(message);
    }
    return message;
  }

  String writeln(String message, IOSink sink) {
    if (!silent) {
      buffer.writeln(message);
      sink.writeln(message);
    }
    return message;
  }
}
