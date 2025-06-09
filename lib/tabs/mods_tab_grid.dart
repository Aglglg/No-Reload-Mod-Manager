import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/tabs/mods_tab.dart';
import 'package:no_reload_mod_manager/utils/auto_group_icon.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_navigator.dart';
import 'package:no_reload_mod_manager/utils/mod_searcher.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;
import 'package:xinput_gamepad/xinput_gamepad.dart';

class TabModsGrid extends ConsumerStatefulWidget {
  const TabModsGrid({super.key});

  @override
  ConsumerState<TabModsGrid> createState() => _TabModsGridState();
}

class _TabModsGridState extends ConsumerState<TabModsGrid>
    with ModNavigationListener {
  final searchController = TextEditingController();
  final searchFocus = FocusNode();
  String getTextDragAndDrop() {
    String text = '';
    if (ref.watch(modGroupDataProvider).isEmpty) {
      text = "Right-click and add group, then you can add mods.".tr();
    } else {
      if (ref.watch(windowIsPinnedProvider)) {
        text =
            'Drag & Drop mod folders here to add mods to this group (1 folder = 1 mod).'
                .tr();
      }
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(searchBarShownProvider, (previous, next) {
      if (next == true) {
        searchFocus.requestFocus();
      }
    });
    ModNavigationListener.addListener(this);
  }

  @override
  void dispose() {
    ModNavigationListener.removeListener(this);
    searchController.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  String getSearchBarHint() {
    int mode = ref.watch(searchBarMode);
    switch (mode) {
      case 0:
        return 'Search mod/group by name or real folder name'.tr();
      case 1:
        return 'Search group by name or real folder name'.tr();
      case 2:
        return 'Search mod by name or real folder name'.tr();
      case 3:
        return 'Search mod in the current group by name or real folder name'
            .tr();
      default:
        return 'Search mod/group by name or real folder name'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Stack(
      children: [
        Stack(
          children: [
            if (ref.watch(windowIsPinnedProvider) ||
                ref.watch(modGroupDataProvider).isEmpty)
              Align(
                alignment:
                    ref.watch(modGroupDataProvider).isNotEmpty
                        ? Alignment.topCenter
                        : Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(
                    top:
                        ref.watch(modGroupDataProvider).isNotEmpty
                            ? 85 * sss
                            : 70 * sss,
                  ),
                  child: IgnorePointer(
                    child: Text(
                      getTextDragAndDrop(),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: GoogleFonts.poppins(
                        color:
                            ref.watch(windowIsPinnedProvider)
                                ? Colors.blue
                                : const Color.fromARGB(127, 255, 255, 255),
                        fontSize: 12 * sss,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            if (ref.watch(modGroupDataProvider).isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top:
                      ref.watch(windowIsPinnedProvider)
                          ? 120 * sss
                          : (120 - 35) * sss,
                  right: 45 * sss,
                  left: 45 * sss,
                  bottom: 40 * sss,
                ),
                child: GroupAreaGrid(
                  initialGroupIndex: ref.watch(currentGroupIndexProvider),
                ),
              ),

            if (ref.watch(modGroupDataProvider).isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top:
                      ref.watch(windowIsPinnedProvider)
                          ? 235 * sss
                          : (235 - 35) * sss,
                  right: 45 * sss,
                  left: 45 * sss,
                  bottom: 40 * sss,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ModAreaGrid(
                    currentGroupData:
                        ref.watch(modGroupDataProvider)[ref.watch(
                          currentGroupIndexProvider,
                        )],
                  ),
                ),
              ),
          ],
        ),
        //
        //Search
        if (ref.watch(searchBarShownProvider))
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 95.0 * sss),
              child: SizedBox(
                height: 38 * sss,
                child: SearchBar(
                  focusNode: searchFocus,
                  controller: searchController,
                  onChanged: (value) {
                    if (value == ' ') {
                      ref.read(searchBarMode.notifier).state =
                          (ref.read(searchBarMode) + 1) %
                          4; //4 modes: all, group, mod, ingroup
                      searchController.text = '';
                      return;
                    }
                    if (value.isNotEmpty) goToSearchResult(ref, value);
                  },
                  onSubmitted:
                      (value) =>
                          ref.read(searchBarShownProvider.notifier).state =
                              false,
                  onTapOutside:
                      (event) =>
                          ref.read(searchBarShownProvider.notifier).state =
                              false,
                  leading: Icon(Icons.search),
                  hintText: getSearchBarHint(),
                  hintStyle: WidgetStatePropertyAll(
                    GoogleFonts.poppins(fontSize: 13 * sss),
                  ),
                  textStyle: WidgetStatePropertyAll(
                    GoogleFonts.poppins(fontSize: 13 * sss),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(20 * sss),
                    ),
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
    if (value.physicalKey == PhysicalKeyboardKey.space &&
        ref.read(tabIndexProvider) == 1 &&
        ref.read(modGroupDataProvider).isNotEmpty) {
      ref.read(searchBarShownProvider.notifier).state =
          !ref.read(searchBarShownProvider);
    }
  }
}

class GroupAreaGrid extends ConsumerStatefulWidget {
  final int initialGroupIndex;
  const GroupAreaGrid({super.key, required this.initialGroupIndex});

  @override
  ConsumerState<GroupAreaGrid> createState() => _GroupAreaGridState();
}

class _GroupAreaGridState extends ConsumerState<GroupAreaGrid> {
  final ScrollController listViewController = ScrollController();
  final TextEditingController _groupNameTextFieldController =
      TextEditingController();
  bool groupTextFieldEnabled = false;
  bool isHoveringGroupName = false;
  final FocusNode groupTextFieldFocusNode = FocusNode();
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    getCurrentGroupName(widget.initialGroupIndex, calledFromInitState: true);
  }

  @override
  void dispose() {
    groupTextFieldFocusNode.dispose();
    _groupNameTextFieldController.dispose();
    super.dispose();
  }

  void getCurrentGroupName(int index, {bool calledFromInitState = false}) {
    if (calledFromInitState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentGroupIndexProvider.notifier).state = index;
      });
    } else {
      ref.read(currentGroupIndexProvider.notifier).state = index;
    }

    setState(() {
      currentPageIndex = index;
    });
    _groupNameTextFieldController.text =
        ref.read(modGroupDataProvider)[index].groupName;
  }

  void setCurrentGroupName() {
    final oldList = ref.read(modGroupDataProvider);

    // 1. Copy the existing ModGroupData but with a new groupName
    final updatedGroup = ModGroupData(
      groupDir: oldList[currentPageIndex].groupDir,
      groupIcon: oldList[currentPageIndex].groupIcon,
      groupName: _groupNameTextFieldController.text,
      modsInGroup: oldList[currentPageIndex].modsInGroup,
      realIndex: oldList[currentPageIndex].realIndex,
      previousSelectedModOnGroup:
          oldList[currentPageIndex].previousSelectedModOnGroup,
    );

    // 2. Create a new list with updated item
    final newList = [...oldList];
    newList[currentPageIndex] = updatedGroup;

    // 3. Write the new list back to the provider
    ref.read(modGroupDataProvider.notifier).state = newList;

    // 4. Write to the groupname file in disk
    setGroupNameOnDisk(
      ref.read(modGroupDataProvider)[currentPageIndex].groupDir,
      ref.read(modGroupDataProvider)[currentPageIndex].groupName,
    );
  }

  Future<void> _scrollToBottom() async {
    // Wait until scrollController has a valid position
    await Future.delayed(const Duration(milliseconds: 100));
    if (!listViewController.hasClients) return;

    await listViewController.animateTo(
      listViewController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    double sss = ref.watch(zoomScaleProvider);
    return Column(
      children: [
        SizedBox(
          height: 70 * sss,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
              scrollbars: false,
            ),
            child: Center(
              child: Listener(
                // Listen for pointer signals (like scroll wheel events)
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    // Invert dy if needed depending on desired behavior.
                    final newOffset =
                        listViewController.offset +
                        pointerSignal.scrollDelta.dy;
                    // Use jumpTo for instantaneous change (or animate if you prefer)
                    listViewController.jumpTo(
                      newOffset.clamp(
                        listViewController.position.minScrollExtent,
                        listViewController.position.maxScrollExtent,
                      ),
                    );
                  }
                },
                child: ListView(
                  physics: BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  controller: listViewController,
                  children:
                      ref.watch(modGroupDataProvider).asMap().entries.map((e) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right:
                                e.key !=
                                        ref.watch(modGroupDataProvider).length -
                                            1
                                    ? 15.0 * sss
                                    : 0,
                          ),
                          child: RightClickMenuRegion(
                            menuItems: [
                              CustomMenuItem(
                                scale: sss,
                                onSelected: () async {
                                  if (!context.mounted) return;
                                  int? groupIndex = await addGroup(
                                    ref,
                                    p.join(
                                      getCurrentModsPath(
                                        ref.read(targetGameProvider),
                                      ),
                                      ConstantVar.managedFolderName,
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  if (groupIndex != null) {
                                    getCurrentGroupName(groupIndex - 1);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          _scrollToBottom();
                                        });
                                  } else {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(
                                          0xFF2B2930,
                                        ),
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        content: Text(
                                          'Max group reached (500 Groups). Unable to add more group.'
                                              .tr(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.yellow,
                                            fontSize: 13 * sss,
                                          ),
                                        ),
                                        dismissDirection: DismissDirection.down,
                                      ),
                                    );
                                  }
                                },
                                label: 'Add group'.tr(),
                              ),
                              CustomMenuItem.submenu(
                                label: 'Sort group by'.tr(),
                                scale: sss,
                                items: [
                                  CustomMenuItem(
                                    label: 'Index'.tr(),
                                    scale: sss,
                                    rightIcon:
                                        ref.read(sortGroupMethod) == 0
                                            ? Icons.check
                                            : null,
                                    onSelected: () async {
                                      if (!context.mounted) return;
                                      await SharedPrefUtils().setGroupSort(0);
                                      if (!context.mounted) return;
                                      triggerRefresh(ref);
                                    },
                                  ),
                                  CustomMenuItem(
                                    label: 'Name'.tr(),
                                    scale: sss,
                                    rightIcon:
                                        ref.read(sortGroupMethod) == 1
                                            ? Icons.check
                                            : null,
                                    onSelected: () async {
                                      if (!context.mounted) return;
                                      await SharedPrefUtils().setGroupSort(1);
                                      if (!context.mounted) return;
                                      triggerRefresh(ref);
                                    },
                                  ),
                                ],
                              ),
                              CustomMenuItem.submenu(
                                items: [
                                  CustomMenuItem(
                                    scale: sss,

                                    onSelected: () async {
                                      if (!context.mounted) return;
                                      bool success = await tryGetIcon(
                                        ref
                                            .read(modGroupDataProvider)[e.key]
                                            .groupDir
                                            .path,
                                        ref.read(autoIconProvider),
                                      );
                                      if (!context.mounted) return;
                                      if (!success) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(
                                              0xFF2B2930,
                                            ),
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
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            content: Text(
                                              'Auto group icon failed. No matching character hash.'
                                                  .tr(),
                                              style: GoogleFonts.poppins(
                                                color: Colors.yellow,
                                                fontSize: 13 * sss,
                                              ),
                                            ),
                                            dismissDirection:
                                                DismissDirection.down,
                                          ),
                                        );
                                      }
                                    },
                                    label: 'Try auto icon'.tr(),
                                  ),
                                  CustomMenuItem(
                                    scale: sss,
                                    onSelected: () async {
                                      if (!context.mounted) return;
                                      await setGroupOrModIcon(
                                        ref,
                                        ref
                                            .read(modGroupDataProvider)[e.key]
                                            .groupDir,
                                        ref
                                            .read(modGroupDataProvider)[e.key]
                                            .groupIcon,
                                        fromClipboard: true,
                                        isGroup: true,
                                        modDir: null,
                                      );
                                    },
                                    label: 'Clipboard icon'.tr(),
                                  ),
                                  CustomMenuItem(
                                    scale: sss,
                                    onSelected: () async {
                                      if (!context.mounted) return;
                                      await setGroupOrModIcon(
                                        ref,
                                        ref
                                            .read(modGroupDataProvider)[e.key]
                                            .groupDir,
                                        ref
                                            .read(modGroupDataProvider)[e.key]
                                            .groupIcon,
                                        fromClipboard: false,
                                        isGroup: true,
                                        modDir: null,
                                      );
                                    },
                                    label: 'Custom icon'.tr(),
                                  ),
                                  CustomMenuItem(
                                    scale: sss,
                                    onSelected: () async {
                                      if (!context.mounted) return;
                                      await unsetGroupOrModIcon(
                                        ref,
                                        ref
                                            .read(modGroupDataProvider)[e.key]
                                            .groupDir,
                                        ref
                                            .read(modGroupDataProvider)[e.key]
                                            .groupIcon,
                                      );
                                    },
                                    label: 'Remove icon'.tr(),
                                  ),
                                ],
                                scale: sss,
                                label: 'Group icon'.tr(),
                              ),
                              CustomMenuItem(
                                scale: sss,
                                onSelected: () {
                                  if (!context.mounted) return;
                                  openFileExplorerToSpecifiedPath(
                                    ref
                                        .read(modGroupDataProvider)[e.key]
                                        .groupDir
                                        .path,
                                  );
                                },
                                label: 'Open in File Explorer'.tr(),
                              ),
                              CustomMenuItem(
                                scale: sss,
                                onSelected: () {
                                  if (!context.mounted) return;
                                  ref
                                      .read(alertDialogShownProvider.notifier)
                                      .state = true;
                                  showDialog(
                                    barrierDismissible: false,
                                    context: context,
                                    builder:
                                        (context) => RemoveModGroupDialog(
                                          name:
                                              ref
                                                  .read(modGroupDataProvider)[e
                                                      .key]
                                                  .groupName,
                                          validModsPath:
                                              ref.read(validModsPath)!,
                                          modOrGroupDir:
                                              ref
                                                  .read(modGroupDataProvider)[e
                                                      .key]
                                                  .groupDir,
                                          isGroup: true,
                                        ),
                                  );
                                },
                                label: 'Remove group'.tr(),
                              ),
                            ],
                            child: Tooltip(
                              message: p.basename(
                                ref.read(modGroupDataProvider)[e.key].groupName,
                              ),
                              waitDuration: Duration(milliseconds: 500),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapUp: (TapUpDetails details) {
                                  getCurrentGroupName(e.key);
                                },
                                child: GroupContainer(
                                  index: e.key,
                                  currentIndex: e.key,
                                  size: 70,
                                  selectedColor:
                                      ref.watch(currentGroupIndexProvider) ==
                                              e.key
                                          ? Colors.blue
                                          : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 13 * sss),
        SizedBox(
          height: 25 * sss,
          child: MouseRegion(
            onEnter:
                (_) => setState(() {
                  isHoveringGroupName = true;
                }),
            onExit:
                (_) => setState(() {
                  isHoveringGroupName = false;
                }),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (TapUpDetails details) {
                setState(() {
                  groupTextFieldEnabled = true;
                });
                _groupNameTextFieldController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _groupNameTextFieldController.text.length,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  groupTextFieldFocusNode.requestFocus();
                });
              },
              child: TextField(
                focusNode: groupTextFieldFocusNode,
                enabled: groupTextFieldEnabled,
                cursorColor: Colors.blue,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14 * sss,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.all(0),
                  hintText: "Group Name".tr(),
                  hintStyle: GoogleFonts.poppins(
                    color: const Color.fromARGB(90, 255, 255, 255),
                    fontSize: 13 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                  disabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: const Color.fromARGB(127, 255, 255, 255),
                      style:
                          isHoveringGroupName
                              ? BorderStyle.solid
                              : BorderStyle.none,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                onEditingComplete: () {
                  setState(() {
                    groupTextFieldEnabled = false;
                  });
                  setCurrentGroupName();
                },
                onTapOutside: (v) {
                  setState(() {
                    groupTextFieldEnabled = false;
                  });
                  setCurrentGroupName();
                },

                controller: _groupNameTextFieldController,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ModAreaGrid extends ConsumerStatefulWidget {
  final ModGroupData currentGroupData;
  const ModAreaGrid({super.key, required this.currentGroupData});

  @override
  ConsumerState<ModAreaGrid> createState() => _ModAreaGridState();
}

class _ModAreaGridState extends ConsumerState<ModAreaGrid> {
  @override
  Widget build(BuildContext context) {
    double sss = ref.watch(zoomScaleProvider);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
        scrollbars: false,
      ),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 15 * sss,
          runSpacing: 15 * sss,
          children:
              widget.currentGroupData.modsInGroup.asMap().entries.map((
                modData,
              ) {
                return ModContainer(
                  itemHeight: 217.8 * sss,
                  isCentered: true,
                  onSelected: () async {
                    simulateKeySelectMod(
                      widget.currentGroupData.realIndex,
                      widget
                          .currentGroupData
                          .modsInGroup[modData.key]
                          .realIndex,
                    );
                    setSelectedModIndex(
                      ref,
                      widget
                          .currentGroupData
                          .modsInGroup[modData.key]
                          .realIndex,
                      widget.currentGroupData.groupDir,
                    );
                  },
                  onTap: () {},
                  index: modData.key,
                  isSelected:
                      widget.currentGroupData.previousSelectedModOnGroup ==
                      widget
                          .currentGroupData
                          .modsInGroup[modData.key]
                          .realIndex,
                  currentGroupData: widget.currentGroupData,
                );
              }).toList(),
        ),
      ),
    );
  }
}
