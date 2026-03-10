import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_troubleshoot.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:no_reload_mod_manager/utils/ui_dialogues.dart';

class ModsTroubleshootTab extends ConsumerStatefulWidget {
  const ModsTroubleshootTab({super.key});

  @override
  ConsumerState<ModsTroubleshootTab> createState() =>
      _ModsTroubleshootTabState();
}

class _ModsTroubleshootTabState extends ConsumerState<ModsTroubleshootTab> {
  int? expandedIndex;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentGame = ref.read(targetGameProvider);
      final troubleshootData = ref.read(troubleshootDataProvider);
      if (troubleshootData != null &&
          troubleshootData.targetGame != currentGame) {
        ref.read(troubleshootDataProvider.notifier).state = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Stack(
      children: [
        //Title & back button
        Padding(
          padding: EdgeInsetsGeometry.only(
            top: 70 * sss,
            right: 45 * sss,
            left: 30 * sss,
            bottom: 0 * sss,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  ref.read(modsSubTabIndexProvider.notifier).state = 1;
                },
                icon: Icon(Icons.chevron_left_rounded),
                iconSize: 24 * sss,
                style: IconButton.styleFrom(overlayColor: Colors.white),
              ),
              IgnorePointer(
                child: Text(
                  "Troubleshoot",
                  textAlign: TextAlign.start,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14 * sss,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        //Subtitle
        Padding(
          padding: EdgeInsetsGeometry.only(
            top: 107 * sss,
            right: 45 * sss,
            left: 45 * sss,
          ),
          child: IgnorePointer(
            child: Text(
              "Read carefully and it will eventually fix your problems",
              textAlign: TextAlign.start,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11.5 * sss,
              ),
            ),
          ),
        ),

        //Content
        TroubleshootContainer(),
      ],
    );
  }
}

class TroubleshootContainer extends ConsumerStatefulWidget {
  const TroubleshootContainer({super.key});

