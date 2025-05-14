import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

class IniFileAsLines {
  List<String> lines;
  File iniFile;

  IniFileAsLines({required this.lines, required this.iniFile});

  Future<void> saveKeybind() async {
    try {
      if (await iniFile.exists()) {
        String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
        DynamicDirectoryWatcher.stop();
        await iniFile.writeAsString(lines.join('\n'));
        if (watchedPath != null) {
          DynamicDirectoryWatcher.watch(watchedPath);
        }
      }
    } catch (e) {}
  }
}

class KeybindKeyData {
  String section;
  String key;
  IniFileAsLines iniFileAsLines;
  int keyLineIndex;
  KeybindKeyData({
    required this.section,
    required this.key,
    required this.iniFileAsLines,
    required this.keyLineIndex,
  });
}

class TabKeybinds extends ConsumerStatefulWidget {
  const TabKeybinds({super.key});

  @override
  ConsumerState<TabKeybinds> createState() => _TabKeybindsState();
}

class _TabKeybindsState extends ConsumerState<TabKeybinds> {
  ModData? modData;
  String groupName = "";
  bool isEditing = false;

  List<IniFileAsLines> iniFilesAsLines = [];
  List<KeybindKeyData> keys = [];

  @override
  void initState() {
    super.initState();

    //When going to Keybind
    ref.listenManual(tabIndexProvider, (previous, next) async {
      await setModDir();
    });

    //In case auto refresh was triggered
    ref.listenManual(targetGameProvider, (previous, next) async {
      if (next != TargetGame.none) {
        await setModDir();
      }
    });
  }

  Future<void> setModDir() async {
    int tabIndex = ref.read(tabIndexProvider);
    if (tabIndex == 0) {
      //RESET
      setState(() {
        modData = null;
        groupName = "";
        isEditing = false;
        iniFilesAsLines = [];
        keys = [];
      });

      //Sometimes widget don't rebuild/don't show loading screen because loading time was too fast
      await Future.delayed(Duration(milliseconds: 10));

      if (ref.read(modKeybindProvider) != null) {
        if (await ref.read(modKeybindProvider)!.$1.modDir.exists() &&
            ref.read(modKeybindProvider)!.$3 == ref.read(targetGameProvider)) {
          setState(() {
            modData = ref.read(modKeybindProvider)!.$1;
            groupName = ref.read(modKeybindProvider)!.$2;
          });
          await loadKeys();
        } else {
          setState(() {
            modData = null;
          });
        }
      }
    }
  }

  Future<void> loadKeys() async {
    final iniFiles = await findIniFilesRecursiveExcludeDisabled(
      modData!.modDir.path,
    );

    final data = await Future.wait(
      iniFiles.map((filePath) async {
        List<String> lines = [];
        try {
          lines = await File(filePath).readAsLines();
        } catch (e) {}
        return IniFileAsLines(lines: lines, iniFile: File(filePath));
      }).toList(),
    );

    setState(() {
      iniFilesAsLines = data;
    });

    List<KeybindKeyData> resultKeys = [];

    final keySectionRegExp = RegExp(
      r'^\s*\[(Key[^\]\r\n]*)',
      caseSensitive: false,
    );

    final keyValueRegExp = RegExp(r'^\s*key\s*=\s*(.+)', caseSensitive: false);

    for (var ini in iniFilesAsLines) {
      String? currentSection;

      for (int i = 0; i < ini.lines.length; i++) {
        final line = ini.lines[i];

        final sectionMatch = keySectionRegExp.firstMatch(line);
        if (sectionMatch != null) {
          currentSection = sectionMatch.group(1);
          continue;
        }

        final keyMatch = keyValueRegExp.firstMatch(line);
        if (keyMatch != null && currentSection != null) {
          final keyValue = keyMatch.group(1)!.trim();
          resultKeys.add(
            KeybindKeyData(
              section: currentSection,
              key: keyValue,
              iniFileAsLines: ini,
              keyLineIndex: i,
            ),
          );
        }
      }
    }

    setState(() {
      keys = resultKeys;
    });
  }

