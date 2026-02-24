import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class SevenZip {
  SevenZip._();
  static final SevenZip instance = SevenZip._();

  String? _exePath;

  /// Supported Formats List
  static const List<ArchiveFormat> _supportedFormats = [
    ArchiveFormat(extension: '7z', label: '7-Zip'),
    ArchiveFormat(extension: 'zip', label: 'ZIP'),
    ArchiveFormat(extension: 'rar', label: 'RAR'),
    ArchiveFormat(extension: 'tar', label: 'TAR'),
    ArchiveFormat(extension: 'gz', label: 'GZip'),
    ArchiveFormat(extension: 'bz2', label: 'BZip2'),
    ArchiveFormat(extension: 'xz', label: 'XZ'),
  ];

  static Set<String> get _supportedExtensions =>
      _supportedFormats.map((f) => f.extension).toSet();

  static bool isSupported(String filePath) {
    final lower = filePath.toLowerCase();

    if (lower.endsWith('.tar.gz') ||
        lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tar.xz')) {
      return true;
    }

    final ext =
        lower.contains('.') ? lower.substring(lower.lastIndexOf('.') + 1) : '';
    return _supportedExtensions.contains(ext);
  }

  /// Initialize
  Future<void> _initialize() async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final sevenZipDir = Directory(p.join(exeDir, '7z'));

    _exePath = p.join(sevenZipDir.path, '7z.exe');
  }

  /// Checks if the archive is password-protected without extracting
  Future<bool> isEncrypted(String archivePath) async {
    if (_exePath == null) {
      await _initialize();
    }

    final args = ['l', archivePath, '-slt', '-p'];

    try {
      final result = await Process.run(
        _exePath!,
        args,
      ).timeout(const Duration(seconds: 10));

      final output = result.stdout.toString();

      // Looks for the "Encrypted = +" line in the -slt output, means encrypted
      if (output.contains('Encrypted = +')) {
        return true;
      }

      return false;
    } catch (_) {
      // If the process fails or times out, assume we can't read it (safest bet)
      return false;
    }
  }

  /// Extract any archive to [outputDir]
  Future<SevenZipResult> extract(
    String archivePath, {
    required String outputDir,
    String password = '',
    void Function(String line)? onProgress,
  }) async {
    if (_exePath == null) {
      await SevenZip.instance._initialize();
    }

    await Directory(outputDir).create(recursive: false);

    final args = ['x', archivePath, '-o$outputDir', '-y', '-p$password'];

    final process = await Process.start(_exePath!, args);

    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stdoutLines.add(line);
          onProgress?.call(line);
        });

    process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen(stderrLines.add);

    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );

    return SevenZipResult(
      success: exitCode == 0,
      exitCode: exitCode,
      output: stdoutLines.join('\n'),
      errors: stderrLines.join('\n'),
      resolvedOutputDir: outputDir,
    );
  }
}

class ArchiveFormat {
  final String extension;
  final String label;

  const ArchiveFormat({required this.extension, required this.label});
}

class SevenZipResult {
  final bool success;
  final int exitCode;
  final String output;
  final String errors;
  final String resolvedOutputDir;

  const SevenZipResult({
    required this.success,
    required this.exitCode,
    required this.output,
    required this.errors,
    required this.resolvedOutputDir,
  });

  bool get wrongPassword {
    final combined = '${output.toLowerCase()} ${errors.toLowerCase()}';
    return !success &&
        (combined.contains('wrong password') ||
            combined.contains('cannot open encrypted') ||
            combined.contains('encrypted archive') ||
            combined.contains('password'));
  }
}
