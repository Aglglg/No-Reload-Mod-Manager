import 'dart:io';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/services.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/get_cloud_data.dart';
import 'package:no_reload_mod_manager/utils/hotkey_handler.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_navigator.dart';
import 'package:no_reload_mod_manager/utils/mods_dropzone.dart';
import 'package:no_reload_mod_manager/utils/refreshable_image.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:no_reload_mod_manager/tabs/keybinds_tab.dart';
import 'package:no_reload_mod_manager/tabs/mods_tab.dart';
import 'package:no_reload_mod_manager/tabs/settings_tab.dart';
import 'package:no_reload_mod_manager/utils/get_process_name.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_tray/system_tray.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:animated_segmented_tab_control/animated_segmented_tab_control.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'package:flutter/material.dart';
import 'package:xinput_gamepad/xinput_gamepad.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPrefUtils().init();
  await setupWindow();
  runApp(ProviderScope(child: MyApp()));
}

Future<void> setupWindow() async {
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  if (await FlutterSingleInstance().isFirstInstance() == false) {
    exit(0);
  }

  String feedURL =
      'https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/appcast.xml';
  await autoUpdater.setFeedURL(feedURL);
  await autoUpdater.setScheduledCheckInterval(0);

  doWhenWindowReady(() async {
    const initialSize = Size(750, 330);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;

    WindowOptions windowOptions = WindowOptions(
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMaximizable(false);
      await windowManager.setAsFrameless();
      await windowManager.setClosable(false);
    });
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KeyboardListener(
      onKeyEvent: (value) {
        if (value is KeyUpEvent ||
            ref.read(alertDialogShownProvider) ||
            ref.read(popupMenuShownProvider)) {
        } else {
          ModNavigationListener.notifyListeners(value, null);
        }
      },
      focusNode: FocusNode(),
      autofocus: true,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Background(),
        theme: ThemeData.dark(),
      ),
    );
  }
}

class Background extends ConsumerStatefulWidget {
  const Background({super.key});

  @override
  ConsumerState<Background> createState() => _BackgroundState();
}

class _BackgroundState extends ConsumerState<Background> {
  Color getBorderColor(WidgetRef ref) {
    if (ref.watch(windowIsPinnedProvider)) {
      return const Color.fromARGB(255, 33, 149, 243);
    } else {
      return const Color.fromARGB(127, 255, 255, 255);
    }
  }

