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

    final exeName = Platform.isWindows ? '7z.exe' : '7zz';
    _exePath = p.join(sevenZipDir.path, exeName);

    // Linux: make sure the file is allowed to run
    if (Platform.isLinux) {
      await Process.run('chmod', ['+x', _exePath!]);
    }
  }

  /// Linux: some Windows zips use "\" as folder separator, fix those names
  Future<void> _fixBackslashNames(String outputDir) async {
    final entities = await Directory(outputDir).list(recursive: true).toList();

    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (!name.contains(r'\')) continue;

      final fixedPath = p.join(
        p.dirname(entity.path),
        name.replaceAll(r'\', '/'),
      );

      if (entity is File) {
        await Directory(p.dirname(fixedPath)).create(recursive: true);
        await entity.rename(fixedPath);
      } else if (entity is Directory) {
        await entity.delete(); // leftover empty "something\" entry
      }
    }
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

      final output = '${result.stdout} ${result.stderr}'.toLowerCase();

      // Normal case: files are marked as encrypted
      // Header-encrypted case: the list itself fails with a password error
      return output.contains('encrypted = +') ||
          output.contains('wrong password') ||
          output.contains('cannot open encrypted archive');
    } catch (_) {
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

    if (exitCode == 0 && Platform.isLinux && archivePath.endsWith('.zip')) {
      await _fixBackslashNames(outputDir);
    }

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
