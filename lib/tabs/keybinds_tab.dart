import 'dart:io';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/force_read_as_utf8.dart';
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
        await safeWriteIni(iniFile, lines.join('\n'));
        if (watchedPath != null) {
          DynamicDirectoryWatcher.watch(watchedPath);
        }
      }
    } catch (e) {}
  }
}

class KeyData {
  String key;
  int lineIndex;
  bool isMainKey;
  KeyData({
    required this.key,
    required this.lineIndex,
    required this.isMainKey,
  });
}

class KeybindData {
  String section;
  List<KeyData> key;
  IniFileAsLines iniFileAsLines;
  int sectionLineIndex;
  KeybindData({
    required this.section,
    required this.key,
    required this.iniFileAsLines,
    required this.sectionLineIndex,
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
  List<KeybindData> keys = [];
  final Map<KeybindData, GlobalKey<_KeyCardState>> childKeys = {};

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
          lines = await forceReadAsLinesUtf8(File(filePath));
        } catch (e) {}
        return IniFileAsLines(lines: lines, iniFile: File(filePath));
      }).toList(),
    );

    setState(() {
      iniFilesAsLines = data;
    });

    List<KeybindData> resultKeys = [];

    final keySectionRegExp = RegExp(
      r'^\s*\[Key([^\]\r\n]*)',
      caseSensitive: false,
    );

    final keyValueRegExp = RegExp(r'^\s*key\s*=\s*(.+)', caseSensitive: false);
    final backValueRegExp = RegExp(
      r'^\s*back\s*=\s*(.+)',
      caseSensitive: false,
    );

    for (var ini in iniFilesAsLines) {
      String? currentSection;
      int? sectionLineIndex;
      List<KeyData>? currentKeys;

      for (int i = 0; i < ini.lines.length; i++) {
        final line = ini.lines[i];

        final sectionMatch = keySectionRegExp.firstMatch(line);
        if (sectionMatch != null) {
          //to get previous key
          if (currentKeys != null && currentKeys.isNotEmpty) {
            if (currentSection != null && sectionLineIndex != null) {
              resultKeys.add(
                KeybindData(
                  section: currentSection,
                  key: currentKeys,
                  iniFileAsLines: ini,
                  sectionLineIndex: sectionLineIndex,
                ),
              );
            }
          }
          //
          currentSection = sectionMatch.group(1);
          sectionLineIndex = i;
          currentKeys = [];
          continue;
        }

        final keyMatch = keyValueRegExp.firstMatch(line);
        if (keyMatch != null &&
            currentSection != null &&
            sectionLineIndex != null &&
            currentKeys != null) {
          final keyValue = keyMatch.group(1)!.trim();
          currentKeys.add(
            KeyData(key: keyValue, lineIndex: i, isMainKey: true),
          );
        }

        final backMatch = backValueRegExp.firstMatch(line);
        if (backMatch != null &&
            currentSection != null &&
            sectionLineIndex != null &&
            currentKeys != null) {
          final keyValue = backMatch.group(1)!.trim();
          currentKeys.add(
            KeyData(key: keyValue, lineIndex: i, isMainKey: false),
          );
        }
      }

      // to get the last key
      if (currentKeys != null && currentKeys.isNotEmpty) {
        if (currentSection != null && sectionLineIndex != null) {
          resultKeys.add(
            KeybindData(
              section: currentSection,
              key: currentKeys,
              iniFileAsLines: ini,
              sectionLineIndex: sectionLineIndex,
            ),
          );
        }
      }
      //
    }

    setState(() {
      keys = resultKeys;
    });

    for (var key in keys) {
      childKeys[key] = GlobalKey<_KeyCardState>();
    }
  }

  Future<void> saveKeys() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      List<String> lowerCasedSections = [];
      for (var key in childKeys.values) {
        if (key.currentState != null) {
          lowerCasedSections.add(
            key.currentState!.updateKeybindAndGetSectionNameLowerCased(),
          );
        }
      }
      //Check for duplicate sections
      if (lowerCasedSections.length == lowerCasedSections.toSet().length) {
        for (var iniFileAsline in iniFilesAsLines) {
          await iniFileAsline.saveKeybind();
        }
        simulateKeyF10();
        setState(() {
          isEditing = false;
        });
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2B2930),
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            closeIconColor: Colors.blue,
            showCloseIcon: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Text(
              'Each section name must be unique (case-insensitive), cannot save.'
                  .tr(),
              style: GoogleFonts.poppins(
                color: Colors.yellow,
                fontSize: 13 * ref.read(zoomScaleProvider),
              ),
            ),
            dismissDirection: DismissDirection.down,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    if (modData != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 85 * sss),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  "$groupName - ${modData!.modName}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * sss,
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                top: 115 * sss,
                right: 45 * sss,
                left: 45 * sss,
                bottom: 40 * sss,
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
                child: RightClickMenuRegion(
                  menuItems: [
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        triggerRefresh(ref);
                      },
                      label: 'Refresh'.tr(),
                    ),
                    ref.watch(windowIsPinnedProvider)
                        ? CustomMenuItem(
                          scale: sss,
                          onSelected:
                              () =>
                                  ref
                                      .read(windowIsPinnedProvider.notifier)
                                      .state = false,
                          label: 'Unpin window'.tr(),
                        )
                        : CustomMenuItem(
                          scale: sss,
                          onSelected:
                              () =>
                                  ref
                                      .read(windowIsPinnedProvider.notifier)
                                      .state = true,
                          label: 'Pin window'.tr(),
                        ),
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        ref.read(targetGameProvider.notifier).state =
                            TargetGame.none;
                        await windowManager.hide();
                        DynamicDirectoryWatcher.stop();
                      },
                      label: 'Hide window'.tr(),
                    ),
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        try {
                          if (!await launchUrl(
                            Uri.parse(ConstantVar.urlValidKeysExample),
                          )) {}
                        } catch (e) {}
                      },
                      label: 'Valid keys'.tr(),
                    ),
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        try {
                          if (!await launchUrl(
                            Uri.parse(ref.read(tutorialLinkProvider)),
                          )) {}
                        } catch (e) {}
                      },
                      label: 'Tutorial'.tr(),
                    ),
                  ],
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 9 * sss,
                      runSpacing: 9 * sss,
                      children:
                          keys.map((keyData) {
                            return _KeyCard(
                              key: childKeys[keyData],
                              sectionName: keyData.section,
                              keybindKey: keyData.key,
                              iniFileAsLines: keyData.iniFileAsLines,
                              sectionLineIndex: keyData.sectionLineIndex,
                              isEditing: isEditing,
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 5 * sss),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scale: sss,
                  child: TextButton(
                    onPressed: () {
                      if (isEditing) {
                        saveKeys();
                      } else {
                        setState(() {
                          isEditing = true;
                        });
                      }
                    },
                    child: Text(
                      isEditing ? "Save Keybinds".tr() : "Edit Keybinds".tr(),
                      style: GoogleFonts.poppins(
                        color: Colors.blue,
                        fontSize: 13,
                      ),
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
        padding: EdgeInsets.only(
          top: 85 * sss,
          right: 49 * sss,
          left: 49 * sss,
          bottom: 30 * sss,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            'Right-click a mod and select Keybind.'.tr(),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12 * sss,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
  }
}

class _KeyCard extends ConsumerStatefulWidget {
  final String sectionName;
  final List<KeyData> keybindKey;
  final IniFileAsLines iniFileAsLines;
  final int sectionLineIndex;
  final bool isEditing;

  const _KeyCard({
    super.key,
    required this.sectionName,
    required this.keybindKey,
    required this.iniFileAsLines,
    required this.sectionLineIndex,
    required this.isEditing,
  });

  @override
  ConsumerState<_KeyCard> createState() => _KeyCardState();
}

class _KeyCardState extends ConsumerState<_KeyCard> {
  final textSectionController = TextEditingController();
  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    textSectionController.text = widget.sectionName;
    controllers =
        widget.keybindKey
            .map((keybind) => TextEditingController(text: keybind.key))
            .toList();
  }

  @override
  void dispose() {
    textSectionController.dispose();
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String updateKeybindAndGetSectionNameLowerCased() {
    //sectionName
    widget.iniFileAsLines.lines[widget.sectionLineIndex] =
        "[Key${textSectionController.text}]";

    //keys
    for (var index = 0; index < controllers.length; index++) {
      widget.iniFileAsLines.lines[widget.keybindKey[index].lineIndex] =
          widget.keybindKey[index].isMainKey
              ? "key = ${controllers[index].text}"
              : "back = ${controllers[index].text}";
    }
    return textSectionController.text.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Container(
      constraints: BoxConstraints(minHeight: 66 * sss),
      padding: EdgeInsets.symmetric(horizontal: 16 * sss, vertical: 7 * sss),
      decoration: BoxDecoration(
        color: const Color.fromARGB(100, 0, 0, 0),
        borderRadius: BorderRadius.circular(15 * sss),
        border: Border.all(
          color: const Color.fromARGB(127, 255, 255, 255),
          width: 3 * sss,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: IntrinsicHeight(
              child: TextField(
                controller: textSectionController,
                enabled: widget.isEditing,
                decoration: InputDecoration(
                  isDense: true,
                  disabledBorder: InputBorder.none,
                ),
                maxLines: null,
                keyboardType: TextInputType.none,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13 * sss,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp(r'[\n\r\u0085\u2028\u2029]'),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 4 * sss),

          SizedBox(height: 4 * sss),
          Column(
            children: List.generate(controllers.length, (index) {
              return IntrinsicWidth(
                child: IntrinsicHeight(
                  child: TextField(
                    controller: controllers[index],
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
                      fontSize: 13 * sss,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(
                        RegExp(r'[\n\r\u0085\u2028\u2029]'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

//TODO: FIX Text don't saved/tap outside not triggered when tap on another textfield
