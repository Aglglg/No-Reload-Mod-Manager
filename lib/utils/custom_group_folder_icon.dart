import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

Future<void> _setAttributes(String path, int attributes) async {
  final lpFileName = path.toNativeUtf16();
  SetFileAttributes(lpFileName, attributes);
  calloc.free(lpFileName);
}

Future<void> unsetFolderIcon(String folderPath) async {
  if (!Platform.isWindows) return;
  final folder = Directory(folderPath).absolute;

  if (!await folder.exists()) return;
  //Remove attributes (ignore if fails)
  try {
    await _setAttributes(folder.path, FILE_ATTRIBUTE_NORMAL);
  } catch (_) {}
}

Future<void> setFolderIcon(String folderPath, String rawIconPath) async {
  if (!Platform.isWindows) return;
  final folder = Directory(folderPath).absolute;
  final rawIcon = File(rawIconPath).absolute;

  if (!await folder.exists() || !await rawIcon.exists()) return;

  final icoFilePath = await _convertToIco(rawIcon);

  if (icoFilePath == null) return;

  final desktopIniFile = File("${folder.path}\\desktop.ini");

  //Remove file/folder attributes metadata from previous set icon, if any
  try {
    await _setAttributes(folder.path, FILE_ATTRIBUTE_NORMAL);
    if (await desktopIniFile.exists()) {
      await _setAttributes(desktopIniFile.path, FILE_ATTRIBUTE_NORMAL);
    }
  } catch (_) {}

  //Write desktop.ini to change folder icon
  final content = "[.ShellClassInfo]\r\nIconResource=$icoFilePath,0\r\n";
  await desktopIniFile.writeAsString(content, flush: true);

  //Restore required attributes, system & read-only (doesn't really mean like that, means this folder can be customized)
  await _setAttributes(
    folder.path,
    FILE_ATTRIBUTE_SYSTEM | FILE_ATTRIBUTE_READONLY,
  );

  //Hidden is required for desktop ini file
  await _setAttributes(
    desktopIniFile.path,
    FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM,
  );

  await deletePreviousIcoFiles(folderPath, icoFilePath);
}

//// CONVERT TO ICO
///
///
// Worker function for encoding ICO inside isolate, avoid freezing ui
Future<Uint8List?> _encodeIcoInIsolate(List<dynamic> args) async {
  final Uint8List bytes = args[0];
  final int size = args[1];

  final imageObj = img.decodeImage(bytes);
  if (imageObj != null) {
    final resized = img.copyResize(imageObj, width: size, height: size);

    return Uint8List.fromList(img.encodeIco(resized, singleFrame: true));
  }
  return null;
}

// Convert to .ico, asynchronously
Future<String?> _convertToIco(File inputFile, {int size = 256}) async {
  String? icoFilePath;
  final inputBytes = await inputFile.readAsBytes();

  //do it without blocking main thread
  final icoBytes = await Isolate.run(
    () => _encodeIcoInIsolate([inputBytes, size]),
  );

  if (icoBytes != null) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final icoFile = await File(
      p.join(p.dirname(inputFile.path), 'icon_$timestamp.ico'),
    ).writeAsBytes(icoBytes, flush: true);
    icoFilePath = icoFile.path;
  }
  return icoFilePath;
}

Future<void> deletePreviousIcoFiles(
  String folderPath,
  String newIcoPath,
) async {
  final dir = Directory(folderPath);

  if (!await dir.exists()) return;

  await for (final entity in dir.list()) {
    if (entity is File && entity.path.toLowerCase().endsWith('.ico')) {
      try {
        if (entity.path == newIcoPath) continue; //do not delete new ico file
        await entity.delete();
      } catch (e) {}
    }
  }
}