  @override
  ConsumerState<TroubleshootContainer> createState() =>
      _TroubleshootContainerState();
}

class _TroubleshootContainerState extends ConsumerState<TroubleshootContainer> {
  Widget mainCategoryHeader(String title, double sss) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * sss),
      child: Row(
        children: [
          SizedBox(width: 20 * sss),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14 * sss,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8 * sss),
          Expanded(
            child: Divider(
              color: const Color.fromARGB(127, 33, 149, 243),
              thickness: 1 * sss,
            ),
          ),
        ],
      ),
    );
  }

  Widget itemHeader(String title, String subtitle, double sss) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 15 * sss, horizontal: 20 * sss),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14 * sss,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> getVerifyXxmiVersionSectionChildren(double sss) {
    final troubleshootData = ref.watch(troubleshootDataProvider);
    if (troubleshootData == null) {
      return [
        Text(
          "Press Full Scan Mods first",
          textAlign: TextAlign.start,
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontSize: 12 * sss,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          "",
          textAlign: TextAlign.start,
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontSize: 5 * sss,
            fontWeight: FontWeight.w400,
          ),
        ),
      ];
    } else {
      return [
        Text(
          "XXMI Version: ${troubleshootData.xxmiDllVersion}",
          textAlign: TextAlign.start,
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontSize: 12 * sss,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (!troubleshootData.xxmiDllVersion.contains("NRMM")) ...[
          Text(
            "Latest Version: ${troubleshootData.latestXxmiDll}++\n",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "It is important to use latest XXMI DLL.",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "Except if the game really need older DLL.\n",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        if (troubleshootData.xxmiDllVersion.contains("NRMM"))
          Text(
            "Skip this if you use Custom XXMI DLL for NRMM, and check for the latest version on Github @Aglglg instead.\n",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
        if (!troubleshootData.xxmiDllVersion.contains("NRMM")) ...[
          Text(
            "To make sure you are using latest XXMI DLL:",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13 * sss,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "1. Open XXMI Launcher",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            "2. Go to Settings > Advanced",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            "3. Make sure Unsafe Mode is OFF (Default)",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "4. DO NOT TURN IT ON, KEEP IT OFF",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "5. Hover over the 3-dots icon next to the Start button and press Check for Updates",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            "6. Restart the game with XXMI Launcher",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            "7. You can ignore this if you are sure that this is the latest version",
            textAlign: TextAlign.start,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 12 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);

    return Padding(
      padding: EdgeInsets.only(
        top: 130 * sss,
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
        child: ListView(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 20 * sss, right: 25 * sss),
              child: Column(
                children: [
                  Container(height: 10 * sss),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (ref.read(validModsPath) == null) {
                              return;
                            }
                            ref
                                .read(troubleshootDataProvider.notifier)
                                .state = await fullScanMods(
                              ref.read(validModsPath)!,
                              ref.read(targetGameProvider),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            overlayColor: Colors.white,
                            backgroundColor: const Color.fromARGB(
                              127,
                              255,
                              255,
                              255,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12 * sss),
                            child: Text(
                              'Full Scan Mods'.tr(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12 * sss,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(height: 2 * sss),
                  Text(
                    "Last Scanned: ${ref.watch(troubleshootDataProvider) == null ? "--" : ref.watch(troubleshootDataProvider)!.time}"
                        .tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color.fromARGB(200, 255, 255, 255),
                      fontSize: 11 * sss,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(height: 10 * sss),
                ],
              ),
            ),
            ExpansionPanelList.radio(
              elevation: 0,
              dividerColor: Colors.transparent,
              expandedHeaderPadding: EdgeInsets.zero,
              animationDuration: const Duration(milliseconds: 250),
              materialGapSize: 0,
              children: [
                // Visual Glitches
                ExpansionPanelRadio(
                  value: 0,
                  headerBuilder:
                      (context, isExpanded) =>
                          mainCategoryHeader("Visual Glitches", sss),
                  backgroundColor: Colors.transparent,
                  canTapOnHeader: true,
                  body: Padding(
                    padding: EdgeInsets.only(left: 20 * sss),
                    child: ExpansionPanelList.radio(
                      elevation: 0,
                      dividerColor: Colors.transparent,
                      expandedHeaderPadding: EdgeInsets.zero,
                      animationDuration: const Duration(milliseconds: 250),
                      materialGapSize: 0,
                      children: [
                        ExpansionPanelRadio(
                          value: 0,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Have you pressed Update Mod Data?",
                                "Press Update Mod Data after you modified the mod outside mod manager",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.only(
                              left: 40 * sss,
                              right: 20 * sss,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (ref.read(validModsPath) ==
                                                null) {
                                              return;
                                            }
                                            ref
                                                .read(
                                                  alertDialogShownProvider
                                                      .notifier,
                                                )
                                                .state = true;
                                            await showDialog(
                                              barrierDismissible: false,
                                              context: context,
                                              builder:
                                                  (context) => UpdateModDialog(
                                                    modsPath:
                                                        ref.read(
                                                          validModsPath,
                                                        )!,
                                                  ),
                                            );
                                            triggerRefresh(ref);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            overlayColor: Colors.white,
                                            backgroundColor:
                                                const Color.fromARGB(
                                                  127,
                                                  255,
                                                  255,
                                                  255,
                                                ),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12 * sss,
                                            ),
                                            child: Text(
                                              'Update Mod Data'.tr(),
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12 * sss,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "",
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.poppins(
                                      color: const Color.fromARGB(
                                        200,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 5 * sss,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 1,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Verify XXMI/3DMigoto version",
                                "It may cause visual glitches if you use old XXMI DLL",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.only(
                              left: 40 * sss,
                              right: 20 * sss,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: getVerifyXxmiVersionSectionChildren(
                                  sss,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 2,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Mods outside _MANAGED_ folder that may cause conflicts",
                                "May cause model glitches or overlapping mods",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.only(
                              left: 40 * sss,
                              right: 20 * sss,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    "",
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.poppins(
                                      color: const Color.fromARGB(
                                        200,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 12 * sss,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    "",
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.poppins(
                                      color: const Color.fromARGB(
                                        200,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 12 * sss,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),

                                  Divider(
                                    color: const Color.fromARGB(
                                      127,
                                      33,
                                      149,
                                      243,
                                    ),
                                    thickness: 1 * sss,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 3,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Mods in different groups that may cause conflicts",
                                "May cause model glitches or overlapping mods if turned on together, usually because a mod was put in the wrong group",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.only(
                              left: 40 * sss,
                              right: 20 * sss,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    "",
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.poppins(
                                      color: const Color.fromARGB(
                                        200,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 12 * sss,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    "",
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.poppins(
                                      color: const Color.fromARGB(
                                        200,
                                        255,
                                        255,
                                        255,
                                      ),
                                      fontSize: 12 * sss,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),

                                  Divider(
                                    color: const Color.fromARGB(
                                      127,
                                      33,
                                      149,
                                      243,
                                    ),
                                    thickness: 1 * sss,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 4,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Detect missing texture references",
                                "Mods referencing non-existent textures may cause black or transparent visuals",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 5,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Detect misplaced mod libraries",
                                "Mod libraries (RabbitFx, TexFx, Orfix, etc) should not be inside _MANAGED_ or they may fail to load",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 6,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Check shader dump setting and ShaderFixes folder",
                                "Enabling shader dumping may leave unintended shader replacements in ShaderFixes",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 7,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Verify exclude_recursive configuration",
                                "Incorrect settings may fail to exclude disabled mods and cause overlap",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.only(
                              left: 40 * sss,
                              right: 20 * sss,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [],
                              ),
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 8,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Fix for outdated mods",
                                "Older mods may break after game updates and require fixes",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Performance Problems
                ExpansionPanelRadio(
                  value: 1,
                  headerBuilder:
                      (context, isExpanded) =>
                          mainCategoryHeader("Performance Problems", sss),
                  backgroundColor: Colors.transparent,
                  canTapOnHeader: true,
                  body: Padding(
                    padding: EdgeInsets.only(left: 20 * sss),
                    child: ExpansionPanelList.radio(
                      elevation: 0,
                      dividerColor: Colors.transparent,
                      expandedHeaderPadding: EdgeInsets.zero,
                      animationDuration: const Duration(milliseconds: 250),
                      materialGapSize: 0,
                      children: [
                        ExpansionPanelRadio(
                          value: 0,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Detect ShaderRegex texture override usage",
                                "Using checktextureoverride in ShaderRegex may reduce FPS",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 1,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Check if debug logging is enabled",
                                "Logging may reduce FPS and generate large log files",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 2,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Check shader cache setting",
                                "Enabling cache_shaders may reduce reload time and stutter",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 3,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Disable unused character groups",
                                "Fewer active groups can shorten reload time",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Other Problems
                ExpansionPanelRadio(
                  value: 2,
                  headerBuilder:
                      (context, isExpanded) =>
                          mainCategoryHeader("Other Problems", sss),
                  backgroundColor: Colors.transparent,
                  canTapOnHeader: true,
                  body: Padding(
                    padding: EdgeInsets.only(left: 20 * sss),
                    child: ExpansionPanelList.radio(
                      elevation: 0,
                      dividerColor: Colors.transparent,
                      expandedHeaderPadding: EdgeInsets.zero,
                      animationDuration: const Duration(milliseconds: 250),
                      materialGapSize: 0,
                      children: [
                        ExpansionPanelRadio(
                          value: 0,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Verify background key input setting",
                                "Important! Mods may fail to activate if background key detection is disabled",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 1,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Check file path length",
                                "Excessively long paths may cause loader errors or crashes",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 2,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Scan d3dx_user.ini for invalid entries",
                                "Invalid lines may reset mod selections and prevent mod customizations from saving",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 3,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Optimize mod and group icons",
                                "Compressing icons can reduce mod manager RAM usage",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                        ExpansionPanelRadio(
                          value: 4,
                          backgroundColor: Colors.transparent,
                          canTapOnHeader: true,
                          headerBuilder:
                              (context, isExpanded) => itemHeader(
                                "Clean unused removed mods",
                                "Deleting DISABLED_MANAGED_REMOVED contents can free storage space",
                                sss,
                              ),
                          body: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 15 * sss,
                              horizontal: 20 * sss,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
