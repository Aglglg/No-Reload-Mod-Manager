//Sorry the code is messy.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:no_reload_mod_manager/utils/auto_group_icon.dart';
import 'package:no_reload_mod_manager/utils/check_admin_privillege.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/get_cloud_data.dart';
import 'package:no_reload_mod_manager/utils/hotkey_handler.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulate.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_navigator.dart';
import 'package:no_reload_mod_manager/utils/mods_dropzone.dart';
import 'package:no_reload_mod_manager/utils/refreshable_image.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:no_reload_mod_manager/utils/ui_dialogues.dart';
import 'package:path/path.dart' as p;

import 'package:bitsdojo_window/bitsdojo_window.dart' as bitsdojo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/tabs/keybinds_tab.dart';
import 'package:no_reload_mod_manager/tabs/mods_tab.dart';
import 'package:no_reload_mod_manager/tabs/settings_tab.dart';
import 'package:no_reload_mod_manager/utils/get_process_name.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_tray/system_tray.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';
import 'package:animated_segmented_tab_control/animated_segmented_tab_control.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'package:flutter/material.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:xinput_gamepad/xinput_gamepad.dart';

import 'package:easy_localization/easy_localization.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  bool successLoadPref = await SharedPrefUtils().tryInit();
  await EasyLocalization.ensureInitialized();
  await setupWindow(args);
  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: [
          Locale('en'),
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
          Locale('id'),
          Locale('ru'),
        ],
        path: 'assets/translations',
        fallbackLocale: Locale('en'),
        child: MyApp(successLoadPref: successLoadPref),
      ),
    ),
  );
}

