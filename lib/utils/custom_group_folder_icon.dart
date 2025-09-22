import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
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

//UI DIALOG
class GenerateGroupIcoFileDialog extends ConsumerStatefulWidget {
  final String validModsPath;
  const GenerateGroupIcoFileDialog({super.key, required this.validModsPath});

  @override
  ConsumerState<GenerateGroupIcoFileDialog> createState() =>
      _GenerateGroupIcoFileDialogState();
}

class _GenerateGroupIcoFileDialogState
    extends ConsumerState<GenerateGroupIcoFileDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showConfirm = true;
  bool _isLoading = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    showWarning();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void showWarning() {
    setState(() {
      contents = [
        TextSpan(
          text: "Generate ico files for all group folders?".tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ];
    });
  }

  Future<void> generateIcons() async {
    setState(() {
      _showConfirm = false;
      _isLoading = true;
    });

    final String managedPath = p.join(
      widget.validModsPath,
      ConstantVar.managedFolderName,
    );

    setState(() {
      contents = [];
    });

    final modGroups = await getGroupFolders(managedPath);

    for (var group in modGroups) {
      setState(() {
        contents = [
          ...contents,
          TextSpan(
            text: "Generating folder icon".tr(
              args: [p.basename(group.$1.path)],
            ),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ];
      });

      await setFolderIcon(group.$1.path, p.join(group.$1.path, 'icon.png'));

      setState(() {
        final newContents = List<TextSpan>.from(contents);
        newContents.removeLast();
        newContents.add(
          TextSpan(
            text: "Generated folder icon".tr(args: [p.basename(group.$1.path)]),
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          ),
        );
        contents = newContents;
      });
      _scrollToBottom();
    }

    setState(() {
      _isLoading = false;
      contents = [
        ...contents,
        TextSpan(
          text: "Task completed!".tr(),
          style: GoogleFonts.poppins(
            color: Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    });
  }

  Future<void> _scrollToBottom() async {
    // Wait until scrollController has a valid position
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_scrollController.hasClients) return;

    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        "Generate Group Folder Icon".tr(),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: RichText(text: TextSpan(children: contents)),
          ),
        ),
      ),
      actions:
          _showConfirm
              ? [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = false;
                  },
                  child: Text(
                    'Cancel'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await generateIcons();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ]
              : _isLoading
              ? []
              : [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = false;
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
    );
  }
}
