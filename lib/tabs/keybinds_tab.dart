import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:window_manager/window_manager.dart';

class KeybindKeyData {
  String sectionName;
  String key;
  File iniFile;
  KeybindKeyData({
    required this.sectionName,
    required this.key,
    required this.iniFile,
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
  List<KeybindKeyData> keys = [];

  //   List<Map<String, String>> keys = const [
  //   {'title': 'Key Weapon', 'subtitle': 'no_shift no_return A'},
  //   {'title': 'Key Something', 'subtitle': 'no_shift no_alt no_control A'},
  //   {'title': 'Key Something Long Very Text', 'subtitle': 'no_control A'},
  //   {'title': 'Key Weapon', 'subtitle': 'no_shift A'},
  //   {'title': 'Key Weapon', 'subtitle': 'no_shift A'},
  //   {'title': 'Key Weapon', 'subtitle': 'no_shift A'},
  //   {
  //     'title': 'Key Weapon',
  //     'subtitle': 'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  //   },
  //   {
  //     'title': 'Key Weapon',
  //     'subtitle': 'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  //   },
  //   {
  //     'title': 'Key Weapon',
  //     'subtitle': 'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  //   },
  //   {
  //     'title': 'Key Weapon',
  //     'subtitle':
  //         'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  //   },
  // ];

  @override
  void initState() {
    super.initState();
    ref.listenManual(tabIndexProvider, (previous, next) {
      setModDir(next);
    });
  }

  Future<void> setModDir(int tabIndex) async {
    if (tabIndex == 0) {
      if (ref.read(modKeybind) != null) {
        if (await ref.read(modKeybind)!.$1.modDir.exists()) {
          setState(() {
            modData = ref.read(modKeybind)!.$1;
            groupName = ref.read(modKeybind)!.$2;
          });
          loadKeys();
        } else {
          setState(() {
            modData = null;
          });
        }
      }
    }
  }

  void loadKeys() {
    final iniFiles = findIniFilesRecursiveExcludeDisabled(modData!.modDir.path);
  }

  @override
  Widget build(BuildContext context) {
    if (modData != null) {
      return Padding(
        padding: const EdgeInsets.only(
          top: 85,
          right: 49,
          left: 49,
          bottom: 30,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Stack(
            children: [
              Align(
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
              Padding(
                padding: const EdgeInsets.only(top: 30),
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
                      ref.watch(windowIsPinnedProvider)
                          ? PopupMenuItem(
                            height: 37,
                            onTap:
                                () =>
                                    ref
                                        .watch(windowIsPinnedProvider.notifier)
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
                                        .watch(windowIsPinnedProvider.notifier)
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
                    ],
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children:
                            keys.map((keyData) {
                              return _KeyCard(
                                sectionName: keyData.sectionName,
                                keybindKey: keyData.key,
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            'Select a mod and go to Keybind tab',
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

  const _KeyCard({required this.sectionName, required this.keybindKey});

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
          TextField(
            controller: textController,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w400,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
