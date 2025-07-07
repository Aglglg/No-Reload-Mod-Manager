import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/tabs/mods_tab_carousel.dart';
import 'package:no_reload_mod_manager/tabs/mods_tab_grid.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_navigator.dart';
import 'package:no_reload_mod_manager/utils/refreshable_image.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;
import 'package:xinput_gamepad/xinput_gamepad.dart';

class TabMods extends ConsumerStatefulWidget {
  const TabMods({super.key});

  @override
  ConsumerState<TabMods> createState() => _TabModsState();
}

class _TabModsState extends ConsumerState<TabMods> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    onWindowResize();
    ref.listenManual(layoutModeProvider, (_, _) {
      onWindowResize();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() async {
    if (ref.read(layoutModeProvider) != 0) return;
    final size = await windowManager.getSize();
    if (mounted) {
      double minimalHeight = 370 * ref.read(zoomScaleProvider);
      double currentHeight = size.height;
      if (minimalHeight * 1.3 <= currentHeight) {
        ref.read(isCarouselProvider.notifier).state = false;
      } else {
        ref.read(isCarouselProvider.notifier).state = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int layoutMode = ref.watch(layoutModeProvider);
    if (layoutMode == 0) {
      if (ref.watch(isCarouselProvider)) {
        return TabModsCarousel();
      } else {
        return TabModsGrid();
      }
    } else if (layoutMode == 1) {
      return TabModsCarousel();
    } else if (layoutMode == 2) {
      return TabModsGrid();
    } else {
      return TabModsCarousel();
    }
  }
}

class GroupContainer extends ConsumerStatefulWidget {
  final int index;
  final int currentIndex;
  final double size;
  final Color? selectedColor;
  final Function() onTap;
  const GroupContainer({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.size,
    required this.onTap,
    this.selectedColor,
  });

  @override
  ConsumerState<GroupContainer> createState() => _GroupContainerState();
}

class _GroupContainerState extends ConsumerState<GroupContainer> {
  bool isHovering = false;
  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return MouseRegion(
      onEnter:
          (_) => setState(() {
            isHovering = true;
          }),
      onExit:
          (_) => setState(() {
            isHovering = false;
          }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: widget.size * sss,
          width: widget.size * sss,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              width: 3 * sss,
              color:
                  widget.selectedColor != null
                      ? widget.selectedColor!
                      : isHovering
                      ? Colors.white
                      : const Color.fromARGB(127, 255, 255, 255),
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            color: Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: RefreshableLocalImage(
              imageWidget:
                  ref.watch(modGroupDataProvider)[widget.index].groupIcon,
              errorWidget: Icon(
                size: 35 * sss,
                Icons.image_outlined,
                color: const Color.fromARGB(127, 255, 255, 255),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModContainer extends ConsumerStatefulWidget {
  final int index;
  final bool isSelected;
  final ModGroupData currentGroupData;
  final double itemHeight;
  final bool isCentered;
  final bool isActiveInGrid;
  final bool isGrid;
  final void Function() onSelected;
  final void Function() onTap;
  const ModContainer({
    super.key,
    required this.itemHeight,
    required this.isCentered,
    required this.isGrid,
    required this.onSelected,
    required this.onTap,
    required this.index,
    required this.isSelected,
    required this.currentGroupData,
    required this.isActiveInGrid,
  });

  @override
  ConsumerState<ModContainer> createState() => _ModContainerState();
}

class _ModContainerState extends ConsumerState<ModContainer>
    with ModNavigationListener {
  bool isHovering = false;
  final TextEditingController _modNameTextFieldController =
      TextEditingController();
  bool modTextFieldEnabled = false;
  final FocusNode modTextFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    getModName();
    ref.listenManual(currentGroupIndexProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getModName();
      });
    });
    ModNavigationListener.addListener(this);
  }

  @override
  void dispose() {
    ModNavigationListener.removeListener(this);
    modTextFieldFocusNode.dispose();
    _modNameTextFieldController.dispose();
    super.dispose();
  }

  void getModName() {
    try {
      _modNameTextFieldController.text =
          widget.currentGroupData.modsInGroup[widget.index].modName;
    } catch (e) {}
  }

  Future<void> setCurrentModName() async {
    final modGroupDatas = ref.read(modGroupDataProvider);

    // Clone the mod list with updated mod name
    final updatedMods = widget.currentGroupData.modsInGroup;
    final oldMod = updatedMods[widget.index];
    updatedMods[widget.index] = ModData(
      modDir: oldMod.modDir,
      modIcon: oldMod.modIcon,
      realIndex: oldMod.realIndex,
      modName: _modNameTextFieldController.text,
      isForced: oldMod.isForced,
      isIncludingRabbitFx: oldMod.isIncludingRabbitFx,
      isUnoptimized: oldMod.isUnoptimized,
    );

    // Clone the ModGroupData with updated mod list
    final updatedGroup = ModGroupData(
      groupDir: widget.currentGroupData.groupDir,
      groupIcon: widget.currentGroupData.groupIcon,
      groupName: widget.currentGroupData.groupName,
      modsInGroup: updatedMods,
      realIndex: widget.currentGroupData.realIndex,
      previousSelectedModOnGroup:
          widget.currentGroupData.previousSelectedModOnGroup,
    );

    // Update the full list
    final updatedGroups = List<ModGroupData>.from(modGroupDatas);
    updatedGroups[ref.read(currentGroupIndexProvider)] = updatedGroup;

    // Save to provider
    ref.read(modGroupDataProvider.notifier).state = updatedGroups;

    await setModNameOnDisk(oldMod.modDir, _modNameTextFieldController.text);
  }

  bool isModDisabled(String modPath) {
    if (p.basename(modPath).toLowerCase().startsWith('disabled')) {
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RightClickMenuRegion(
          menuItems: [
            CustomMenuItem(
              scale: sss,
              onSelected: () {
                if (!context.mounted) return;
                widget.onSelected();
              },
              label: 'Select'.tr(),
              textColor: Colors.blue,
            ),
            if (!ref.watch(windowIsPinnedProvider))
              CustomMenuItem(
                scale: sss,
                onSelected: () {
                  if (!context.mounted) return;
                  ref.read(windowIsPinnedProvider.notifier).state = true;
                },
                label: 'Add mods'.tr(),
              ),
            if (widget.index != 0)
              CustomMenuItem.submenu(
                items: [
                  if (widget.index != 0)
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        if (!context.mounted) return;
                        await setGroupOrModIcon(
                          ref,
                          widget.currentGroupData.groupDir,
                          widget
                              .currentGroupData
                              .modsInGroup[widget.index]
                              .modIcon,
                          fromClipboard: true,
                          isGroup: false,
                          modDir:
                              widget
                                  .currentGroupData
                                  .modsInGroup[widget.index]
                                  .modDir,
                        );
                      },
                      label: 'Clipboard icon'.tr(),
                    ),
                  if (widget.index != 0)
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        if (!context.mounted) return;
                        await setGroupOrModIcon(
                          ref,
                          widget.currentGroupData.groupDir,
                          widget
                              .currentGroupData
                              .modsInGroup[widget.index]
                              .modIcon,
                          fromClipboard: false,
                          isGroup: false,
                          modDir:
                              widget
                                  .currentGroupData
                                  .modsInGroup[widget.index]
                                  .modDir,
                        );
                      },
                      label: 'Custom icon'.tr(),
                    ),
                  if (widget.index != 0)
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        if (!context.mounted) return;
                        await unsetGroupOrModIcon(
                          ref,
                          widget.currentGroupData.groupDir,
                          modDir:
                              widget
                                  .currentGroupData
                                  .modsInGroup[widget.index]
                                  .modDir,
                          widget
                              .currentGroupData
                              .modsInGroup[widget.index]
                              .modIcon,
                        );
                      },
                      label: 'Remove icon'.tr(),
                    ),
                ],
                label: 'Mod icon'.tr(),
                scale: sss,
              ),
            if (widget.index != 0)
              CustomMenuItem(
                scale: sss,
                onSelected: () {
                  if (!context.mounted) return;
                  setState(() {
                    modTextFieldEnabled = true;
                  });
                  _modNameTextFieldController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _modNameTextFieldController.text.length,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    modTextFieldFocusNode.requestFocus();
                  });
                },
                label: 'Rename'.tr(),
              ),
            if (widget.index != 0)
              CustomMenuItem(
                scale: sss,
                onSelected: () {
                  if (!context.mounted) return;
                  ref.read(modKeybindProvider.notifier).state = null;
                  ref.read(modKeybindProvider.notifier).state = (
                    widget.currentGroupData.modsInGroup[widget.index],
                    widget.currentGroupData.groupName,
                    ref.read(targetGameProvider),
                  );
                },
                label: 'Keybinds'.tr(),
              ),
            if (widget.index != 0)
              CustomMenuItem(
                scale: sss,
                onSelected: () {
                  if (!context.mounted) return;
                  openFileExplorerToSpecifiedPath(
                    widget
                        .currentGroupData
                        .modsInGroup[widget.index]
                        .modDir
                        .path,
                  );
                },
                label: 'Open in File Explorer'.tr(),
              ),
            if (widget.index != 0 &&
                !isModDisabled(
                  widget.currentGroupData.modsInGroup[widget.index].modDir.path,
                ))
              CustomMenuItem(
                scale: sss,
                onSelected: () async {
                  if (!context.mounted) return;

                  bool success = await completeDisableMod(
                    widget.currentGroupData.modsInGroup[widget.index].modDir,
                  );

                  if (!context.mounted) return;

                  if (success) {
                    ref.read(alertDialogShownProvider.notifier).state = true;
                    await showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder:
                          (context) => UpdateModDialog(
                            modsPath: ref.read(validModsPath)!,
                          ),
                    );
                    triggerRefresh(ref);
                  } else {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF2B2930),
                        margin: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 20,
                        ),
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        closeIconColor: Colors.blue,
                        showCloseIcon: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        content: Text(
                          'Failed to disable mod'.tr(),
                          style: GoogleFonts.poppins(
                            color: Colors.yellow,
                            fontSize: 13 * ref.read(zoomScaleProvider),
                          ),
                        ),
                        dismissDirection: DismissDirection.down,
                      ),
                    );
                  }
                },
                label: 'Disable mod completely'.tr(),
              ),
            if (widget.index != 0 &&
                isModDisabled(
                  widget.currentGroupData.modsInGroup[widget.index].modDir.path,
                ))
              CustomMenuItem(
                scale: sss,
                onSelected: () async {
                  if (!context.mounted) return;

                  bool success = await enableMod(
                    widget.currentGroupData.modsInGroup[widget.index].modDir,
                  );

                  if (!context.mounted) return;

                  if (success) {
                    ref.read(alertDialogShownProvider.notifier).state = true;
                    await showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder:
                          (context) => UpdateModDialog(
                            modsPath: ref.read(validModsPath)!,
                          ),
                    );
                    triggerRefresh(ref);
                  } else {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF2B2930),
                        margin: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 20,
                        ),
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        closeIconColor: Colors.blue,
                        showCloseIcon: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        content: Text(
                          'Failed to enable mod'.tr(),
                          style: GoogleFonts.poppins(
                            color: Colors.yellow,
                            fontSize: 13 * ref.read(zoomScaleProvider),
                          ),
                        ),
                        dismissDirection: DismissDirection.down,
                      ),
                    );
                  }
                },
                label: 'Enable mod'.tr(),
              ),
            if (widget.index != 0)
              CustomMenuItem(
                scale: sss,
                onSelected: () {
                  if (!context.mounted) return;
                  ref.read(alertDialogShownProvider.notifier).state = true;
                  showDialog(
                    barrierDismissible: false,
                    context: context,
                    builder:
                        (context) => RemoveModGroupDialog(
                          name: _modNameTextFieldController.text,
                          validModsPath: ref.read(validModsPath)!,
                          modOrGroupDir:
                              widget
                                  .currentGroupData
                                  .modsInGroup[widget.index]
                                  .modDir,
                          isGroup: false,
                        ),
                  );
                },
                label: 'Remove mod'.tr(),
              ),
          ],
          child: GestureDetector(
            onDoubleTap:
                widget.isCentered || widget.isGrid ? widget.onSelected : null,
            onTap: widget.onTap,
            child: MouseRegion(
              onEnter:
                  (_) => setState(() {
                    isHovering = true;
                  }),
              onExit:
                  (_) => setState(() {
                    isHovering = false;
                  }),
              child: Tooltip(
                message: p.basename(
                  widget.currentGroupData.modsInGroup[widget.index].modDir.path,
                ),
                waitDuration: Duration(milliseconds: 500),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  height: widget.itemHeight,
                  width: 156.816 * sss,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      strokeAlign: BorderSide.strokeAlignInside,
                      color:
                          (isHovering && !widget.isGrid) ||
                                  (widget.isActiveInGrid && widget.isGrid)
                              ? Colors.white
                              : isModDisabled(
                                widget
                                    .currentGroupData
                                    .modsInGroup[widget.index]
                                    .modDir
                                    .path,
                              )
                              ? Colors.red
                              : widget.isSelected
                              ? Colors.blue
                              : const Color.fromARGB(127, 255, 255, 255),
                      width: !widget.isActiveInGrid ? 3 * sss : 4 * sss,
                    ),
                    borderRadius: BorderRadius.circular(17 * sss),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14 * sss),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        widget.index != 0
                            ? SizedBox.expand(
                              child: RefreshableLocalImage(
                                imageWidget:
                                    widget
                                        .currentGroupData
                                        .modsInGroup[widget.index]
                                        .modIcon,
                                errorWidget: Icon(
                                  size: 40 * sss,
                                  Icons.image_outlined,
                                  color: const Color.fromARGB(
                                    127,
                                    255,
                                    255,
                                    255,
                                  ),
                                ),
                              ),
                            )
                            : SizedBox.expand(
                              child: Icon(
                                size: 45 * sss,
                                Icons.close,
                                color: const Color.fromARGB(127, 255, 255, 255),
                              ),
                            ),

                        if (widget
                                .currentGroupData
                                .modsInGroup[widget.index]
                                .isForced ||
                            widget
                                .currentGroupData
                                .modsInGroup[widget.index]
                                .isIncludingRabbitFx ||
                            widget
                                .currentGroupData
                                .modsInGroup[widget.index]
                                .isUnoptimized)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 30 * sss,
                              width: 156.816 * sss,
                              color: const Color.fromARGB(150, 0, 0, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: 8 * sss,
                                children: [
                                  if (widget
                                      .currentGroupData
                                      .modsInGroup[widget.index]
                                      .isForced)
                                    Tooltip(
                                      richMessage: TextSpan(
                                        text:
                                            'Mod was forced to be managed and might not working properly.'
                                                .tr(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * sss,
                                        ),
                                      ),
                                      child: HoverableIcon(
                                        iconData: Icons.sync_problem_rounded,
                                        scaleFactor: sss,
                                        idleColor: Colors.yellow,
                                        activeColor: Colors.white,
                                      ),
                                    ),
                                  if (widget
                                      .currentGroupData
                                      .modsInGroup[widget.index]
                                      .isIncludingRabbitFx)
                                    Tooltip(
                                      richMessage: TextSpan(
                                        text:
                                            'Mod contains RabbitFx.ini, please remove it. You must only have 1 RabbitFx accross your entire "Mods" folder.'
                                                .tr(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * sss,
                                        ),
                                      ),
                                      child: HoverableIcon(
                                        iconData: Icons.warning_amber_rounded,
                                        scaleFactor: sss,
                                        idleColor: Colors.yellow,
                                        activeColor: Colors.white,
                                      ),
                                    ),
                                  if (widget
                                      .currentGroupData
                                      .modsInGroup[widget.index]
                                      .isUnoptimized)
                                    Tooltip(
                                      richMessage: TextSpan(
                                        text:
                                            'Mod is unoptimized and might slow down performance or even break other mods.'
                                                .tr(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * sss,
                                        ),
                                      ),
                                      child: Transform.scale(
                                        scaleX: -1,
                                        child: HoverableIcon(
                                          iconData: Icons.speed_rounded,
                                          scaleFactor: sss,
                                          idleColor: Colors.yellow,
                                          activeColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 3 * sss, width: 156.816 * sss),
        SizedBox(
          width: 156.816 * sss,
          child: TextField(
            focusNode: modTextFieldFocusNode,
            enabled: modTextFieldEnabled,
            cursorColor: Colors.blue,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12 * sss),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(0),
              hintText: "Mod Name".tr(),
              hintStyle: GoogleFonts.poppins(
                color: const Color.fromARGB(90, 255, 255, 255),
                fontSize: 12 * sss,
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.blue,
                  style: BorderStyle.none,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            onEditingComplete: () {
              setState(() {
                modTextFieldEnabled = false;
              });
              setCurrentModName();
            },
            onTapOutside: (v) {
              setState(() {
                modTextFieldEnabled = false;
              });
              setCurrentModName();
            },

            controller: _modNameTextFieldController,
          ),
        ),
      ],
    );
  }

  @override
  void onKeyEvent(KeyEvent value, Controller? controller) {
    if (ref.read(tabIndexProvider) == 1) {
      if (value.physicalKey == PhysicalKeyboardKey.keyF) {
        if (widget.isCentered || widget.isActiveInGrid) {
          widget.onSelected();
          controller?.vibrate(Duration(milliseconds: 80));
        }
      }
      if (value.physicalKey == PhysicalKeyboardKey.keyR) {
        if (widget.isCentered || widget.isActiveInGrid) {
          ref.read(modKeybindProvider.notifier).state = null;
          ref.read(modKeybindProvider.notifier).state = (
            widget.currentGroupData.modsInGroup[widget.index],
            widget.currentGroupData.groupName,
            ref.read(targetGameProvider),
          );
        }
      }
    }
  }
}

class TabModsNotReady extends ConsumerWidget {
  final String notReadyReason;

  const TabModsNotReady({super.key, required this.notReadyReason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sss = ref.watch(zoomScaleProvider);
    return Padding(
      padding: EdgeInsets.only(top: 85 * sss),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Warning".tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14 * sss,
            ),
          ),
          Text(
            notReadyReason,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              fontSize: 12 * sss,
            ),
          ),
          Container(height: 12 * sss),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "1. Go to Settings.".tr(),
                // textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 12 * sss,
                ),
              ),
              Text(
                "2. Make sure Mods Path is correct.".tr(),
                // textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 12 * sss,
                ),
              ),
              Text(
                "3. Press Update Mod Data button.".tr(),
                // textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 12 * sss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TabModsLoading extends ConsumerWidget {
  const TabModsLoading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sss = ref.watch(zoomScaleProvider);
    return Padding(
      padding: EdgeInsets.only(top: 57 * sss),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Loading mods".tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 12 * sss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HoverableIcon extends StatefulWidget {
  final IconData iconData;
  final double scaleFactor;
  final Color idleColor;
  final Color activeColor;
  const HoverableIcon({
    super.key,
    required this.iconData,
    required this.scaleFactor,
    required this.idleColor,
    required this.activeColor,
  });

  @override
  State<HoverableIcon> createState() => _HoverableIconState();
}

class _HoverableIconState extends State<HoverableIcon> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() {
          isHovering = true;
        });
      },
      onExit: (event) {
        setState(() {
          isHovering = false;
        });
      },
      child: Icon(
        widget.iconData,
        color: !isHovering ? widget.idleColor : widget.activeColor,
        size: 20 * widget.scaleFactor,
      ),
    );
  }
}
