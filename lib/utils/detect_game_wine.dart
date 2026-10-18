import 'dart:convert';
import 'dart:io';

/// A wine process found in /proc.
class _WineProcess {
  _WineProcess(this.pid, this.environment, this.executablePath);

  final int pid;
  final Map<String, String> environment;
  final String executablePath;
}

/// A running Windows game (under Wine or Proton) and everything needed to launch more exes beside it.
class WineGame {
  WineGame({
    required this.pid,
    required this.gameEnvironment,
    required this.wineBinary,
    required this.protonFolder,
  });

  /// Variables from the game's own process that must not reach a new process
  static const _gameOnlyVariables = {
    'WINESERVERSOCKET', // socket number the game inherited, doesn't exist in a new process
    'WINELOADERNOEXEC', // Wine internals, also per process
    'WINEPRELOADRESERVE',
    'LD_PRELOAD', // Steam overlay, gamemode
  };

  final int pid;
  final Map<String, String> gameEnvironment;
  final String wineBinary;
  final String? protonFolder; // null = plain Wine

  bool get isProton => protonFolder != null;
  String get prefixPath => gameEnvironment['WINEPREFIX'] ?? '';

  /// Finds a running game whose exe file name exactly matches [exeName] (case sensitive), e.g. "Game.exe".
  static Future<WineGame?> find(String exeName) async {
    final process = await _findWineProcess(exeName);
    if (process == null) return null;

    final binFolder = File(process.executablePath).parent;
    return WineGame(
      pid: process.pid,
      gameEnvironment: process.environment,
      wineBinary: _findWineLauncher(binFolder),
      protonFolder: _findProtonFolder(binFolder),
    );
  }

  /// Returns the pid of [exeName] if it is already running in this game's prefix, otherwise null.
  Future<int?> findRunningInSamePrefix(String exeName) async {
    final process = await _findWineProcess(exeName, onlyPrefix: prefixPath);
    return process?.pid;
  }

  /// Starts [exePath] only if it is not already running in the same prefix.
  /// Returns the pid of the existing or the newly started process.
  Future<int> runExeOnce(
    String exePath, {
    List<String> arguments = const [],
  }) async {
    final exeName = exePath.split('/').last;

    final existingPid = await findRunningInSamePrefix(exeName);
    if (existingPid != null) return existingPid;

    final newProcess = await runExe(exePath, arguments: arguments);
    return newProcess.pid;
  }

  /// Runs [exePath] with the same Wine/Proton and the same prefix as the game.
  Future<Process> runExe(
    String exePath, {
    List<String> arguments = const [],
    Map<String, String> extraEnvironment = const {},
    ProcessStartMode mode = ProcessStartMode.detachedWithStdio,
  }) {
    final environment = Map<String, String>.from(gameEnvironment)
      ..removeWhere((name, _) => _gameOnlyVariables.contains(name));

    // The game's bus lives inside Steam's container, so use the real session bus
    final sessionBus = Platform.environment['DBUS_SESSION_BUS_ADDRESS'];
    if (sessionBus != null) {
      environment['DBUS_SESSION_BUS_ADDRESS'] = sessionBus;
    } else {
      environment.remove('DBUS_SESSION_BUS_ADDRESS');
    }

    environment.addAll(extraEnvironment);
    final exeFolder = File(exePath).parent.path;

    if (isProton) {
      environment['STEAM_COMPAT_DATA_PATH'] ??=
          Directory(prefixPath).parent.path;
      return Process.start(
        '$protonFolder/proton',
        ['run', exePath, ...arguments],
        environment: environment,
        includeParentEnvironment: false,
        workingDirectory: exeFolder,
        mode: mode,
      );
    }

    return Process.start(
      wineBinary,
      [exePath, ...arguments],
      environment: environment,
      includeParentEnvironment: false,
      workingDirectory: exeFolder,
      mode: mode,
    );
  }

  // ---------- helpers ----------

  static final _pathSeparator = RegExp(r'[\\/]');

  /// True if any argument is a path whose file name is exactly [exeName] (case sensitive).
  /// Works for "/home/me/Game.exe" and "Z:\home\me\Game.exe".
  static bool _hasExactExeName(List<String> arguments, String exeName) {
    for (final argument in arguments) {
      final fileName = argument.split(_pathSeparator).last;
      if (fileName == exeName) return true;
    }
    return false;
  }

  /// Scans /proc for a wine process whose command line exactly matches [exeName].
  /// If [onlyPrefix] is given, the process must also use that WINEPREFIX.
  static Future<_WineProcess?> _findWineProcess(
    String exeName, {
    String? onlyPrefix,
  }) async {
    final wantedPrefix =
        onlyPrefix == null ? null : _withoutTrailingSlash(onlyPrefix);

    await for (final entry in Directory('/proc').list(followLinks: false)) {
      final pid = int.tryParse(entry.path.split('/').last);
      if (pid == null) continue;

      try {
        final arguments = (await _readProcFile(
          '/proc/$pid/cmdline',
        )).split('\u0000');
        if (!_hasExactExeName(arguments, exeName)) continue;

        // Wrapper processes (umu.exe) mention the game in their command line but are not the game.
        // Wine names each process after its exe (cut to 15 characters), so compare that name too.
        final processName = (await _readProcFile('/proc/$pid/comm')).trim();
        if (!exeName.toLowerCase().startsWith(processName.toLowerCase())) {
          continue;
        }

        // Only real wine processes, skips helpers like "proton waitforexitandrun" (python).
        final executablePath =
            await File('/proc/$pid/exe').resolveSymbolicLinks();
        if (!executablePath.split('/').last.startsWith('wine')) continue;

        final environment = _parseEnvironment(
          await _readProcFile('/proc/$pid/environ'),
        );

        if (wantedPrefix != null) {
          final processPrefix = _withoutTrailingSlash(
            environment['WINEPREFIX'] ?? '',
          );
          if (processPrefix != wantedPrefix) continue;
        }

        return _WineProcess(pid, environment, executablePath);
      } catch (_) {
        continue; // process closed or no permission, skip it
      }
    }
    return null;
  }

  static String _withoutTrailingSlash(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;

  static Future<String> _readProcFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Map<String, String> _parseEnvironment(String rawText) {
    final environment = <String, String>{};
    for (final line in rawText.split('\u0000')) {
      final equalsIndex = line.indexOf('=');
      if (equalsIndex <= 0) continue;
      environment[line.substring(0, equalsIndex)] = line.substring(
        equalsIndex + 1,
      );
    }
    return environment;
  }

  static String? _findProtonFolder(Directory binFolder) {
    final parentName = binFolder.parent.path.split('/').last;
    if (parentName != 'files' && parentName != 'dist') return null;

    final protonFolder = binFolder.parent.parent.path;
    return File('$protonFolder/proton').existsSync() ? protonFolder : null;
  }

  static String _findWineLauncher(Directory binFolder) {
    for (final name in ['wine64', 'wine']) {
      final path = '${binFolder.path}/$name';
      if (File(path).existsSync()) return path;
    }
    return 'wine';
  }
}