  Future<void> saveKeys() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var iniFileAsline in iniFilesAsLines) {
        await iniFileAsline.saveKeybind();
      }
      simulateKeyF10();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (modData != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 85),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  "$groupName - ${modData!.modName}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(
                top: 115,
                right: 49,
                left: 49,
                bottom: 40,
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                  scrollbars: false,
                ),
                child: RightClickMenuWrapper(
                  menuItems: [
                    PopupMenuItem(
                      height: 37,
                      onTap: () async {
                        triggerRefresh(ref);
                      },
                      value: 'Refresh',
                      child: Text(
                        'Refresh',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ref.watch(windowIsPinnedProvider)
                        ? PopupMenuItem(
                          height: 37,
                          onTap:
                              () =>
                                  ref
                                      .read(windowIsPinnedProvider.notifier)
                                      .state = false,
                          value: 'Unpin window',
                          child: Text(
                            'Unpin window',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        )
                        : PopupMenuItem(
                          height: 37,
                          onTap:
                              () =>
                                  ref
                                      .read(windowIsPinnedProvider.notifier)
                                      .state = true,
                          value: 'Pin window',
                          child: Text(
                            'Pin window',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    PopupMenuItem(
                      height: 37,
                      onTap: () async {
                        ref.read(targetGameProvider.notifier).state =
                            TargetGame.none;
                        await windowManager.hide();
                        DynamicDirectoryWatcher.stop();
                      },
                      value: 'Hide window',
                      child: Text(
                        'Hide window',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      height: 37,
                      onTap: () async {
                        try {
                          if (!await launchUrl(
                            Uri.parse(ConstantVar.urlValidKeysExample),
                          )) {}
                        } catch (e) {}
                      },
                      value: 'Valid keys',
                      child: Text(
                        'Valid keys',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      height: 37,
                      onTap: () async {
                        try {
                          if (!await launchUrl(
                            Uri.parse(ref.read(tutorialLinkProvider)),
                          )) {}
                        } catch (e) {}
                      },
                      value: 'Tutorial',
                      child: Text(
                        'Tutorial',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children:
                          keys.map((keyData) {
                            return _KeyCard(
                              sectionName: keyData.section,
                              keybindKey: keyData.key,
                              iniFileAsLines: keyData.iniFileAsLines,
                              keyLineIndex: keyData.keyLineIndex,
                              isEditing: isEditing,
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  onPressed: () {
                    if (isEditing) {
                      saveKeys();
                      setState(() {
                        isEditing = false;
                      });
                    } else {
                      setState(() {
                        isEditing = true;
                      });
                    }
                  },
                  child: Text(
                    isEditing ? "Save Keybinds" : "Edit Keybinds",
                    style: GoogleFonts.poppins(
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(
          top: 85,
          right: 49,
          left: 49,
          bottom: 30,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            'Right-click a mod and select Keybind.\nOr just press R(keyboard) X(gamepad) on a mod.',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
  }
}

class _KeyCard extends StatefulWidget {
  final String sectionName;
  final String keybindKey;
  final IniFileAsLines iniFileAsLines;
  final int keyLineIndex;
  final bool isEditing;

  const _KeyCard({
    required this.sectionName,
    required this.keybindKey,
    required this.iniFileAsLines,
    required this.keyLineIndex,
    required this.isEditing,
  });

  @override
  State<_KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends State<_KeyCard> {
  final textController = TextEditingController();
  @override
  void initState() {
    super.initState();
    textController.text = widget.keybindKey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: const Color.fromARGB(100, 0, 0, 0),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color.fromARGB(127, 255, 255, 255),
          width: 3,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '[${widget.sectionName}]',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),

          const SizedBox(height: 4),
          IntrinsicWidth(
            child: IntrinsicHeight(
              child: TextField(
                onEditingComplete: () {
                  textController.text = textController.text.replaceAll(
                    '\n',
                    '',
                  );
                  widget.iniFileAsLines.lines[widget.keyLineIndex] =
                      "key = ${textController.text}";
                  FocusScope.of(context).unfocus();
                },
                onTapOutside: (v) {
                  textController.text = textController.text.replaceAll(
                    '\n',
                    '',
                  );
                  widget.iniFileAsLines.lines[widget.keyLineIndex] =
                      "key = ${textController.text}";
                  FocusScope.of(context).unfocus();
                },
                controller: textController,
                enabled: widget.isEditing,
                decoration: InputDecoration(
                  isDense: true,
                  disabledBorder: InputBorder.none,
                ),
                maxLines: null,
                keyboardType: TextInputType.none,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
