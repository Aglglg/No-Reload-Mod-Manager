import 'dart:io';
import 'dart:ui';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/mods_dropzone.dart';
import 'package:path/path.dart' as p;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

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
    return ref.watch(fromTrayProvider)
        ? 'Drag & Drop mod folders here, to revert any modifications caused by this tool.'
        : 'Drag & Drop mod folders here, to revert any modifications caused by this tool.\nRight-click and pin this window to use this.';
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeFocusTraversal(
      child: Stack(
        children: [
          Container(
            color: Colors.transparent,
            child: MoveWindow(onDoubleTap: () {}),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 85,
                bottom: 15,
                left: 50,
                right: 50,
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GameSettings(),
                      Container(height: 20),
                      Container(
                        height: 105,
                        decoration: BoxDecoration(
                          border: Border.all(
                            width: 3,
                            color: const Color.fromARGB(127, 255, 255, 255),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            if (ref.watch(tabIndexProvider) == 2 &&
                                !ref.watch(alertDialogShownProvider))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: ModsDropZone(
                                  dialogTitleText: "Revert mods",
                                  onConfirmFunction:
                                      (validFolder) => print("CONFIRM REVERT"),
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
                                    size: 30,
                                  ),
                                  Text(
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
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 2),
                      Text(
                        "Only for mods that are directly removed via File Explorer (without right-click on “Mods” tab)",
                        textAlign: TextAlign.end,
                        style: GoogleFonts.poppins(
                          color: const Color.fromARGB(200, 255, 255, 255),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Keyboard Toggle Window',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color.fromARGB(200, 255, 255, 255),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(width: 20),
                          Expanded(
                            child: Text(
                              'Gamepad(XInput) Toggle Window',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color.fromARGB(200, 255, 255, 255),
                                fontSize: 11,
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
                              height: 42,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color.fromARGB(
                                    127,
                                    255,
                                    255,
                                    255,
                                  ),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButton(
                                itemHeight: 48,
                                isExpanded: true,
                                value: ref.watch(hotkeyKeyboardProvider),
                                borderRadius: BorderRadius.circular(20),
                                dropdownColor: Colors.grey,

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
                                          fontSize: 12,
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
                                          fontSize: 12,
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
                                          fontSize: 12,
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
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    ref
                                        .read(hotkeyKeyboardProvider.notifier)
                                        .state = value;
                                    SharedPrefUtils().setHotkeyKeyboard(value);
                                  }
                                },
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ),
                          ),
                          Container(width: 20),
                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color.fromARGB(
                                    127,
                                    255,
                                    255,
                                    255,
                                  ),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButton(
                                itemHeight: 48,
                                isExpanded: true,
                                value: ref.watch(hotkeyGamepadProvider),
                                borderRadius: BorderRadius.circular(20),
                                dropdownColor: Colors.grey,

                                underline: SizedBox(),
                                items: [
                                  DropdownMenuItem(
                                    value: HotkeyGamepad.none,
                                    child: Center(
                                      child: Text(
                                        "None",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
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
                                          fontSize: 12,
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
                                          fontSize: 12,
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
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    ref
                                        .read(hotkeyGamepadProvider.notifier)
                                        .state = value;
                                    SharedPrefUtils().setHotkeyGamepad(value);
                                  }
                                },
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                "Support me",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(height: 8),
                              CustomImageButtonLink(
                                link: ref.watch(supportLinkProvider),
                                imageNormal: Image.network(
                                  ConstantVar.urlSupportIcon,
                                  height: 25,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.error);
                                  },
                                ),
                                imageOnHover: Image.network(
                                  ConstantVar.urlSupportIconOnHover,
                                  height: 25,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.error);
                                  },
                                ),
                              ),
                              Container(height: 15),
                            ],
                          ),
                          Container(width: 30),
                          Column(
                            children: [
                              Text(
                                "Tutorial",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(height: 8),
                              CustomImageButtonLink(
                                link: ref.watch(tutorialLinkProvider),
                                imageNormal: Image.network(
                                  ConstantVar.urlTutorialIcon,
                                  height: 25,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.error);
                                  },
                                ),
                                imageOnHover: Image.network(
                                  ConstantVar.urlTutorialIconOnHover,
                                  height: 25,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.error);
                                  },
                                ),
                              ),
                              Container(height: 15),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              appVersion,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
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

class ClickableText extends StatefulWidget {
  const ClickableText({super.key});

  @override
  State<ClickableText> createState() => _ClickableTextState();
}

class _ClickableTextState extends State<ClickableText> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Created alone by ',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                print('Clicked @someone');
                // You can launch a URL or open profile etc.
              },
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.poppins(
                  color: _isHovering ? Colors.blue : Colors.white,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.underline,
                  fontSize: 12,
                ),
                child: const Text('@agulag'),
              ),
            ),
          ),
          Text(
            ' on GameBanana (Free & Open Source Software)',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ],
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
  String modsPathText = "Mods Path";

  @override
  void initState() {
    super.initState();

    ref.listenManual(targetGameProvider, (previous, next) {
      loadTextFieldModsPath(next);
      loadTextFieldTargetProcess(next);
    });
  }

  String _getTargetProcessHintText() {
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        return 'example: Client-Win64-Shipping.exe';
      case TargetGame.Genshin_Impact:
        return 'example: GenshinImpact.exe';
      case TargetGame.Honkai_Star_Rail:
        return 'example: StarRail.exe';
      case TargetGame.Zenless_Zone_Zero:
        return 'example: ZenlessZoneZero.exe';
      default:
        return '';
    }
  }

  String _getModsPathHintText() {
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        return r'example: D:\WWMI\Mods';
      case TargetGame.Genshin_Impact:
        return r'example: D:\GIMI\Mods';
      case TargetGame.Honkai_Star_Rail:
        return r'example: D:\SRMI\Mods';
      case TargetGame.Zenless_Zone_Zero:
        return r'example: D:\ZZMI\Mods';
      default:
        return '';
    }
  }

  String _getTitleSettingText() {
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Wuthering_Waves:
        return 'Wuthering Waves';
      case TargetGame.Genshin_Impact:
        return 'Settings';
      case TargetGame.Honkai_Star_Rail:
        return 'Honkai Star Rail';
      case TargetGame.Zenless_Zone_Zero:
        return 'Zenless Zone Zero';
      default:
        return 'unexpected_error(almost impossible that you see this) please report to dev';
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
    if (!await Directory(path).exists()) {
      valid = false;
      setState(() {
        modsPathText = "Mods Path (path doesn't exist)";
      });
    } else if (path.toLowerCase().endsWith('mods') ||
        path.toLowerCase().endsWith('mods\\')) {
      valid = true;
      setState(() {
        modsPathText = "Mods Path";
      });
    } else {
      valid = false;
      setState(() {
        modsPathText = "Mods Path (Invalid)";
      });
    }

    return valid;
  }

  Future<void> _pickFolder() async {
    if (_isPickingFolder) return; // Prevent multiple triggers
    bool wasPinned = ref.read(fromTrayProvider);
    ref.read(fromTrayProvider.notifier).state = true;
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
        dialogTitle: 'Please select "Mods" folder',
        initialDirectory: initialDir,
      );

      if (selectedDirectory != null) {
        _modsPathTextFieldController.text = selectedDirectory;
        _saveModsPath(selectedDirectory);
        isModsPathValid(selectedDirectory);
      }
    } finally {
      if (!wasPinned) {
        ref.read(fromTrayProvider.notifier).state = false;
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getTitleSettingText(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),

          Container(height: 5),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    'Target Process',
                    style: GoogleFonts.poppins(
                      color: const Color.fromARGB(200, 255, 255, 255),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Container(width: 20),
              Expanded(
                child: Center(
                  child: Text(
                    modsPathText,
                    style: GoogleFonts.poppins(
                      color: const Color.fromARGB(200, 255, 255, 255),
                      fontSize: 11,
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
                  height: 42,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: _getTargetProcessHintText(),
                          hintStyle: GoogleFonts.poppins(
                            color: const Color.fromARGB(90, 255, 255, 255),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: BorderSide(
                              width: 3,
                              color: const Color.fromARGB(127, 255, 255, 255),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: BorderSide(
                              width: 3,
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
              Container(width: 20),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: Colors.transparent,
                        width: 3,
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
                                fontSize: 12,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  borderSide: BorderSide(
                                    width: 3,
                                    color: const Color.fromARGB(
                                      127,
                                      255,
                                      255,
                                      255,
                                    ),
                                  ),
                                ),
                                contentPadding: EdgeInsets.only(
                                  left: 10,
                                  right: 70,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(100),
                                  borderSide: BorderSide(
                                    width: 3,
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
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isPickingFolder ? null : _pickFolder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                overlayColor: Colors.white,
                              ),
                              child: Transform.scale(
                                scale: 1.3,
                                child: const Icon(
                                  Icons.folder_outlined,
                                  color: Colors.white,
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

          Container(height: 15),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Update Mod Data',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(height: 2),
          Text(
            "Press this after you add/remove/edit/fix mods (usually when add/edit/remove mods directly via File Explorer)",
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(200, 255, 255, 255),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class UpdateModDialog extends ConsumerStatefulWidget {
  final String modsPath;
  const UpdateModDialog({super.key, required this.modsPath});

  @override
  ConsumerState<UpdateModDialog> createState() => _UpdateModDialogState();
}

class _UpdateModDialogState extends ConsumerState<UpdateModDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showClose = false;
  bool _needReload = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    validatingModsPath();
  }

  Future<void> validatingModsPath() async {
    setState(() {
      contents = [];
      contents.add(
        TextSpan(
          text: 'Validating Mods Path...\n',
          style: GoogleFonts.poppins(color: Colors.black),
        ),
      );
    });

    if (!await Directory(widget.modsPath).exists()) {
      setState(() {
        _showClose = true;
        contents = [
          TextSpan(
            text: "Mods path doesn't exist",
            style: GoogleFonts.poppins(color: Colors.red),
          ),
        ];
      });
    } else if (widget.modsPath.toLowerCase().endsWith('mods') ||
        widget.modsPath.toLowerCase().endsWith('mods\\')) {
      setState(() {
        contents = [
          TextSpan(
            text: "Modifying mods...",
            style: GoogleFonts.poppins(color: Colors.black),
          ),
        ];
      });
      final operationResults = await updateModData(widget.modsPath, (
        needReload,
      ) {
        setState(() {
          _needReload = needReload;
        });
      });
      setState(() {
        _showClose = true;
        contents = operationResults;
      });
      _scrollToBottom();
    } else {
      setState(() {
        _showClose = true;
        contents = [
          TextSpan(
            text:
                "Mods path is invalid. Make sure you're targetting \"Mods\" folder.",
            style: GoogleFonts.poppins(color: Colors.red),
          ),
        ];
      });
    }
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
        'Managing mod',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 17),
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
          _showClose
              ? [
                _needReload
                    ? TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(alertDialogShownProvider.notifier).state =
                            false;
                        //TODO: Simulate keypress F10;
                      },
                      child: Text(
                        'Close & Reload',
                        style: GoogleFonts.poppins(color: Colors.blue),
                      ),
                    )
                    : TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(alertDialogShownProvider.notifier).state =
                            false;
                      },
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(color: Colors.blue),
                      ),
                    ),
              ]
              : [],
    );
  }
}
