import 'dart:io';

import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:process_run/process_run.dart';

String? _firstExisting(List<String> paths) {
  for (final path in paths) {
    if (!path.startsWith('null\\') && File(path).existsSync()) {
      return path;
    }
  }

  return null;
}

void findExternalCodeEditors() {
  final programFiles = Platform.environment['ProgramFiles'];
  final programFilesX86 = Platform.environment['ProgramFiles(x86)'];

  vsCodePath = whichSync('code');
  zedPath = whichSync('zed');
  notepadppPath = whichSync('notepad++');
  sublimeTextPath = whichSync('subl');

  notepadppPath ??= _firstExisting([
    if (programFiles != null) '$programFiles\\Notepad++\\notepad++.exe',
    if (programFilesX86 != null) '$programFilesX86\\Notepad++\\notepad++.exe',
  ]);

  sublimeTextPath ??= _firstExisting([
    if (programFiles != null) '$programFiles\\Sublime Text\\sublime_text.exe',
    if (programFilesX86 != null)
      '$programFilesX86\\Sublime Text\\sublime_text.exe',
  ]);
}

Future<void> openVsCodeToSpecifiedPath(String vsCodePath, String path) async {
  if (!Platform.isWindows) return;
  if (!await Directory(path).exists()) return;

  final environment = Map<String, String>.from(Platform.environment);
  environment.remove('ELECTRON_RUN_AS_NODE');

  await Process.start(
    vsCodePath,
    [path],
    environment: environment,
    includeParentEnvironment: false,
    mode: ProcessStartMode.detached,
  );
}

Future<void> openZedToSpecifiedPath(String zedPath, String path) async {
  if (!Platform.isWindows) return;
  if (!await Directory(path).exists()) return;

  await Process.start(zedPath, [
    '--classic',
    path,
  ], mode: ProcessStartMode.detached);
}

Future<void> openNotepadPlusPlusToSpecifiedPath(
  String notepadPlusPlusPath,
  String path,
) async {
  if (!Platform.isWindows) return;
  if (!await Directory(path).exists()) return;

  await Process.start(notepadPlusPlusPath, [
    '-multiInst',
    '-nosession',
    '-openFoldersAsWorkspace',
    path,
  ], mode: ProcessStartMode.detached);
}

Future<void> openSublimeTextToSpecifiedPath(
  String sublimeTextPath,
  String path,
) async {
  if (!Platform.isWindows) return;
  if (!await Directory(path).exists()) return;

  await Process.start(sublimeTextPath, [path], mode: ProcessStartMode.detached);
}

Future<void> openKateToSpecifiedPath(String katePath, String path) async {
  if (!Platform.isWindows) return;
  if (!await Directory(path).exists()) return;

  await Process.start(katePath, [path], mode: ProcessStartMode.detached);
}
