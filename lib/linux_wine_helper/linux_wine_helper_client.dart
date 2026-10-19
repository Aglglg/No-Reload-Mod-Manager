import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:no_reload_mod_manager/utils/detect_game_wine.dart';

class IniCheckError {
  final int lineIndex;
  final String filePath;
  final String trimmedLine;
  final String reason;

  IniCheckError({
    required this.lineIndex,
    required this.filePath,
    required this.trimmedLine,
    required this.reason,
  });
}

class WineHelperException implements Exception {
  WineHelperException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WineHelperClient {
  /// Called when the helper stops on its own (crash, last game closed). Not called by [stop].
  void Function()? onStopped;

  /// Every line the helper prints. Use it for a debug log.
  void Function(String line)? onLog;

  static const _readyPrefix = 'WINE_HELPER_READY port=';
  static final _badChars = RegExp(r'[\t\r\n]');

  Process? _process;
  Socket? _socket;
  String? _prefix; // Wine prefix the running helper belongs to
  final Set<int> _gamePids = {}; // running games in that prefix
  Timer? _gameWatcher;
  Future<void> _lastStart = Future.value(); // makes starts run one at a time
  final Queue<Completer<String>> _waitingForReply = Queue();

  bool get isRunning => _socket != null;

  // ---------- start / stop ----------

  /// Starts the helper in this game's Wine prefix.
  /// Same prefix already running: keeps it. Other prefix: stops it and switches.
  /// Throws [WineHelperException] if anything fails.
  Future<void> start(WineGame game) {
    // One start at a time, so fast clicks or quick game switching can't overlap
    final job = _lastStart.then((_) => _startNow(game));
    _lastStart = job.then((_) {}, onError: (_) {});
    return job;
  }

  Future<void> _startNow(WineGame game) async {
    final prefix = game.prefixPath.replaceFirst(RegExp(r'/+$'), '');

    if (isRunning) {
      if (prefix == _prefix) {
        _gamePids.add(game.pid); // same prefix, just remember this game too
        return;
      }
      await stop(); // other prefix, switch
    }

    _prefix = prefix;
    _gamePids
      ..clear()
      ..add(game.pid);

    final token = _makeToken();
    try {
      final process = await game.runExe(
        _findHelperExe(),
        mode:
            ProcessStartMode
                .normal, // normal = we get stdout, exit code and kill()
        extraEnvironment: {'WINE_HELPER_TOKEN': token, 'WINEDEBUG': '-all'},
      );
      _process = process;

      final port = await _readPort(process);
      await _connect(port, token);
      _watchGames();
    } catch (error) {
      await stop();
      if (error is WineHelperException) rethrow;
      throw WineHelperException(
        'Could not start Wine helper'.tr(args: [error.toString()]),
      );
    }
  }

  Future<void> stop() async {
    final process = _process;
    _resetState();
    if (process == null) return;

    process.kill();
    // The helper also quits by itself when the socket closes. SIGKILL only if it is stuck.
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }

  void _resetState() {
    _gameWatcher?.cancel();
    _gameWatcher = null;
    _prefix = null;
    _gamePids.clear();

    final socket = _socket;
    _socket = null;
    socket?.destroy();

    _process = null;

    while (_waitingForReply.isNotEmpty) {
      _waitingForReply.removeFirst().completeError(
        WineHelperException('Wine helper stopped'.tr()),
      );
    }
  }

  /// The helper died, the connection broke or the last game closed.
  void _helperLost() {
    if (!isRunning) return; // we stopped it ourselves
    unawaited(stop());
    onStopped?.call();
  }

  // ---------- startup steps ----------

  /// Where the helper lives. Works for `flutter run` and for the release bundle.
  static String _findHelperExe() {
    final appFolder = File(Platform.resolvedExecutable).parent.path;
    final path =
        '$appFolder/data/flutter_assets/assets/wine_helper/nrmm_wine_helper.exe';
    if (!File(path).existsSync()) {
      throw WineHelperException('Wine helper file is missing'.tr(args: [path]));
    }
    return path;
  }

  static String _makeToken() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
  }

