import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:auto_updater/auto_updater.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/languages_name.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mods_dropzone.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

class TabSettings extends ConsumerStatefulWidget {
  const TabSettings({super.key});

  @override
  ConsumerState<TabSettings> createState() => _TabSettingsState();
}

class _TabSettingsState extends ConsumerState<TabSettings> {
  String appVersion = "appVersion";
  @override
  void initState() {
    _getAppVersion();
    super.initState();
  }

  Future<void> _getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = "v${info.version}";
    });
  }

  String _getRevertInfoText() {
    return ref.watch(windowIsPinnedProvider)
        ? 'Drag & Drop mod folders here, to revert any modifications caused by this tool.'
            .tr()
        : '${'Drag & Drop mod folders here, to revert any modifications caused by this tool.'.tr()}\n${'Right-click and pin this window to use this.'.tr()}';
  }

  void _onModRevertConfirm(List<Directory> modDirs) {
    ref.read(alertDialogShownProvider.notifier).state = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => RevertModDialog(modDirs: modDirs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: 85 * sss,
              bottom: 15 * sss,
              left: 45 * sss,
              right: 45 * sss,
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
                          Uri.parse(ref.read(tutorialLinkProvider)),
                        )) {}
                      } catch (e) {}
                    },
                    label: 'Tutorial'.tr(),
                  ),
                ],
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GameSettings(),

                      Container(height: 15 * sss),
                      Divider(
                        color: const Color.fromARGB(127, 33, 149, 243),
                        thickness: 1 * sss,
                      ),
                      Container(height: 10 * sss),
                      Text(
                        'Reverter'.tr(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14 * sss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(height: 5 * sss),
                      Container(
                        height: 160 * sss,
                        decoration: BoxDecoration(
                          border: Border.all(
                            width: 3 * sss,
                            color: const Color.fromARGB(127, 255, 255, 255),
                          ),
                          borderRadius: BorderRadius.circular(20 * sss),
                        ),
                        child: Stack(
                          children: [
                            if (ref.watch(tabIndexProvider) == 2 &&
                                !ref.watch(alertDialogShownProvider))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20 * sss),
                                child: ModsDropZone(
                                  dialogTitleText: "Revert mods".tr(),
                                  onConfirmFunction: _onModRevertConfirm,
                                  additionalContent: TextSpan(
                                    text:
                                        "\n${'Reverting mods will remove all changes you made while these mods were managed.'.tr()}",
                                    style: GoogleFonts.poppins(
                                      color: const Color.fromARGB(
                                        255,
                                        189,
                                        170,
                                        0,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder,
                                    color: const Color.fromARGB(
                                      127,
                                      255,
                                      255,
                                      255,
                                    ),
                                    size: 30 * sss,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 19,
                                    ),
                                    child: Text(
                                      _getRevertInfoText(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: const Color.fromARGB(
                                          127,
                                          255,
                                          255,
                                          255,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12 * sss,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 2 * sss),
                      Text(
                        "Only for mods that are directly removed via File Explorer (without right-click on “Mods” tab)"
                            .tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color.fromARGB(200, 255, 255, 255),
                          fontSize: 11 * sss,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      Container(height: 15 * sss),
                      Divider(
                        color: const Color.fromARGB(127, 33, 149, 243),
                        thickness: 1 * sss,
                      ),
                      Container(height: 10 * sss),
                      Text(
                        'Overall Scale'.tr(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14 * sss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0 * sss,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 9.0 * sss,
                          ),
                        ),
                        child: Slider(
                          label:
                              "${ref.read(zoomScaleProvider).toStringAsFixed(2)}x",
                          activeColor: Colors.blue,
                          divisions: 23,
                          value: sss,
                          onChangeEnd: (value) {
                            SharedPrefUtils().setOverallScale(value);
                          },
                          onChanged: (value) {
                            ref.read(zoomScaleProvider.notifier).state = value;
                            appWindow.minSize = Size(
                              750 * ref.read(zoomScaleProvider),
                              370 * ref.read(zoomScaleProvider),
                            );
                            appWindow.size = Size(
                              750 * ref.read(zoomScaleProvider),
                              370 * ref.read(zoomScaleProvider),
                            );
                          },
                          min: 0.85,
                          max: 2.0,
                        ),
                      ),
                      Container(height: 10),
                      Text(
                        'Background Transparency'.tr(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14 * sss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0 * sss,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 9.0 * sss,
                          ),
                        ),
                        child: Slider(
                          activeColor: Colors.blue,
                          value: ref.watch(bgTransparencyProvider).toDouble(),
                          onChangeEnd: (value) {
                            SharedPrefUtils().setBgTransparency(value.round());
                          },
                          onChanged: (value) {
                            ref.read(bgTransparencyProvider.notifier).state =
                                value.round();
                          },
                          min: 0,
                          max: 255,
                        ),
                      ),

                      Container(height: 15 * sss),
                      Divider(
                        color: const Color.fromARGB(127, 33, 149, 243),
                        thickness: 1 * sss,
                      ),
                      Container(height: 10 * sss),
                      Text(
                        'Window Toggle Hotkeys'.tr(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14 * sss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(height: 5 * sss),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Keyboard Toggle'.tr(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color.fromARGB(200, 255, 255, 255),
                                fontSize: 11 * sss,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(width: 20 * sss),
                          Expanded(
                            child: Text(
                              'Gamepad(XInput) Toggle'.tr(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color.fromARGB(200, 255, 255, 255),
                                fontSize: 11 * sss,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 42 * sss,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color.fromARGB(
                                    127,
                                    255,
                                    255,
                                    255,
                                  ),
                                  width: 3 * sss,
                                ),
                                borderRadius: BorderRadius.circular(20 * sss),
                              ),
                              child: Center(
                                child:
                                    ref.watch(tabIndexProvider) == 2
                                        ? DropdownButton(
                                          isExpanded: true,
                                          value: ref.watch(
                                            hotkeyKeyboardProvider,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20 * sss,
                                          ),
                                          dropdownColor: const Color(
                                            0xFF2B2930,
                                          ),
                                          underline: SizedBox(),
                                          items: [
                                            DropdownMenuItem(
                                              value: HotkeyKeyboard.altW,
                                              child: Center(
                                                child: Text(
                                                  "Alt+W",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyKeyboard.altS,
                                              child: Center(
                                                child: Text(
                                                  "Alt+S",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyKeyboard.altA,
                                              child: Center(
                                                child: Text(
                                                  "Alt+A",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyKeyboard.altD,
                                              child: Center(
                                                child: Text(
                                                  "Alt+D",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              ref
                                                  .read(
                                                    hotkeyKeyboardProvider
                                                        .notifier,
                                                  )
                                                  .state = value;
                                              SharedPrefUtils()
                                                  .setHotkeyKeyboard(value);
                                            }
                                          },
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                          ),
                                        )
                                        : null,
                              ),
                            ),
                          ),
                          Container(width: 20 * sss),
                          Expanded(
                            child: Container(
                              height: 42 * sss,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color.fromARGB(
                                    127,
                                    255,
                                    255,
                                    255,
                                  ),
                                  width: 3 * sss,
                                ),
                                borderRadius: BorderRadius.circular(20 * sss),
                              ),
                              child: Center(
                                child:
                                    ref.watch(tabIndexProvider) == 2
                                        ? DropdownButton(
                                          isExpanded: true,
                                          value: ref.watch(
                                            hotkeyGamepadProvider,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20 * sss,
                                          ),
                                          dropdownColor: const Color(
                                            0xFF2B2930,
                                          ),

                                          underline: SizedBox(),
                                          items: [
                                            DropdownMenuItem(
                                              value: HotkeyGamepad.none,
                                              child: Center(
                                                child: Text(
                                                  "None".tr(),
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyGamepad.lsB,
                                              child: Center(
                                                child: Text(
                                                  "LeftStick+B",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyGamepad.lsA,
                                              child: Center(
                                                child: Text(
                                                  "LeftStick+A",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyGamepad.lsRb,
                                              child: Center(
                                                child: Text(
                                                  "LeftStick+RB",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyGamepad.selectStart,
                                              child: Center(
                                                child: Text(
                                                  "Select+Start",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: HotkeyGamepad.lsRs,
                                              child: Center(
                                                child: Text(
                                                  "LeftStick+RightStick",
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12 * sss,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              ref
                                                  .read(
                                                    hotkeyGamepadProvider
                                                        .notifier,
                                                  )
                                                  .state = value;
                                              SharedPrefUtils()
                                                  .setHotkeyGamepad(value);
                                            }
                                          },
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                          ),
                                        )
                                        : null,
                              ),
                            ),
                          ),
                        ],
                      ),

                      Container(height: 15 * sss),
                      Divider(
                        color: const Color.fromARGB(127, 33, 149, 243),
                        thickness: 1 * sss,
                      ),
                      Container(height: 10 * sss),

                      //SEGMENT: LANGUAGES
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Languages'.tr(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14 * sss,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(width: 5 * sss),
                          Icon(Icons.translate, size: 18 * sss),
                        ],
                      ),
                      Container(height: 5 * sss),
                      Container(
                        height: 42 * sss,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color.fromARGB(127, 255, 255, 255),
                            width: 3 * sss,
                          ),
                          borderRadius: BorderRadius.circular(20 * sss),
                        ),
                        child: Center(
                          child:
                              ref.watch(tabIndexProvider) == 2
                                  ? DropdownButton(
                                    isExpanded: true,
                                    value: context.locale,
                                    borderRadius: BorderRadius.circular(
                                      20 * sss,
                                    ),
                                    dropdownColor: const Color(0xFF2B2930),

                                    underline: SizedBox(),
                                    items:
                                        context.supportedLocales.map((locale) {
                                          return DropdownMenuItem(
                                            value: locale,
                                            child: Center(
                                              child: Text(
                                                locale.toLanguageName(),
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12 * sss,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (locale) {
                                      if (locale != null) {
                                        context.setLocale(locale);
                                        ref
                                            .read(
                                              alertDialogShownProvider.notifier,
                                            )
                                            .state = true;
                                        showDialog(
                                          barrierDismissible: false,
                                          context: context,
                                          builder:
                                              (context) => ChangeLanguageDialog(
                                                locale: locale,
                                              ),
                                        );
                                      }
                                    },
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  )
                                  : null,
                        ),
                      ),

                      Container(height: 15 * sss),
                      Divider(
                        color: const Color.fromARGB(127, 33, 149, 243),
                        thickness: 1 * sss,
                      ),
                      Container(height: 10 * sss),

                      Text(
                        'Navigation Hotkeys'.tr(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14 * sss,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(height: 5 * sss),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20 * sss),
                          Column(
                            children: [
                              Text(
                                'Mod Navigation'.tr(),
                                style: GoogleFonts.poppins(
                                  color: const Color.fromARGB(
                                    200,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 11 * sss,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/keys_icon/keyW_icon.png',
                                        height: 40 * sss,
                                      ),
                                      Image.asset(
                                        'assets/keys_icon/keyA_icon.png',
                                        height: 40 * sss,
                                      ),
                                      Image.asset(
                                        'assets/keys_icon/keyS_icon.png',
                                        height: 40 * sss,
                                      ),
                                      Image.asset(
                                        'assets/keys_icon/keyD_icon.png',
                                        height: 40 * sss,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Transform.rotate(
                                        angle: pi / 2,
                                        child: Image.asset(
                                          'assets/keys_icon/dpad_icon.png',
                                          height: 40 * sss,
                                        ),
                                      ),
                                      Image.asset(
                                        'assets/keys_icon/dpad_icon.png',
                                        height: 40 * sss,
                                      ),
                                      Transform.rotate(
                                        angle: pi / -2,
                                        child: Image.asset(
                                          'assets/keys_icon/dpad_icon.png',
                                          height: 40 * sss,
                                        ),
                                      ),

                                      Transform.rotate(
                                        angle: pi,
                                        child: Image.asset(
                                          'assets/keys_icon/dpad_icon.png',
                                          height: 40 * sss,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(width: 20 * sss),
                          Column(
                            children: [
                              Text(
                                'Select Mod'.tr(),
                                style: GoogleFonts.poppins(
                                  color: const Color.fromARGB(
                                    200,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 11 * sss,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Column(
                                children: [
                                  Image.asset(
                                    'assets/keys_icon/keyF_icon.png',
                                    height: 40 * sss,
                                  ),
                                  Image.asset(
                                    'assets/keys_icon/a_icon.png',
                                    height: 40 * sss,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(width: 20 * sss),
                          Column(
                            children: [
                              Text(
                                'Mod Keybind'.tr(),
                                style: GoogleFonts.poppins(
                                  color: const Color.fromARGB(
                                    200,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 11 * sss,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Column(
                                children: [
                                  Image.asset(
                                    'assets/keys_icon/keyR_icon.png',
                                    height: 40 * sss,
                                  ),
                                  Image.asset(
                                    'assets/keys_icon/x_icon.png',
                                    height: 40 * sss,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(width: 20 * sss),
                          Column(
                            children: [
                              Text(
                                'Tab Navigation'.tr(),
                                style: GoogleFonts.poppins(
                                  color: const Color.fromARGB(
                                    200,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 11 * sss,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/keys_icon/keyQ_icon.png',
                                        height: 40 * sss,
                                      ),
                                      Image.asset(
                                        'assets/keys_icon/keyE_icon.png',
                                        height: 40 * sss,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/keys_icon/lb_icon.png',
                                        height: 40 * sss,
                                      ),
                                      Image.asset(
                                        'assets/keys_icon/rb_icon.png',
                                        height: 40 * sss,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),

                          Container(width: 20 * sss),
                          Column(
                            children: [
                              Text(
                                'Search'.tr(),
                                style: GoogleFonts.poppins(
                                  color: const Color.fromARGB(
                                    200,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 11 * sss,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Column(
                                children: [
                                  Image.asset(
                                    'assets/keys_icon/keySpace_icon.png',
                                    height: 40 * sss,
                                  ),
                                  Container(height: 40 * sss),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(height: 15 * sss),
                      Divider(
                        color: const Color.fromARGB(127, 33, 149, 243),
                        thickness: 1 * sss,
                      ),
                      Container(height: 15 * sss),

                      ElevatedButton(
                        onPressed: () async {
                          ref.read(windowIsPinnedProvider.notifier).state =
                              false;
                          await autoUpdater.checkForUpdates();
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
                          padding: EdgeInsets.symmetric(vertical: 8 * sss),
                          child: Text(
                            'Check for Updates'.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12 * sss,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      Container(height: 15 * sss),
                      Divider(
                        color: const Color.fromARGB(127, 33, 149, 243),
                        thickness: 1 * sss,
                      ),
                      Container(height: 15 * sss),

                      ElevatedButton(
                        onPressed: () {
                          exit(0);
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
                          padding: EdgeInsets.symmetric(vertical: 8 * sss),
                          child: Text(
                            'Exit'.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12 * sss,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      Container(height: 20 * sss),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  "Support me".tr(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12 * sss,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(height: 8 * sss),
                                CustomImageButtonLink(
                                  link: ref.watch(supportLinkProvider),
                                  imageNormal: Image.network(
                                    ConstantVar.urlSupportIcon,
                                    height: 25 * sss,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.error);
                                    },
                                  ),
                                  imageOnHover: Image.network(
                                    ConstantVar.urlSupportIconOnHover,
                                    height: 25 * sss,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.error);
                                    },
                                  ),
                                ),
                                Container(height: 15 * sss),
                              ],
                            ),
                          ),
                          Container(width: 15 * sss),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  "Contact for help".tr(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12 * sss,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(height: 8 * sss),
                                CustomImageButtonLink(
                                  link: ref.watch(contactLinkProvider),
                                  imageNormal: Image.network(
                                    ConstantVar.urlContactIcon,
                                    height: 25 * sss,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.error);
                                    },
                                  ),
                                  imageOnHover: Image.network(
                                    ConstantVar.urlContactIconOnHover,
                                    height: 25 * sss,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.error);
                                    },
                                  ),
                                ),
                                Container(height: 15 * sss),
                              ],
                            ),
                          ),
                          Container(width: 15 * sss),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  "Tutorial".tr(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12 * sss,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(height: 8 * sss),
                                CustomImageButtonLink(
                                  link: ref.watch(tutorialLinkProvider),
                                  imageNormal: Image.network(
                                    ConstantVar.urlTutorialIcon,
                                    height: 25 * sss,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.error);
                                    },
                                  ),
                                  imageOnHover: Image.network(
                                    ConstantVar.urlTutorialIconOnHover,
                                    height: 25 * sss,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.error);
                                    },
                                  ),
                                ),
                                Container(height: 15 * sss),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            appVersion,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 10 * sss),
          ),
        ),
      ],
    );
  }
}

class CustomImageButtonLink extends StatefulWidget {
  final Image imageNormal;
  final Image imageOnHover;
  final String link;

  const CustomImageButtonLink({
    super.key,
    required this.imageNormal,
    required this.imageOnHover,
    required this.link,
  });

  @override
  State<CustomImageButtonLink> createState() => _CustomImageButtonLinkState();
}

class _CustomImageButtonLinkState extends State<CustomImageButtonLink> {
  bool _isHovering = false;

  Future<void> _launchUrl() async {
    try {
      if (!await launchUrl(Uri.parse(widget.link))) {}
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
      },
      onExit: (_) {
        setState(() => _isHovering = false);
      },
      child: GestureDetector(
        onTap: () {
          _launchUrl();
        },
        child: _isHovering ? widget.imageOnHover : widget.imageNormal,
      ),
    );
  }
}

class GameSettings extends ConsumerStatefulWidget {
  const GameSettings({super.key});

  @override
  ConsumerState<GameSettings> createState() => _GameSettingsState();
}

class _GameSettingsState extends ConsumerState<GameSettings> {
  final TextEditingController _targetProcessTextFieldController =
      TextEditingController();
  final TextEditingController _modsPathTextFieldController =
      TextEditingController();
  bool _isPickingFolder = false;
  String modsPathText = "Mods Path".tr();

  @override
  void initState() {
    super.initState();

    ref.listenManual(targetGameProvider, (previous, next) {
      loadTextFieldModsPath(next);
      loadTextFieldTargetProcess(next);
    });
  }

  @override
  void dispose() {
    _targetProcessTextFieldController.dispose();
    _modsPathTextFieldController.dispose();
    super.dispose();
  }

  String _getTargetProcessHintText() {
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        return '${'example:'.tr()} Client-Win64-Shipping.exe';
      case TargetGame.Genshin_Impact:
        return '${'example:'.tr()} GenshinImpact.exe';
      case TargetGame.Honkai_Star_Rail:
        return '${'example:'.tr()} StarRail.exe';
      case TargetGame.Zenless_Zone_Zero:
        return '${'example:'.tr()} ZenlessZoneZero.exe';
      default:
        return '';
    }
  }

  String _getModsPathHintText() {
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        return '${'example:'.tr()} D:\\WWMI\\Mods';
      case TargetGame.Genshin_Impact:
        return '${'example:'.tr()} D:\\GIMI\\Mods';
      case TargetGame.Honkai_Star_Rail:
        return '${'example:'.tr()} D:\\SRMI\\Mods';
      case TargetGame.Zenless_Zone_Zero:
        return '${'example:'.tr()} D:\\ZZMI\\Mods';
      default:
        return '';
    }
  }

  String _getTitleSettingText() {
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        return 'Wuthering Waves'.tr();
      case TargetGame.Genshin_Impact:
        return 'Genshin Impact'.tr();
      case TargetGame.Honkai_Star_Rail:
        return 'Honkai Star Rail'.tr();
      case TargetGame.Zenless_Zone_Zero:
        return 'Zenless Zone Zero'.tr();
      default:
        return 'Please re-open with Hotkey or System Tray'.tr();
    }
  }

  void _saveTargetProcess(String value) {
    switch (ref.read(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        SharedPrefUtils().setWuwaTargetProcess(value);
        break;
      case TargetGame.Genshin_Impact:
        SharedPrefUtils().setGenshinTargetProcess(value);
        break;
      case TargetGame.Honkai_Star_Rail:
        SharedPrefUtils().setHsrTargetProcess(value);
        break;
      case TargetGame.Zenless_Zone_Zero:
        SharedPrefUtils().setZzzTargetProcess(value);
        break;
      default:
        break;
    }
  }

  void _saveModsPath(String value) {
    switch (ref.read(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        SharedPrefUtils().setWuwaModsPath(value);
        break;
      case TargetGame.Genshin_Impact:
        SharedPrefUtils().setGenshinModsPath(value);
        break;
      case TargetGame.Honkai_Star_Rail:
        SharedPrefUtils().setHsrModsPath(value);
        break;
      case TargetGame.Zenless_Zone_Zero:
        SharedPrefUtils().setZzzModsPath(value);
        break;
      default:
        break;
    }
  }

  void loadTextFieldTargetProcess(TargetGame targetGame) {
    switch (targetGame) {
      case TargetGame.Wuthering_Waves:
        _targetProcessTextFieldController.text =
            SharedPrefUtils().getWuwaTargetProcess();
        break;
      case TargetGame.Genshin_Impact:
        _targetProcessTextFieldController.text =
            SharedPrefUtils().getGenshinTargetProcess();
        break;
      case TargetGame.Honkai_Star_Rail:
        _targetProcessTextFieldController.text =
            SharedPrefUtils().getHsrTargetProcess();
        break;
      case TargetGame.Zenless_Zone_Zero:
        _targetProcessTextFieldController.text =
            SharedPrefUtils().getZzzTargetProcess();
        break;
      default:
        break;
    }
  }

  void loadTextFieldModsPath(TargetGame targetGame) {
    switch (targetGame) {
      case TargetGame.Wuthering_Waves:
        _modsPathTextFieldController.text = SharedPrefUtils().getWuwaModsPath();
        break;
      case TargetGame.Genshin_Impact:
        _modsPathTextFieldController.text =
            SharedPrefUtils().getGenshinModsPath();
        break;
      case TargetGame.Honkai_Star_Rail:
        _modsPathTextFieldController.text = SharedPrefUtils().getHsrModsPath();
        break;
      case TargetGame.Zenless_Zone_Zero:
        _modsPathTextFieldController.text = SharedPrefUtils().getZzzModsPath();
        break;
      default:
        break;
    }
    isModsPathValid(_modsPathTextFieldController.text);
  }

  Future<bool> isModsPathValid(String path) async {
    bool valid = false;

    try {
      if (!await Directory(path).exists()) {
        valid = false;
        setState(() {
          modsPathText = "Mods Path (path doesn't exist)".tr();
        });
      } else if (path.toLowerCase().endsWith('mods') ||
          path.toLowerCase().endsWith('mods\\')) {
        valid = true;
        setState(() {
          modsPathText = "Mods Path".tr();
        });
      } else {
        valid = false;
        setState(() {
          modsPathText = "Mods Path (Invalid)".tr();
        });
      }
    } catch (e) {
      valid = false;
      setState(() {
        modsPathText = "Mods Path (Invalid)".tr();
      });
    }

    return valid;
  }

  Future<void> _pickFolder() async {
    if (_isPickingFolder) return; // Prevent multiple triggers
    bool wasPinned = ref.read(windowIsPinnedProvider);
    ref.read(windowIsPinnedProvider.notifier).state = true;
    setState(() {
      _isPickingFolder = true;
    });

    String initialDir =
        await Directory(_modsPathTextFieldController.text).exists() == true &&
                _modsPathTextFieldController.text.trim() != ''
            ? _modsPathTextFieldController.text
            : p.join(
              SharedPrefUtils().getUserProfilePath(),
              r'AppData\Roaming',
            );
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        lockParentWindow: true,
        dialogTitle: 'Please select "Mods" folder'.tr(),
        initialDirectory: initialDir,
      );

      if (selectedDirectory != null) {
        _modsPathTextFieldController.text = selectedDirectory;
        _saveModsPath(selectedDirectory);
        isModsPathValid(selectedDirectory);
      }
    } finally {
      if (!wasPinned) {
        ref.read(windowIsPinnedProvider.notifier).state = false;
      }
      setState(() {
        _isPickingFolder = false;
      });
    }
  }

  void _onUpdateModDataClicked() {
    ref.read(alertDialogShownProvider.notifier).state = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (context) =>
              UpdateModDialog(modsPath: _modsPathTextFieldController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getTitleSettingText(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14 * sss,
            ),
          ),

          Container(height: 5 * sss),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'Target Process'.tr(),
                    style: GoogleFonts.poppins(
                      color: const Color.fromARGB(200, 255, 255, 255),
                      fontSize: 11 * sss,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Container(width: 20 * sss),
              Expanded(
                child: Center(
                  child: Text(
                    modsPathText,
                    style: GoogleFonts.poppins(
                      color: const Color.fromARGB(200, 255, 255, 255),
                      fontSize: 11 * sss,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 42 * sss,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        selectionColor: const Color.fromARGB(127, 33, 149, 243),
                      ),
                    ),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(dragDevices: {}),
                      child: TextField(
                        cursorColor: Colors.blue,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12 * sss,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 15 * sss,
                          ),
                          hintText: _getTargetProcessHintText(),
                          hintStyle: GoogleFonts.poppins(
                            color: const Color.fromARGB(90, 255, 255, 255),
                            fontSize: 12 * sss,
                            fontWeight: FontWeight.w400,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100 * sss),
                            borderSide: BorderSide(
                              width: 3 * sss,
                              color: const Color.fromARGB(127, 255, 255, 255),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100 * sss),
                            borderSide: BorderSide(
                              width: 3 * sss,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        controller: _targetProcessTextFieldController,
                        onChanged: (value) {
                          _saveTargetProcess(value);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 20 * sss),
              Expanded(
                child: SizedBox(
                  height: 42 * sss,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100 * sss),
                      border: Border.all(
                        color: Colors.transparent,
                        width: 3 * sss,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: TextSelectionThemeData(
                              selectionColor: const Color.fromARGB(
                                127,
                                33,
                                149,
                                243,
                              ),
                            ),
                          ),
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(dragDevices: {}),
                            child: TextField(
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12 * sss,
                                fontWeight: FontWeight.w400,
                              ),
                              cursorColor: Colors.blue,
                              decoration: InputDecoration(
                                fillColor: Colors.white,
                                hintText: _getModsPathHintText(),
                                hintStyle: GoogleFonts.poppins(
                                  color: const Color.fromARGB(
                                    90,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 12 * sss,
                                  fontWeight: FontWeight.w400,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    100 * sss,
                                  ),
                                  borderSide: BorderSide(
                                    width: 3 * sss,
                                    color: const Color.fromARGB(
                                      127,
                                      255,
                                      255,
                                      255,
                                    ),
                                  ),
                                ),
                                contentPadding: EdgeInsets.only(
                                  left: 10 * sss,
                                  right: 70 * sss,
                                  top: 15 * sss,
                                  bottom: 15 * sss,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    100 * sss,
                                  ),
                                  borderSide: BorderSide(
                                    width: 3 * sss,
                                    color: Colors.blue,
                                    strokeAlign: BorderSide.strokeAlignOutside,
                                  ),
                                ),
                              ),
                              controller: _modsPathTextFieldController,
                              onChanged: (value) async {
                                _saveModsPath(value);
                                isModsPathValid(value);
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(
                                  RegExp('["\'\n\r\u0085\u2028\u2029]'),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 42 * sss,
                            child: ElevatedButton(
                              onLongPress:
                                  () => openFileExplorerToSpecifiedPath(
                                    _modsPathTextFieldController.text,
                                  ),
                              onPressed: _isPickingFolder ? null : _pickFolder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                overlayColor: Colors.white,
                              ),
                              child: Transform.scale(
                                scale: 1.3,
                                child: Icon(
                                  Icons.folder_outlined,
                                  color: Colors.white,
                                  size: 20 * sss,
                                ),
                              ),
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

          Container(height: 15 * sss),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _onUpdateModDataClicked();
                  },
                  style: ElevatedButton.styleFrom(
                    overlayColor: Colors.white,
                    backgroundColor: const Color.fromARGB(127, 255, 255, 255),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12 * sss),
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
          Container(height: 2 * sss),
          Text(
            "Press this after you add/remove/edit/fix mods (usually when add/edit/remove mods directly via File Explorer)"
                .tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 11 * sss,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ChangeLanguageDialog extends ConsumerWidget {
  final Locale locale;
  const ChangeLanguageDialog({super.key, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(
        'Change language'.tr(),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Language changed, please Restart.'.tr(),
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(alertDialogShownProvider.notifier).state = false;
            checkToRelaunch(forcedRelaunch: true);
          },
          child: Text(
            'Restart'.tr(),
            style: GoogleFonts.poppins(color: Colors.blue),
          ),
        ),
      ],
    );
  }
}