  void _onModAddConfirm(List<Directory> modDirs) {
    String? modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      ref.read(alertDialogShownProvider.notifier).state = true;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder:
            (context) => CopyModDialog(
              modDirs: modDirs,
              modsPath: modsPath,
              targetGroupPath:
                  ref
                      .read(modGroupDataProvider)[ref.read(
                        currentGroupIndexProvider,
                      )]
                      .groupDir
                      .path,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeFocusTraversal(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(127, 0, 0, 0),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                strokeAlign: BorderSide.strokeAlignInside,
                width: 3,
                color: getBorderColor(ref),
              ),
            ),
            child: Stack(
              children: [
                if (ref.watch(windowIsPinnedProvider) &&
                    ref.watch(tabIndexProvider) == 1 &&
                    !ref.watch(alertDialogShownProvider) &&
                    ref.watch(validModsPath) != null &&
                    ref.watch(modGroupDataProvider).isNotEmpty)
                  ModsDropZone(
                    checkForMaxMods: true,
                    currentModsCountInGroup:
                        ref
                            .watch(modGroupDataProvider)[ref.watch(
                              currentGroupIndexProvider,
                            )]
                            .modsInGroup
                            .length,
                    dialogTitleText: "Add mods",
                    onConfirmFunction: _onModAddConfirm,
                    copyDestination:
                        ref
                            .watch(modGroupDataProvider)[ref.watch(
                              currentGroupIndexProvider,
                            )]
                            .groupDir
                            .path,
                  ),
                RightClickMenuWrapper(
                  menuItems: [
                    if (ref.watch(tabIndexProvider) == 1 &&
                        ref.watch(modGroupDataProvider).isEmpty)
                      PopupMenuItem(
                        height: 37,
                        onTap: () async {
                          await addGroup(
                            ref,
                            p.join(
                              getCurrentModsPath(ref.read(targetGameProvider)),
                              ConstantVar.managedFolderName,
                            ),
                          );
                        },
                        value: 'Add group',
                        child: Text(
                          'Add group',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (ref.watch(tabIndexProvider) != 2)
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
                    if (ref.watch(tabIndexProvider) == 0)
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
                  child: MoveWindow(onDoubleTap: () {}),
                ),
                MainView(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainView extends ConsumerStatefulWidget {
  const MainView({super.key});

  @override
  ConsumerState<MainView> createState() => _MainViewState();
}

class _MainViewState extends ConsumerState<MainView>
    with WindowListener, SingleTickerProviderStateMixin, ModNavigationListener {
  late TabController _tabController;
  final List<SegmentTab> _tabs = [
    SegmentTab(label: "Keybinds"),
    SegmentTab(label: "Mods"),
    SegmentTab(label: "Settings"),
  ];

  List<Widget> _views = [TabKeybinds(), TabModsLoading(), TabSettings()];

  @override
  void onWindowBlur() {
    checkToHideWindow();
    super.onWindowBlur();
  }

  void setupGamepadNavigation() {
    XInputManager.enableXInput();
    final Controller controller = Controller(
      index: 0,
      buttonsCombination: {
        {ControllerButton.LEFT_THUMB, ControllerButton.B_BUTTON}: () {
          if (ref.read(hotkeyGamepadProvider) == HotkeyGamepad.lsB) {
            toggleWindow();
          }
        },
        {ControllerButton.LEFT_THUMB, ControllerButton.A_BUTTON}: () {
          if (ref.read(hotkeyGamepadProvider) == HotkeyGamepad.lsA) {
            toggleWindow();
          }
        },
        {ControllerButton.LEFT_THUMB, ControllerButton.RIGHT_SHOULDER}: () {
          if (ref.read(hotkeyGamepadProvider) == HotkeyGamepad.lsRb) {
            toggleWindow();
          }
        },
      },
    );
    controller.leftVibrationSpeed = 56535;
    controller.rightVibrationSpeed = 56535;
    controller.buttonsMapping = {
      ControllerButton.A_BUTTON: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyF,
              logicalKey: LogicalKeyboardKey.keyF,
              timeStamp: Duration(),
            ),
            controller,
          );
        }
      },
      ControllerButton.DPAD_UP: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyW,
              logicalKey: LogicalKeyboardKey.keyW,
              timeStamp: Duration(),
            ),
            controller,
          );
        }
      },
      ControllerButton.DPAD_DOWN: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyS,
              logicalKey: LogicalKeyboardKey.keyS,
              timeStamp: Duration(),
            ),
            controller,
          );
        }
      },
      ControllerButton.DPAD_LEFT: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyA,
              logicalKey: LogicalKeyboardKey.keyA,
              timeStamp: Duration(),
            ),
            controller,
          );
        }
      },
      ControllerButton.DPAD_RIGHT: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyD,
              logicalKey: LogicalKeyboardKey.keyD,
              timeStamp: Duration(),
            ),
            controller,
          );
        }
      },
      ControllerButton.LEFT_SHOULDER: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyQ,
              logicalKey: LogicalKeyboardKey.keyQ,
              timeStamp: Duration(),
            ),
            controller,
          );
        }
      },
      ControllerButton.RIGHT_SHOULDER: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyE,
              logicalKey: LogicalKeyboardKey.keyE,
              timeStamp: Duration(),
            ),
            controller,
          );
        }
      },
    };
    controller.listen();
  }

  Future<void> loadNetworkDatas() async {
    precacheImage(
      NetworkImage(ConstantVar.urlSupportIcon),
      context,
      onError: (exception, stackTrace) {},
    );
    precacheImage(
      NetworkImage(ConstantVar.urlSupportIconOnHover),
      context,
      onError: (exception, stackTrace) {},
    );
    precacheImage(
      NetworkImage(ConstantVar.urlTutorialIcon),
      context,
      onError: (exception, stackTrace) {},
    );
    precacheImage(
      NetworkImage(ConstantVar.urlTutorialIconOnHover),
      context,
      onError: (exception, stackTrace) {},
    );
    if (ref.read(supportLinkProvider).isEmpty) {
      ref.read(supportLinkProvider.notifier).state = await CloudData()
          .loadTextFromCloud(
            ConstantVar.urlToGetSupportLink,
            "https://ko-fi.com/agulagula",
          );
    }
    if (ref.read(tutorialLinkProvider).isEmpty) {
      ref.read(tutorialLinkProvider.notifier).state = await CloudData()
          .loadTextFromCloud(
            ConstantVar.urlToGetTutorialLink,
            "https://gamebanana.com/mods/582623",
          );
    }
  }

  Future<void> initSystemTray() async {
    final SystemTray systemTray = SystemTray();

    // We first init the systray menu
    await systemTray.initSystemTray(
      title: "system tray",
      toolTip: 'Mod Manager for Gacha Games',
      iconPath:
          Platform.isWindows
              ? 'assets/images/app_icon.ico'
              : 'assets/images/app_icon.png',
    );

    // create context menu
    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show (WuWa)',
        onClicked: (menuItem) async {
          if (!ref.read(alertDialogShownProvider)) {
            ref.read(targetGameProvider.notifier).state =
                TargetGame.Wuthering_Waves;
          }
          ref.read(windowIsPinnedProvider.notifier).state = true;
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuItemLabel(
        label: 'Show (Genshin)',
        onClicked: (menuItem) async {
          if (!ref.read(alertDialogShownProvider)) {
            ref.read(targetGameProvider.notifier).state =
                TargetGame.Genshin_Impact;
          }
          ref.read(windowIsPinnedProvider.notifier).state = true;
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuItemLabel(
        label: 'Show (HSR)',
        onClicked: (menuItem) async {
          if (!ref.read(alertDialogShownProvider)) {
            ref.read(targetGameProvider.notifier).state =
                TargetGame.Honkai_Star_Rail;
          }
          ref.read(windowIsPinnedProvider.notifier).state = true;
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuItemLabel(
        label: 'Show (ZZZ)',
        onClicked: (menuItem) async {
          if (!ref.read(alertDialogShownProvider)) {
            ref.read(targetGameProvider.notifier).state =
                TargetGame.Zenless_Zone_Zero;
          }
          ref.read(windowIsPinnedProvider.notifier).state = true;
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(label: 'Hide', onClicked: (menuItem) => appWindow.hide()),
      MenuSeparator(),
      MenuItemLabel(label: 'Exit', onClicked: (menuItem) => exit(0)),
    ]);

    // set context menu
    await systemTray.setContextMenu(menu);

    // handle system tray event
    systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        systemTray.popUpContextMenu();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    setupGamepadNavigation();
    ModNavigationListener.addListener(this);

    ref.listenManual(targetGameProvider, (previous, next) {
      checkIsModsPathValidAndReady();
    });

    ref.listenManual(
      hotkeyKeyboardProvider,
      (prevHotkey, newHotkey) =>
          hotkeyKeyboardChanged(prevHotkey, newHotkey, toggleWindow),
    );
    hotkeyKeyboardChanged(null, ref.read(hotkeyKeyboardProvider), toggleWindow);

    initSystemTray();
    windowManager.addListener(this);

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: ref.read(tabIndexProvider),
    );
    _tabController.addListener(() {
      ref.read(tabIndexProvider.notifier).state = _tabController.index;
      FocusScope.of(context).unfocus();
      if (_tabController.index == 1 && _tabController.indexIsChanging == true) {
        checkIsModsPathValidAndReady();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadNetworkDatas();
    });
    ref.listenManual(targetGameProvider, checkToShowInfoMessage);

    ref.listenManual(modKeybindProvider, (previous, next) {
      if (next != null) {
        _tabController.animateTo(0);
      }
    });
  }

  Future<void> checkToShowInfoMessage(
    TargetGame? prevTargetGame,
    TargetGame targetGame,
  ) async {
    if (targetGame == TargetGame.none) return;

    String rawMessage = "";
    String message = "";
    String detailUrl = "";
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    switch (targetGame) {
      case TargetGame.Wuthering_Waves:
        if (!ref.read(messageWuwaDismissedProvider)) {
          rawMessage = await CloudData().loadTextFromCloud(
            ConstantVar.urlMessageWuwa,
            "",
          );
          List<String> splittedInput = rawMessage.split("||").toList();
          message = splittedInput[0].trim();
          if (splittedInput.length == 2) {
            detailUrl = splittedInput[1].trim();
          }
          showInfoMessage(message, TargetGame.Wuthering_Waves, detailUrl);
        }
        break;
      case TargetGame.Genshin_Impact:
        if (!ref.read(messageGenshinDismissedProvider)) {
          rawMessage = await CloudData().loadTextFromCloud(
            ConstantVar.urlMessageGenshin,
            "",
          );
          List<String> splittedInput = rawMessage.split("||").toList();
          message = splittedInput[0].trim();
          if (splittedInput.length == 2) {
            detailUrl = splittedInput[1].trim();
          }
          showInfoMessage(message, TargetGame.Genshin_Impact, detailUrl);
        }
        break;
      case TargetGame.Honkai_Star_Rail:
        if (!ref.read(messageHsrDismissedProvider)) {
          rawMessage = await CloudData().loadTextFromCloud(
            ConstantVar.urlMessageHsr,
            "",
          );
          List<String> splittedInput = rawMessage.split("||").toList();
          message = splittedInput[0].trim();
          if (splittedInput.length == 2) {
            detailUrl = splittedInput[1].trim();
          }
          showInfoMessage(message, TargetGame.Honkai_Star_Rail, detailUrl);
        }
        break;
      case TargetGame.Zenless_Zone_Zero:
        if (!ref.read(messageZzzDismissedProvider)) {
          rawMessage = await CloudData().loadTextFromCloud(
            ConstantVar.urlMessageZzz,
            "",
          );
          List<String> splittedInput = rawMessage.split("||").toList();
          message = splittedInput[0].trim();
          if (splittedInput.length == 2) {
            detailUrl = splittedInput[1].trim();
          }
          showInfoMessage(message, TargetGame.Zenless_Zone_Zero, detailUrl);
        }
        break;
      default:
        break;
    }
  }

  void showInfoMessage(
    String message,
    TargetGame targetGame,
    String urlDetails,
  ) {
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF2B2930),
              margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
              duration: Duration(days: 1),
              behavior: SnackBarBehavior.floating,
              closeIconColor: Colors.blue,
              showCloseIcon: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.yellow, fontSize: 13),
              ),
              action:
                  urlDetails.isNotEmpty
                      ? SnackBarAction(
                        textColor: Colors.blue,
                        label: "Details",
                        onPressed: () async {
                          try {
                            if (!await launchUrl(Uri.parse(urlDetails))) {}
                          } catch (e) {}
                        },
                      )
                      : null,
              dismissDirection: DismissDirection.none,
            ),
          )
          .closed
          .then((reason) {
            if (reason == SnackBarClosedReason.action ||
                reason == SnackBarClosedReason.dismiss) {
              switch (targetGame) {
                case TargetGame.Wuthering_Waves:
                  ref.read(messageWuwaDismissedProvider.notifier).state = true;
                  break;
                case TargetGame.Genshin_Impact:
                  ref.read(messageGenshinDismissedProvider.notifier).state =
                      true;
                  break;
                case TargetGame.Honkai_Star_Rail:
                  ref.read(messageHsrDismissedProvider.notifier).state = true;
                  break;
                case TargetGame.Zenless_Zone_Zero:
                  ref.read(messageZzzDismissedProvider.notifier).state = true;
                  break;
                default:
                  break;
              }
            }
          });
    }
  }

  Future<void> checkIsModsPathValidAndReady() async {
    String? previousModsPath = ref.read(validModsPath);
    if (previousModsPath != null) {
      int prevGroupIndex = ref.read(currentGroupIndexProvider);
      setSelectedGroupIndex(
        prevGroupIndex,
        p.join(previousModsPath, ConstantVar.managedFolderName),
      );
    }

    ImageRefreshListener.refreshImages(ref.read(modGroupDataProvider));

    ref.read(validModsPath.notifier).state = null;

    setState(() {
      _views = [TabKeybinds(), TabModsLoading(), TabSettings()];
    });
    ref.read(currentGroupIndexProvider.notifier).state = 0;
    TargetGame targetGame = ref.read(targetGameProvider);
    if (targetGame == TargetGame.none) return;

    String modsPath = getCurrentModsPath(targetGame);
    bool existAndValid = false;
    String notReadyReason = "";

    if (!await Directory(modsPath).exists()) {
      existAndValid = false;
      notReadyReason = "Mods path does not exist.";
    } else if (modsPath.toLowerCase().endsWith('mods') ||
        modsPath.toLowerCase().endsWith('mods\\')) {
      existAndValid = true;
    } else {
      existAndValid = false;
      notReadyReason = "Mods path invalid.";
    }

    if (existAndValid) {
      String managedPath = p.join(modsPath, ConstantVar.managedFolderName);
      String backgroundKeypressPath = p.join(
        managedPath,
        ConstantVar.backgroundKeypressFileName,
      );
      String managerGroupPath = p.join(
        managedPath,
        ConstantVar.managerGroupFileName,
      );

      //Check managed folder
      if (!await Directory(managedPath).exists()) {
        existAndValid = false;
        notReadyReason =
            "Mods path is correct, but managed folder cannot be found or still old version.";
      }
      //Check background_keypress.ini
      else if (!await File(backgroundKeypressPath).exists()) {
        existAndValid = false;
        notReadyReason =
            "Mods path is correct, but some requirement is missing.";
      }
      //Check manager_group.ini
      else if (!await File(managerGroupPath).exists()) {
        existAndValid = false;
        notReadyReason =
            "Mods path is correct, but some requirement is missing.";
      }

      if (existAndValid) {
        ref.read(modGroupDataProvider.notifier).state = await refreshModData(
          Directory(managedPath),
        );
        ref.read(validModsPath.notifier).state = modsPath;
        int groupIndex = await getSelectedGroupIndex(
          managedPath,
          ref.read(modGroupDataProvider).length,
        );
        ref.read(currentGroupIndexProvider.notifier).state = groupIndex;

        DynamicDirectoryWatcher.watch(managedPath, ref: ref);
      } else {
        DynamicDirectoryWatcher.stop();
      }
    }

    //Sometimes widget don't rebuild/don't show loading screen because loading time was too fast
    await Future.delayed(Duration(milliseconds: 10));

    setState(() {
      existAndValid
          ? _views = [TabKeybinds(), TabMods(), TabSettings()]
          : _views = [
            TabKeybinds(),
            TabModsNotReady(notReadyReason: notReadyReason),
            TabSettings(),
          ];
    });
  }

  @override
  Future<void> dispose() async {
    windowManager.removeListener(this);
    ModNavigationListener.removeListener(this);
    hotKeyManager.unregisterAll();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> toggleWindow() async {
    if (await windowManager.isVisible()) {
      if (!ref.read(alertDialogShownProvider)) {
        ref.read(targetGameProvider.notifier).state = TargetGame.none;
      }
      await windowManager.hide();
      DynamicDirectoryWatcher.stop();
    } else {
      String foregroundProcessName = getForegroundWindowProcessName();
      if (foregroundProcessName == SharedPrefUtils().getWuwaTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Wuthering_Waves;
        }
        ref.read(windowIsPinnedProvider.notifier).state = false;
        await windowManager.show();
        await windowManager.focus();
      } else if (foregroundProcessName ==
          SharedPrefUtils().getGenshinTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Genshin_Impact;
        }
        ref.read(windowIsPinnedProvider.notifier).state = false;
        await windowManager.show();
        await windowManager.focus();
      } else if (foregroundProcessName ==
          SharedPrefUtils().getHsrTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Honkai_Star_Rail;
        }
        ref.read(windowIsPinnedProvider.notifier).state = false;
        await windowManager.show();
        await windowManager.focus();
      } else if (foregroundProcessName ==
          SharedPrefUtils().getZzzTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Zenless_Zone_Zero;
        }
        ref.read(windowIsPinnedProvider.notifier).state = false;
        await windowManager.show();
        await windowManager.focus();
      }
    }
  }

  Future<void> checkToHideWindow() async {
    if (!ref.read(windowIsPinnedProvider)) {
      if (!ref.read(alertDialogShownProvider)) {
        ref.read(targetGameProvider.notifier).state = TargetGame.none;
      }
      await windowManager.hide();
      DynamicDirectoryWatcher.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ///Tab views
        IndexedStack(index: ref.watch(tabIndexProvider), children: _views),

        ///Tab bars
        Padding(
          padding: const EdgeInsets.only(top: 25),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 350,

              child: SegmentedTabControl(
                controller: _tabController,
                height: 42,
                selectedTabTextColor: Colors.black,
                tabTextColor: Colors.white,
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                indicatorDecoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                barDecoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: const Color.fromARGB(127, 255, 255, 255),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                tabs: _tabs,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void onKeyEvent(KeyEvent value, Controller? controller) {
    if (value.physicalKey == PhysicalKeyboardKey.keyE &&
        _tabController.index != 2) {
      _tabController.animateTo(_tabController.index + 1);
    } else if (value.physicalKey == PhysicalKeyboardKey.keyQ &&
        _tabController.index != 0) {
      _tabController.animateTo(_tabController.index - 1);
    }
  }
}

class CustomKeyEvent extends KeyEvent {
  const CustomKeyEvent({
    required super.physicalKey,
    required super.logicalKey,
    required super.timeStamp,
  });
}