Future<void> initializeAndShowNotification() async {
  try {
    if (!Platform.isWindows) return;
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    //Cannot use something like 'assets/images/app_icon.ico"
    final String iconPath = p.join(
      p.dirname(Platform.resolvedExecutable),
      r"data\flutter_assets\assets\images\app_icon.ico",
    );

    final WindowsInitializationSettings
    initializationSettingsWindows = WindowsInitializationSettings(
      appName: 'No Reload Mod Manager',
      appUserModelId: 'com.aglg.NoReloadModManager',
      //guid same as app id from inno setup (\windows\packaging\exe\make_config.yaml)
      guid: 'DF5B0F87-8365-499D-B8B3-58211FBF6F2A',
      iconPath: iconPath,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(windows: initializationSettingsWindows);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const WindowsNotificationDetails windowsNotificationDetails =
        WindowsNotificationDetails(duration: WindowsNotificationDuration.short);
    const NotificationDetails notificationDetails = NotificationDetails(
      windows: windowsNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      'No Reload Mod Manager is running'.tr(),
      'Access it from Tray or Alt+W(default) while in your target game'.tr(),
      notificationDetails,
    );
  } catch (_) {}
}

Future<void> relaunchAsNormalUser() async {
  final exePath = Platform.resolvedExecutable;

  await Process.start('explorer.exe', [
    exePath,
  ], mode: ProcessStartMode.detached);
  exit(0);
}

Future<void> checkToRelaunch({bool forcedRelaunch = false}) async {
  final String relaunchFlagPath = p.join(
    Directory.systemTemp.path,
    "nrmm_relaunched",
  );

  bool wasRelaunched = await File(relaunchFlagPath).exists();
  if ((isRunningAsAdmin() && !wasRelaunched) || forcedRelaunch) {
    try {
      await File(relaunchFlagPath).writeAsString('1');
      await relaunchAsNormalUser();
      exit(0);
    } catch (_) {}
  } else if (wasRelaunched) {
    try {
      await File(relaunchFlagPath).delete();
    } catch (_) {}
  }
}

Future<void> setupWindow(List<String> args) async {
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  await WindowsSingleInstance.ensureSingleInstance(
    args,
    "no_reload_mod_manager",
    onSecondWindow: (args) {
      for (var element in args) {
        print(element);
      }
    },
    bringWindowToFront:
        false, //IMPORTANT, or else it will mess up with always on top or it will be hidden even when it's pinned or blue outline/border, IDK why
  );

  await checkToRelaunch();

  String feedURL =
      'https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/appcast.xml';
  await autoUpdater.setFeedURL(feedURL);
  await autoUpdater.setScheduledCheckInterval(0);

  bitsdojo.doWhenWindowReady(() async {
    final minSize = Size(
      750 * SharedPrefUtils().getOverallScale(),
      370 * SharedPrefUtils().getOverallScale(),
    );

    Size? savedSize = SharedPrefUtils().getSavedWindowSize();

    savedSize ??= minSize;

    double savedSizeWidth =
        savedSize.width < minSize.width ? minSize.width : savedSize.width;
    double savedSizeHeight =
        savedSize.height < minSize.height ? minSize.height : savedSize.height;

    savedSize = Size(savedSizeWidth, savedSizeHeight);

    bitsdojo.appWindow.minSize = minSize;
    bitsdojo.appWindow.size = savedSize;
    bitsdojo.appWindow.alignment = Alignment.center;

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

class MyApp extends ConsumerStatefulWidget {
  final bool successLoadPref;
  const MyApp({super.key, required this.successLoadPref});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WindowListener {
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    onWindowResize();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _resizeDebounce?.cancel();
    super.dispose();
  }

  @override
  void onWindowResize() {
    debouncedSaveWindowSize();
  }

  Timer? _resizeDebounce;
  void debouncedSaveWindowSize() {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 500), () async {
      SharedPrefUtils().setSavedWindow(await windowManager.getSize());
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      onKeyEvent: (value) {
        if (value is KeyUpEvent ||
            ref.read(alertDialogShownProvider) ||
            ref.read(popupMenuShownProvider)) {
        } else {
          ModNavigationListener.notifyListeners(value, null);
        }

        //Fix stuck on windows menu when press Alt
        if ((value.physicalKey == PhysicalKeyboardKey.altLeft ||
                value.physicalKey == PhysicalKeyboardKey.altRight) &&
            value is KeyUpEvent) {
          simulateKeyDown(VK_ESCAPE);
          simulateKeyUp(VK_ESCAPE);
          focusNode.requestFocus();
        }
      },
      focusNode: focusNode,
      autofocus: true,
      child: MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        debugShowCheckedModeBanner: false,
        home: Background(successLoadPref: widget.successLoadPref),
        theme: ThemeData.dark(),
      ),
    );
  }
}

class Background extends ConsumerStatefulWidget {
  final bool successLoadPref;
  const Background({super.key, required this.successLoadPref});

  @override
  ConsumerState<Background> createState() => _BackgroundState();
}

class _BackgroundState extends ConsumerState<Background> {
  @override
  void initState() {
    super.initState();
    if (!widget.successLoadPref) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) => PrefCorruptedDialog(),
        );
      });
    }
  }

  Color getBorderColor(WidgetRef ref) {
    if (ref.watch(windowIsPinnedProvider)) {
      return const Color.fromARGB(255, 33, 149, 243);
    } else {
      return const Color.fromARGB(127, 255, 255, 255);
    }
  }

  void _onModAddConfirm(List<Directory> modDirs, List<File> modArchives) {
    String? modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      ref.read(alertDialogShownProvider.notifier).state = true;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder:
            (context) => CopyModDialog(
              modDirs: modDirs,
              modArchives: modArchives,
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
    final sss = ref.watch(zoomScaleProvider);
    return ExcludeFocusTraversal(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Container(
            decoration: BoxDecoration(
              color: Color.fromARGB(ref.watch(bgTransparencyProvider), 0, 0, 0),
              borderRadius: BorderRadius.circular(30 * sss),
              border: Border.all(
                strokeAlign: BorderSide.strokeAlignInside,
                width: 3 * sss,
                color: getBorderColor(ref),
              ),
            ),
            child: Stack(
              children: [
                if (ref.watch(tabIndexProvider) == 1 &&
                    !ref.watch(alertDialogShownProvider) &&
                    ref.watch(validModsPath) != null &&
                    ref.watch(modGroupDataProvider).isNotEmpty)
                  ModsDropZone(
                    acceptArchived: true,
                    checkForMaxMods: true,
                    currentModsCountInGroup:
                        ref
                            .watch(modGroupDataProvider)[ref.watch(
                              currentGroupIndexProvider,
                            )]
                            .modsInGroup
                            .length,
                    dialogTitleText: "Add mods".tr(),
                    onConfirmFunction: _onModAddConfirm,
                    copyDestination:
                        ref
                            .watch(modGroupDataProvider)[ref.watch(
                              currentGroupIndexProvider,
                            )]
                            .groupDir
                            .path,
                  ),
                RightClickMenuRegion(
                  menuItems: <ContextMenuEntry>[
                    if (ref.watch(tabIndexProvider) == 1 &&
                        ref.watch(modGroupDataProvider).isEmpty)
                      CustomMenuItem(
                        scale: sss,
                        onSelected: () async {
                          await addGroup(
                            ref,
                            p.join(
                              getCurrentModsPath(ref.read(targetGameProvider)),
                              ConstantVar.managedFolderName,
                            ),
                          );
                        },
                        label: 'Add group'.tr(),
                      ),
                    if (ref.watch(tabIndexProvider) != 2)
                      CustomMenuItem(
                        scale: sss,
                        onSelected: () async {
                          triggerRefresh(ref);
                        },
                        label: 'Refresh'.tr(),
                      ),
                    if (ref.watch(tabIndexProvider) == 1 &&
                        ref.watch(modGroupDataProvider).isNotEmpty)
                      CustomMenuItem(
                        scale: sss,
                        onSelected: () {
                          ref.read(searchBarShownProvider.notifier).state =
                              true;
                        },
                        label: 'Search'.tr(),
                      ),
                    if (ref.watch(tabIndexProvider) == 1)
                      CustomMenuItem.submenu(
                        scale: sss,
                        items: [
                          CustomMenuItem(
                            leftIcon: Icons.laptop_windows_outlined,
                            rightIcon:
                                ref.watch(layoutModeProvider) == 0
                                    ? Icons.check
                                    : null,
                            label: 'Auto'.tr(),
                            scale: sss,
                            onSelected: () {
                              SharedPrefUtils().setLayoutMode(0);
                              ref.read(layoutModeProvider.notifier).state = 0;
                            },
                          ),
                          CustomMenuItem(
                            leftIcon: Icons.view_carousel_outlined,
                            rightIcon:
                                ref.watch(layoutModeProvider) == 1
                                    ? Icons.check
                                    : null,
                            label: 'Carousel'.tr(),
                            scale: sss,
                            onSelected: () {
                              SharedPrefUtils().setLayoutMode(1);
                              ref.read(layoutModeProvider.notifier).state = 1;
                              ref.read(isCarouselProvider.notifier).state =
                                  true;
                            },
                          ),
                          CustomMenuItem(
                            leftIcon: Icons.window_outlined,
                            rightIcon:
                                ref.watch(layoutModeProvider) == 2
                                    ? Icons.check
                                    : null,
                            label: 'Grid'.tr(),
                            scale: sss,
                            onSelected: () {
                              SharedPrefUtils().setLayoutMode(2);
                              ref.read(layoutModeProvider.notifier).state = 2;
                              ref.read(isCarouselProvider.notifier).state =
                                  false;
                            },
                          ),
                        ],
                        label: 'Layout'.tr(),
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

                    if (ref.watch(tabIndexProvider) == 0)
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
                  ],
                  child: bitsdojo.MoveWindow(onDoubleTap: () {}),
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

  List<Widget> _views = [TabKeybinds(), TabModsLoading(), TabSettings()];

  @override
  void onWindowBlur() {
    checkToHideWindow();
    super.onWindowBlur();
  }

  Future<void> resetLeftThumbGamepad() async {
    await Future.delayed(Duration(milliseconds: 180));
    ref.read(leftThumbWasTriggered.notifier).state = false;
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
        {ControllerButton.BACK, ControllerButton.START}: () {
          if (ref.read(hotkeyGamepadProvider) == HotkeyGamepad.selectStart) {
            toggleWindow();
          }
        },
        {ControllerButton.LEFT_THUMB, ControllerButton.RIGHT_THUMB}: () {
          if (ref.read(hotkeyGamepadProvider) == HotkeyGamepad.lsRs) {
            toggleWindow();
          }
        },
      },
    );
    controller.leftVibrationSpeed = 56535;
    controller.rightVibrationSpeed = 56535;
    controller.variableKeysMapping = {
      VariableControllerKey.THUMB_LX: (v) {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider) &&
            !ref.read(leftThumbWasTriggered)) {
          if (v >= 30000) {
            ModNavigationListener.notifyListeners(
              CustomKeyEvent(
                physicalKey: PhysicalKeyboardKey.keyD,
                logicalKey: LogicalKeyboardKey.keyD,
                timeStamp: Duration(),
              ),
              controller,
            );
            ref.read(leftThumbWasTriggered.notifier).state = true;
          } else if (v <= -30000) {
            ModNavigationListener.notifyListeners(
              CustomKeyEvent(
                physicalKey: PhysicalKeyboardKey.keyA,
                logicalKey: LogicalKeyboardKey.keyA,
                timeStamp: Duration(),
              ),
              controller,
            );
            ref.read(leftThumbWasTriggered.notifier).state = true;
          }
        }
      },
      VariableControllerKey.THUMB_LY: (v) {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider) &&
            !ref.read(leftThumbWasTriggered)) {
          if (v >= 30000) {
            ModNavigationListener.notifyListeners(
              CustomKeyEvent(
                physicalKey: PhysicalKeyboardKey.keyW,
                logicalKey: LogicalKeyboardKey.keyW,
                timeStamp: Duration(),
              ),
              controller,
            );
            ref.read(leftThumbWasTriggered.notifier).state = true;
          } else if (v <= -30000) {
            ModNavigationListener.notifyListeners(
              CustomKeyEvent(
                physicalKey: PhysicalKeyboardKey.keyS,
                logicalKey: LogicalKeyboardKey.keyS,
                timeStamp: Duration(),
              ),
              controller,
            );
            ref.read(leftThumbWasTriggered.notifier).state = true;
          }
        }
      },
    };
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
      ControllerButton.X_BUTTON: () {
        if (!ref.read(alertDialogShownProvider) &&
            !ref.read(popupMenuShownProvider)) {
          ModNavigationListener.notifyListeners(
            CustomKeyEvent(
              physicalKey: PhysicalKeyboardKey.keyR,
              logicalKey: LogicalKeyboardKey.keyR,
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
    precacheImage(
      NetworkImage(ConstantVar.urlContactIcon),
      context,
      onError: (exception, stackTrace) {},
    );
    precacheImage(
      NetworkImage(ConstantVar.urlContactIconOnHover),
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
            "https://youtu.be/mBO9KEc6LA8",
          );
    }
    if (ref.read(contactLinkProvider).isEmpty) {
      ref.read(contactLinkProvider.notifier).state = await CloudData()
          .loadTextFromCloud(
            ConstantVar.urlToGetContactLink,
            "https://discord.com",
          );
    }
    ref.read(autoIconProvider.notifier).state = await fetchGroupIconData();
  }

  Future<void> initSystemTray() async {
    final SystemTray systemTray = SystemTray();

    // We first init the systray menu
    await systemTray.initSystemTray(
      title: "system tray",
      toolTip: 'Mod Manager for Gacha Games'.tr(),
      iconPath:
          Platform.isWindows
              ? 'assets/images/app_icon.ico'
              : 'assets/images/app_icon.png',
    );

    // create context menu
    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show (WuWa)'.tr(),
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
        label: 'Show (Genshin)'.tr(),
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
        label: 'Show (HSR)'.tr(),
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
        label: 'Show (ZZZ)'.tr(),
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
      MenuItemLabel(
        label: "${'Reset Position'.tr()} (Alt+T)",
        onClicked: (menuItem) async {
          await windowManager.center();
        },
      ),
      MenuItemLabel(
        label: 'Hide'.tr(),
        onClicked: (menuItem) => bitsdojo.appWindow.hide(),
      ),
      MenuSeparator(),
      MenuItemLabel(label: 'Exit'.tr(), onClicked: (menuItem) => exit(0)),
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

    ref.listenManual(leftThumbWasTriggered, (previous, next) {
      if (next == true) {
        resetLeftThumbGamepad();
      }
    });

    ref.listenManual(targetGameProvider, (previous, next) {
      checkIsModsPathValidAndReady();
    });

    ref.listenManual(
      hotkeyKeyboardProvider,
      (prevHotkey, newHotkey) =>
          hotkeyKeyboardChanged(prevHotkey, newHotkey, toggleWindow),
    );
    hotkeyKeyboardChanged(null, ref.read(hotkeyKeyboardProvider), toggleWindow);
    registerHotkeyResetWindowPos();

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      loadNetworkDatas();
      await initSystemTray();

      //show notif only after system tray loaded successfully
      await initializeAndShowNotification();
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

    if (SharedPrefUtils().currentTargetGameNeedUpdateMod(targetGame)) {
      showUpdateModSnackbar(
        context,
        ProviderScope.containerOf(context, listen: false),
      );
    } else {
      try {
        try {
          final listAnimController = ref.read(animControllerSpecialSnackbar);
          for (var controller in listAnimController) {
            try {
              controller.reverse();
            } catch (_) {}
          }
        } catch (_) {}
      } catch (_) {}
    }

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
                style: GoogleFonts.poppins(
                  color: Colors.yellow,
                  fontSize: 13 * ref.read(zoomScaleProvider),
                ),
              ),
              action:
                  urlDetails.isNotEmpty
                      ? SnackBarAction(
                        textColor: Colors.blue,
                        label: "Details".tr(),
                        onPressed: () async {
                          try {
                            if (!await launchUrl(Uri.parse(urlDetails))) {}
                          } catch (_) {}
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
    ref.read(searchBarShownProvider.notifier).state = false;

    setState(() {
      _views = [TabKeybinds(), TabModsLoading(), TabSettings()];
    });
    ref.read(currentGroupIndexProvider.notifier).state = 0;
    TargetGame targetGame = ref.read(targetGameProvider);
    if (targetGame == TargetGame.none) return;

    String modsPath = getCurrentModsPath(targetGame);
    bool existAndValid = false;
    String notReadyReason = "";

    try {
      if (!await Directory(modsPath).exists()) {
        existAndValid = false;
        notReadyReason = "Mods path does not exist.".tr();
      } else if (modsPath.toLowerCase().endsWith('mods') ||
          modsPath.toLowerCase().endsWith('mods\\')) {
        existAndValid = true;
      } else {
        existAndValid = false;
        notReadyReason = "Mods path invalid.".tr();
      }
    } catch (_) {
      existAndValid = false;
      notReadyReason = "Mods path invalid.".tr();
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
            "Mods path is correct, but the '_MANAGED_' folder is missing or outdated."
                .tr();
      }
      //Check background_keypress.ini
      else if (!await File(backgroundKeypressPath).exists()) {
        existAndValid = false;
        notReadyReason =
            "Mods path is correct, but some requirements are missing.".tr();
      }
      //Check manager_group.ini
      else if (!await File(managerGroupPath).exists()) {
        existAndValid = false;
        notReadyReason =
            "Mods path is correct, but some requirements are missing.".tr();
      }

      //Check for ini configuration version
      if (existAndValid) {
        String managedPath = p.join(modsPath, ConstantVar.managedFolderName);

        String managerGroupPath = p.join(
          managedPath,
          ConstantVar.managerGroupFileName,
        );
        final firstLine = await readFirstLine(managerGroupPath);
        if (firstLine?.trim() != ";revision_3") {
          existAndValid = false;
          notReadyReason =
              "Everything is correct, but config files are outdated.".tr();
        }
      }

      if (existAndValid) {
        //Load mod & group datas
        final datas = await refreshModData(Directory(managedPath));

        ref.read(sortGroupMethod.notifier).state =
            SharedPrefUtils().getGroupSort();

        if (ref.read(sortGroupMethod) == 1) {
          datas.sort((a, b) => a.groupName.compareTo(b.groupName));
        }

        ref.read(modGroupDataProvider.notifier).state = datas;

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
      bool autoPinWindow = ref.read(isAutoPinWindowProvider);
      if (foregroundProcessName == SharedPrefUtils().getWuwaTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Wuthering_Waves;
        }
        ref.read(windowIsPinnedProvider.notifier).state = autoPinWindow;
        await windowManager.show();
        await windowManager.focus();
      } else if (foregroundProcessName ==
          SharedPrefUtils().getGenshinTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Genshin_Impact;
        }
        ref.read(windowIsPinnedProvider.notifier).state = autoPinWindow;
        await windowManager.show();
        await windowManager.focus();
      } else if (foregroundProcessName ==
          SharedPrefUtils().getHsrTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Honkai_Star_Rail;
        }
        ref.read(windowIsPinnedProvider.notifier).state = autoPinWindow;
        await windowManager.show();
        await windowManager.focus();
      } else if (foregroundProcessName ==
          SharedPrefUtils().getZzzTargetProcess()) {
        if (!ref.read(alertDialogShownProvider)) {
          ref.read(targetGameProvider.notifier).state =
              TargetGame.Zenless_Zone_Zero;
        }
        ref.read(windowIsPinnedProvider.notifier).state = autoPinWindow;
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

  Future<String?> readFirstLine(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) return null;

    // Open file as a stream of bytes
    final stream = file.openRead();

    // Decode bytes to UTF-8 text, split into lines
    final lines = stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    // Return the first line
    try {
      return await lines.first;
    } catch (_) {
      return null; // File might be empty
    }
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Stack(
      children: [
        if (kDebugMode)
          Align(
            alignment: Alignment.topCenter,
            child: Text(
              'Experimental Version',
              style: GoogleFonts.poppins(
                color: Colors.amber,
                fontSize: 10 * sss,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (SharedPrefUtils().useCustomXXMILib())
          Align(
            alignment: Alignment.topCenter,
            child: Text(
              'Intended to be used with Custom XXMI Lib by @Aglglg on Github',
              style: GoogleFonts.poppins(
                color: Colors.amber,
                fontSize: 10 * sss,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        ///Tab views
        IndexedStack(index: ref.watch(tabIndexProvider), children: _views),

        ///Tab bars
        Padding(
          padding: EdgeInsets.only(top: 25 * sss),
          child: Align(
            alignment: Alignment.topCenter,
            child: Transform.scale(
              scale: sss,
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
                  tabs: [
                    SegmentTab(label: "Keybinds".tr()),
                    SegmentTab(label: "Mods".tr()),
                    SegmentTab(label: "Settings".tr()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void onKeyEvent(KeyEvent value, Controller? controller) {
    if (_tabController.index == 1 && !ref.read(isCarouselProvider)) return;
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

class UpdateModDataSnackbarButton extends ConsumerStatefulWidget {
  const UpdateModDataSnackbarButton({super.key});

  @override
  ConsumerState<UpdateModDataSnackbarButton> createState() =>
      _UpdateModDataSnackbarButtonState();
}

class _UpdateModDataSnackbarButtonState
    extends ConsumerState<UpdateModDataSnackbarButton> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color.fromARGB(255, 72, 68, 80),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20 * ref.read(zoomScaleProvider),
          right: 20 * ref.read(zoomScaleProvider),
          bottom: 10 * ref.read(zoomScaleProvider),
          top: 10 * ref.read(zoomScaleProvider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Do not forget to press Update Mod Data'.tr(),
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * ref.read(zoomScaleProvider),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (ref.read(validModsPath) == null) return;
                try {
                  final listAnimController = ref.read(
                    animControllerSpecialSnackbar,
                  );
                  for (var controller in listAnimController) {
                    try {
                      controller.reverse();
                    } catch (_) {}
                  }
                } catch (_) {}
                ref.read(alertDialogShownProvider.notifier).state = true;
                await showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder:
                      (context) =>
                          UpdateModDialog(modsPath: ref.read(validModsPath)!),
                );
                triggerRefresh(ref);
              },
              child: Text(
                'Update Mod Data'.tr(),
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * ref.read(zoomScaleProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showUpdateModSnackbar(BuildContext context, ProviderContainer container) {
  SharedPrefUtils().setCurrentTargetGameNeedUpdateMod(
    container.read(targetGameProvider),
    true,
  );
  showTopSnackBar(
    Overlay.of(context),
    onAnimationControllerInit: (controller) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        final listAnimController = container.read(
          animControllerSpecialSnackbar,
        );
        listAnimController.add(controller);
        container.read(animControllerSpecialSnackbar.notifier).state =
            listAnimController;
      });
    },
    persistent: true,
    padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
    animationDuration: Duration(milliseconds: 500),
    reverseAnimationDuration: Duration(milliseconds: 250),
    snackBarPosition: SnackBarPosition.bottom,
    UpdateModDataSnackbarButton(),
  );
}
