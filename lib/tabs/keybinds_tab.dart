import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart' as w;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/force_read_as_utf8.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
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
    } catch (_) {}
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
  bool isDisabled;
  KeybindData({
    required this.section,
    required this.key,
    required this.iniFileAsLines,
    required this.sectionLineIndex,
    required this.isDisabled,
  });
}

class TabKeybinds extends ConsumerStatefulWidget {
  const TabKeybinds({super.key});

  @override
  ConsumerState<TabKeybinds> createState() => _TabKeybindsState();
}

class _TabKeybindsState extends ConsumerState<TabKeybinds> with WindowListener {
  ModData? modData;
  String groupName = "";
  bool isEditing = false;

  List<IniFileAsLines> iniFilesAsLines = [];
  List<KeybindData> keys = [];

  List<String> editSectionNames = [];
  List<bool> disabledKeys = [];
  List<List<String>> editKeyValues = [];

  List<List<int>> _rows = [];
  double _lastComputedWidth = 0;
  double _lastComputedSss = 0;

  bool _rowsComputePending = false;
  int _rowComputeGeneration = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    ref.listenManual(tabIndexProvider, (previous, next) async {
      await setModDir();
    });

    ref.listenManual(targetGameProvider, (previous, next) async {
      await setModDir();
    });
  }

  bool recalculate = true;
  @override
  void onWindowResize() {
    _rowComputeGeneration++;
    setState(() {
      recalculate = false;
      _rowsComputePending = false;
    });
    super.onWindowResize();
  }

  @override
  void onWindowResized() {
    setState(() {
      recalculate = true;
    });
    super.onWindowResized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> setModDir() async {
    int tabIndex = ref.read(tabIndexProvider);
    if (tabIndex == 0) {
      _rowComputeGeneration++;
      setState(() {
        modData = null;
        groupName = "";
        isEditing = false;
        iniFilesAsLines = [];
        keys = [];
        editSectionNames = [];
        disabledKeys = [];
        editKeyValues = [];
        _rows = [];
        _lastComputedWidth = 0;
        _lastComputedSss = 0;
        _rowsComputePending = false;
      });

      if (mounted) {
        final modKeybind = ref.read(modKeybindProvider);
        if (modKeybind != null) {
          final exist =
              modKeybind.$5
                  ? await File(modKeybind.$1.modPath).exists()
                  : await Directory(modKeybind.$1.modPath).exists();
          if (exist && modKeybind.$3 == ref.read(targetGameProvider)) {
            setState(() {
              modData = modKeybind.$1;
              groupName = modKeybind.$2;
            });
            await loadKeys(modKeybind.$5);
            return;
          }
        }
      }
    }

    setState(() {
      modData = null;
    });
  }

  Future<void> loadKeys(bool isIniFile) async {
    if (!mounted || modData == null) return;

    final iniFiles =
        isIniFile
            ? [modData!.modPath]
            : await findIniFilesRecursiveExcludeDisabled(modData!.modPath);

    final data = await Future.wait(
      iniFiles.map((filePath) async {
        List<String> lines = [];
        try {
          lines = await forceReadAsLinesUtf8(File(filePath));
        } catch (_) {}
        return IniFileAsLines(lines: lines, iniFile: File(filePath));
      }).toList(),
    );

    if (!mounted) return;

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

    int totalLinesProcessed = 0;
    for (var ini in data) {
      String? currentSection;
      int? sectionLineIndex;
      List<KeyData>? currentKeys;

      bool? currentSectionIsDisabled;

      for (int i = 0; i < ini.lines.length; i++) {
        final line = ini.lines[i];
        final effectiveLine = line.startsWith(';+;') ? line.substring(3) : line;

        final sectionMatch = keySectionRegExp.firstMatch(effectiveLine);
        if (sectionMatch != null) {
          if (currentKeys != null && currentKeys.isNotEmpty) {
            if (currentSection != null && sectionLineIndex != null) {
              resultKeys.add(
                KeybindData(
                  section: currentSection,
                  key: currentKeys,
                  iniFileAsLines: ini,
                  sectionLineIndex: sectionLineIndex,
                  isDisabled: currentSectionIsDisabled ?? false,
                ),
              );
            }
          }
          currentSection = sectionMatch.group(1);
          sectionLineIndex = i;
          currentSectionIsDisabled = line != effectiveLine;
          currentKeys = [];
          continue;
        }

        final keyMatch = keyValueRegExp.firstMatch(effectiveLine);
        if (keyMatch != null &&
            currentSection != null &&
            sectionLineIndex != null &&
            currentKeys != null) {
          final keyValue = keyMatch.group(1)!.trim();
          currentKeys.add(
            KeyData(key: keyValue, lineIndex: i, isMainKey: true),
          );
        }

        final backMatch = backValueRegExp.firstMatch(effectiveLine);
        if (backMatch != null &&
            currentSection != null &&
            sectionLineIndex != null &&
            currentKeys != null) {
          final keyValue = backMatch.group(1)!.trim();
          currentKeys.add(
            KeyData(key: keyValue, lineIndex: i, isMainKey: false),
          );
        }

        totalLinesProcessed++;
        if (totalLinesProcessed % 500 == 0) {
          await Future.delayed(Duration.zero);
          if (!mounted) return;
        }
      }

      if (currentKeys != null && currentKeys.isNotEmpty) {
        if (currentSection != null && sectionLineIndex != null) {
          resultKeys.add(
            KeybindData(
              section: currentSection,
              key: currentKeys,
              iniFileAsLines: ini,
              sectionLineIndex: sectionLineIndex,
              isDisabled: currentSectionIsDisabled ?? false,
            ),
          );
        }
      }
    }

    if (!mounted) return;

    setState(() {
      iniFilesAsLines = data;
      keys = resultKeys;
      editSectionNames = resultKeys.map((k) => k.section).toList();
      disabledKeys = resultKeys.map((k) => k.isDisabled).toList();
      editKeyValues =
          resultKeys.map((k) => k.key.map((kd) => kd.key).toList()).toList();
      _rows = [];
      _lastComputedWidth = 0;
      _lastComputedSss = 0;
      _rowsComputePending = false;
    });

    for (final ini in iniFilesAsLines) {
      ini.lines = const [];
    }
  }

  static const int _kRowChunk = 15;

  Future<void> _recomputeRowsAsync(double availableWidth, double sss) async {
    final myGeneration = ++_rowComputeGeneration;
    final spacing = 9.0 * sss;
    final List<double> widths = [];

    final boldStyle = GoogleFonts.poppins(
      fontSize: 13 * sss,
      fontWeight: FontWeight.bold,
    );
    final normalStyle = GoogleFonts.poppins(
      fontSize: 13 * sss,
      fontWeight: FontWeight.w400,
    );

    for (int i = 0; i < keys.length; i++) {
      if (myGeneration != _rowComputeGeneration) return;

      double maxW = 0;

      final sectionP = TextPainter(
        text: TextSpan(text: editSectionNames[i], style: boldStyle),
        textDirection: w.TextDirection.ltr,
      )..layout();
      maxW = sectionP.width;
      sectionP.dispose();

      for (final val in editKeyValues[i]) {
        final keyP = TextPainter(
          text: TextSpan(text: val, style: normalStyle),
          textDirection: w.TextDirection.ltr,
        )..layout();
        if (keyP.width > maxW) maxW = keyP.width;
        keyP.dispose();
      }

      widths.add(maxW + 32.0 * sss + 28.0);

      if ((i + 1) % _kRowChunk == 0 || i == keys.length - 1) {
        final rows = _packRows(widths, availableWidth, spacing);
        if (!mounted || myGeneration != _rowComputeGeneration) return;
        setState(() => _rows = rows);
        await Future.delayed(Duration.zero);
      }
    }

    if (!mounted || myGeneration != _rowComputeGeneration) return;
    setState(() {
      _lastComputedWidth = availableWidth;
      _lastComputedSss = sss;
      _rowsComputePending = false;
    });
  }

  static List<List<int>> _packRows(
    List<double> widths,
    double availableWidth,
    double spacing,
  ) {
    final rows = <List<int>>[];
    var row = <int>[];
    var rowW = 0.0;
    for (var i = 0; i < widths.length; i++) {
      final needed = row.isEmpty ? widths[i] : rowW + spacing + widths[i];
      if (row.isNotEmpty && needed > availableWidth) {
        rows.add(row);
        row = [i];
        rowW = widths[i];
      } else {
        row.add(i);
        rowW = needed;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  String _getNamespaceLowercase(List<String> lines, String path) {
    String namespace = path;
    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.startsWith(';')) continue;
      if (trimmedLine
          .toLowerCase()
          .replaceAll(' ', '')
          .startsWith('namespace=')) {
        namespace = trimmedLine.substring(trimmedLine.indexOf('=') + 1).trim();
        break;
      }
      if (trimmedLine.startsWith("[")) {
        break;
      }
    }

    return namespace.toLowerCase();
  }

  Future<void> saveKeys({
    bool disableAll = false,
    bool enableAll = false,
  }) async {
    if (disableAll) {
      final disableKeys = List<bool>.filled(disabledKeys.length, true);
      setState(() {
        disabledKeys = disableKeys;
      });
    } else if (enableAll) {
      final enableKeys = List<bool>.filled(disabledKeys.length, false);
      setState(() {
        disabledKeys = enableKeys;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait(
        iniFilesAsLines.map((ini) async {
          try {
            ini.lines = await forceReadAsLinesUtf8(ini.iniFile);
          } catch (_) {
            ini.lines = [];
          }
        }).toList(),
      );

      List<String> lowerCasedSections = [];
      Map<String, String> pathToNamespaceMap = {};

      for (var i = 0; i < keys.length; i++) {
        final keybindData = keys[i];

        keybindData.iniFileAsLines.lines[keybindData.sectionLineIndex] =
            disabledKeys[i]
                ? ";+;[Key${editSectionNames[i]}]"
                : "[Key${editSectionNames[i]}]";

        for (var ki = 0; ki < keybindData.key.length; ki++) {
          final keyData = keybindData.key[ki];
          keybindData.iniFileAsLines.lines[keyData.lineIndex] =
              keyData.isMainKey
                  ? disabledKeys[i]
                      ? ";+;key = ${editKeyValues[i][ki]}"
                      : "key = ${editKeyValues[i][ki]}"
                  : disabledKeys[i]
                  ? ";+;back = ${editKeyValues[i][ki]}"
                  : "back = ${editKeyValues[i][ki]}";
        }

        final keyLineIndices = keybindData.key.map((k) => k.lineIndex).toSet();
        int sectionEnd = keybindData.iniFileAsLines.lines.length;
        for (int j = keybindData.sectionLineIndex + 1; j < sectionEnd; j++) {
          final l = keybindData.iniFileAsLines.lines[j];
          final effective = l.startsWith(';+;') ? l.substring(3) : l;
          if (effective.trimLeft().startsWith('[')) {
            sectionEnd = j;
            break;
          }
        }
        for (int j = keybindData.sectionLineIndex + 1; j < sectionEnd; j++) {
          if (keyLineIndices.contains(j)) continue;
          final raw = keybindData.iniFileAsLines.lines[j];
          keybindData.iniFileAsLines.lines[j] =
              disabledKeys[i]
                  ? (raw.startsWith(';+;') ? raw : ';+;$raw')
                  : (raw.startsWith(';+;') ? raw.substring(3) : raw);
        }

        if (!pathToNamespaceMap.containsKey(
          keybindData.iniFileAsLines.iniFile.path,
        )) {
          pathToNamespaceMap[keybindData
              .iniFileAsLines
              .iniFile
              .path] = _getNamespaceLowercase(
            keybindData.iniFileAsLines.lines,
            keybindData.iniFileAsLines.iniFile.path,
          );
        }

        lowerCasedSections.add(
          "${editSectionNames[i].toLowerCase()}${pathToNamespaceMap[keybindData.iniFileAsLines.iniFile.path]}",
        );
      }

      for (var iniFileAsline in iniFilesAsLines) {
        await iniFileAsline.saveKeybind();
      }

      for (final ini in iniFilesAsLines) {
        ini.lines = const [];
      }

      setState(() {
        isEditing = false;
      });

      if (lowerCasedSections.length != lowerCasedSections.toSet().length) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2B2930),
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            closeIconColor: getAccentColor(ref),
            showCloseIcon: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Text(
              'Each section name must be unique (case-insensitive), to ensure all keys are working.'
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2B2930),
          margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          closeIconColor: getAccentColor(ref),
          showCloseIcon: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Text(
            "Don't forget to reload the mod with F10.".tr(),
            style: GoogleFonts.poppins(
              color: Colors.yellow,
              fontSize: 13 * ref.read(zoomScaleProvider),
            ),
          ),
          action: SnackBarAction(
            textColor: getAccentColor(ref),
            label: "Reload".tr(),
            onPressed: () async {
              await simulateKeyF10();
            },
          ),
          dismissDirection: DismissDirection.down,
        ),
      );
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
                child: Column(
                  children: [
                    Text(
                      groupName == "casual"
                          ? modData!.modName
                          : "$groupName - ${modData!.modName}",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14 * sss,
                      ),
                    ),
                    SizedBox(height: 5 * sss),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 25 * sss,
                          width: 35 * sss,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: Switch(
                              value: ref.watch(keybindSimulateKeypressProvider),
                              onChanged: (value) {
                                SharedPrefUtils().setKeybindSimulateKeypress(
                                  value,
                                );
                                ref
                                    .read(
                                      keybindSimulateKeypressProvider.notifier,
                                    )
                                    .state = value;
                              },
                              activeColor: getAccentColor(ref),
                              trackOutlineWidth: WidgetStatePropertyAll(0),
                              trackOutlineColor: WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        Container(width: 15 * sss),
                        Text(
                          'Click keybind to simulate keypress'.tr(),
                          style: GoogleFonts.poppins(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            fontSize: 12 * sss,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                top: 150 * sss,
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
                        clearImagesCache();
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
                        } catch (_) {}
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
                        } catch (_) {}
                      },
                      label: 'Tutorial'.tr(),
                    ),
                  ],
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final available = constraints.maxWidth - (45 * sss);
                      if (recalculate &&
                          !_rowsComputePending &&
                          ((_rows.isEmpty && keys.isNotEmpty) ||
                              _lastComputedWidth != available ||
                              _lastComputedSss != sss)) {
                        _rowsComputePending = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _recomputeRowsAsync(available, sss);
                        });
                      }
                      return ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (context, rowIndex) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 9 * sss),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  _rows[rowIndex].map((i) {
                                    return Padding(
                                      padding: EdgeInsets.only(right: 9 * sss),
                                      child: _KeyCard(
                                        key: ValueKey(i),
                                        sectionName: editSectionNames[i],
                                        isDisabled: disabledKeys[i],
                                        keyValues: editKeyValues[i],
                                        isEditing: isEditing,
                                        onSectionChanged:
                                            (val) => editSectionNames[i] = val,
                                        onKeyChanged:
                                            (ki, val) =>
                                                editKeyValues[i][ki] = val,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 5 * sss),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  alignment: Alignment.bottomCenter,
                  scale: sss,
                  child: w.Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () async {
                          if (isEditing) {
                            await saveKeys();
                          } else {
                            setState(() {
                              isEditing = true;
                            });
                          }
                        },
                        child: Text(
                          isEditing
                              ? "Save Keybinds".tr()
                              : "Edit Keybinds".tr(),
                          style: GoogleFonts.poppins(
                            color: getAccentColor(ref),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isEditing && disabledKeys.contains(true))
                        TextButton(
                          onPressed: () async {
                            await saveKeys(enableAll: true);
                          },
                          child: Text(
                            "Enable All Keybinds".tr(),
                            style: GoogleFonts.poppins(
                              color: getAccentColor(ref),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!isEditing && !disabledKeys.contains(true))
                        TextButton(
                          onPressed: () async {
                            await saveKeys(disableAll: true);
                          },
                          child: Text(
                            "Disable All Keybinds".tr(),
                            style: GoogleFonts.poppins(
                              color: getAccentColor(ref),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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
  final bool isDisabled;
  final List<String> keyValues;
  final bool isEditing;
  final void Function(String) onSectionChanged;
  final void Function(int, String) onKeyChanged;

  const _KeyCard({
    super.key,
    required this.sectionName,
    required this.isDisabled,
    required this.keyValues,
    required this.isEditing,
    required this.onSectionChanged,
    required this.onKeyChanged,
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
        widget.keyValues
            .map((val) => TextEditingController(text: val))
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

  Future<void> _simulateKey(int index, double sss) async {
    if (widget.isDisabled) return;
    bool success = false;
    final messenger = ScaffoldMessenger.of(context);

    try {
      success = await simulateKeysFromKeySections(controllers[index].text);
    } catch (_) {}

    if (!success) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2B2930),
          margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          closeIconColor: getAccentColor(ref),
          showCloseIcon: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Text(
            'Invalid keys'.tr(),
            style: GoogleFonts.poppins(
              color: Colors.yellow,
              fontSize: 13 * sss,
            ),
          ),
          dismissDirection: DismissDirection.down,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return ElevatedButton(
      onPressed:
          widget.isEditing || !ref.watch(keybindSimulateKeypressProvider)
              ? null
              : () async {
                if (controllers.length <= 1) {
                  await _simulateKey(0, sss);
                }
              },
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          const Color.fromARGB(100, 0, 0, 0),
        ),
        overlayColor: WidgetStatePropertyAll(
          controllers.length > 1
              ? Colors.transparent
              : widget.isDisabled
              ? const Color.fromARGB(43, 43, 43, 43)
              : getAccentColor(ref, alpha: 50),
        ),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(EdgeInsetsGeometry.zero),
        shape: WidgetStateOutlinedBorder.resolveWith((state) {
          return RoundedRectangleBorder(
            side: BorderSide(
              color:
                  widget.isDisabled
                      ? const Color.fromARGB(80, 244, 67, 54)
                      : state.contains(WidgetState.hovered)
                      ? getAccentColor(ref)
                      : const Color.fromARGB(127, 255, 255, 255),
              width: 3 * sss,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            borderRadius: BorderRadiusGeometry.all(Radius.circular(15 * sss)),
          );
        }),
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: 66 * sss),
        padding: EdgeInsets.symmetric(horizontal: 16 * sss, vertical: 7 * sss),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15 * sss),
          border: Border.all(
            color: Colors.transparent,
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
                  onChanged: widget.onSectionChanged,
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
                    child:
                        controllers.length > 1
                            ? TextButton(
                              onPressed:
                                  widget.isEditing ||
                                          !ref.watch(
                                            keybindSimulateKeypressProvider,
                                          )
                                      ? null
                                      : () async {
                                        await _simulateKey(index, sss);
                                      },
                              style: ButtonStyle(
                                backgroundColor: WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                                overlayColor: WidgetStatePropertyAll(
                                  widget.isDisabled
                                      ? const Color.fromARGB(43, 43, 43, 43)
                                      : getAccentColor(ref, alpha: 50),
                                ),
                                shadowColor: WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                              ),
                              child: TextField(
                                controller: controllers[index],
                                enabled: widget.isEditing,
                                onChanged:
                                    (val) => widget.onKeyChanged(index, val),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 15 * sss,
                                    horizontal: 10 * sss,
                                  ),
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
                            )
                            : TextField(
                              controller: controllers[index],
                              enabled: widget.isEditing,
                              onChanged:
                                  (val) => widget.onKeyChanged(index, val),
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
      ),
    );
  }
}