  /// Waits for the helper's "ready" line and returns the port it picked.
  Future<int> _readPort(Process process) {
    final portFound = Completer<int>();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final port =
              line.startsWith(_readyPrefix)
                  ? int.tryParse(line.substring(_readyPrefix.length))
                  : null;

          if (port != null && !portFound.isCompleted) {
            portFound.complete(port);
          } else {
            onLog?.call(line);
          }
        });

    // Nobody needs Wine's stderr, but the pipe must be emptied or the helper freezes
    process.stderr.drain<void>();

    // Helper ended before it was ready (wine missing, dll missing, ...)
    process.exitCode.then((code) {
      if (!portFound.isCompleted) {
        portFound.completeError(
          WineHelperException(
            'Wine helper exited with code'.tr(args: [code.toString()]),
          ),
        );
      }
    });

    return portFound.future.timeout(
      const Duration(seconds: 20),
      onTimeout:
          () => throw WineHelperException('Wine helper start timed out'.tr()),
    );
  }

  Future<void> _connect(int port, String token) async {
    final socket = await Socket.connect(
      '127.0.0.1',
      port,
      timeout: const Duration(seconds: 3),
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.write('auth $token\n'); // first line must be the secret, no reply
    _socket = socket;

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (replyLine) {
            if (_waitingForReply.isNotEmpty) {
              _waitingForReply.removeFirst().complete(replyLine);
            }
          },
          onDone: _helperLost,
          onError: (_) => _helperLost(),
        );
  }

  /// A helper left running would keep the Wine prefix busy, so it must end when the last game closes.
  void _watchGames() {
    _gameWatcher ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _gamePids.removeWhere((pid) => !Directory('/proc/$pid').existsSync());
      if (_gamePids.isEmpty) _helperLost();
    });
  }

  // ---------- commands ----------

  Future<String> _send(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    final socket = _socket;
    if (socket == null) {
      return Future.error(
        WineHelperException(
          'Wine helper is not connected, connect to it first.'.tr(),
        ),
      );
    }

    final reply = Completer<String>();
    _waitingForReply.add(reply);
    socket.write('$command\n');

    return reply.future.timeout(
      timeout,
      onTimeout: () {
        // Replies are matched by order, so after a missed reply the connection can't be trusted
        _helperLost();
        throw WineHelperException('Wine helper did not answer'.tr());
      },
    );
  }

  Future<void> simulateKeyDown(int key) async => await _send('keydown $key');
  Future<void> simulateKeyUp(int key) async => await _send('keyup $key');
  Future<void> setCursorPos(int x, int y) async =>
      await _send('setcursor $x $y');

  Future<List<IniCheckError>> checkIni({
    required String iniPath,
    required String basePath,
    required List<String> knownLibNamespaces,
  }) async {
    // One line = one command. A tab or new line inside a mod folder name
    // could otherwise sneak extra commands (like keydown) into the helper.
    for (final text in [iniPath, basePath, ...knownLibNamespaces]) {
      if (text.contains(_badChars)) {
        throw ArgumentError('Tabs and new lines are not allowed: $text');
      }
    }

    final command = [
      'inicheck',
      iniPath,
      basePath,
      ...knownLibNamespaces,
    ].join('\t');
    final reply =
        jsonDecode(await _send(command, timeout: const Duration(seconds: 60)))
            as Map<String, dynamic>;

    // Throw instead of returning an empty list, so "failed" never looks like "no errors"
    if (reply['error'] != null) {
      throw Exception('Ini check failed: ${reply['error']}');
    }

    return (reply['errors'] as List)
        .map(
          (item) => IniCheckError(
            lineIndex: item['line'],
            filePath: item['file'],
            trimmedLine: item['text'],
            reason: item['reason'],
          ),
        )
        .toList();
  }
}

final wineHelper = WineHelperClient();

enum WineHelperState { notConnected, connecting, connected, failed }
