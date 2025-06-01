import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/auto_group_icon.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_navigator.dart';
import 'package:no_reload_mod_manager/utils/mod_searcher.dart';
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

class _TabModsState extends ConsumerState<TabMods> with ModNavigationListener {
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
    return Padding(
      padding: EdgeInsets.only(top: 67 * sss, right: 45 * sss, left: 45 * sss),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (ref.watch(windowIsPinnedProvider) ||
                  ref.watch(modGroupDataProvider).isEmpty)
                Center(
                  child: Column(
                    children: [
                      IgnorePointer(
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
                    ],
                  ),
                ),

              if (ref.watch(modGroupDataProvider).isNotEmpty)
                Column(
                  children: [
                    IgnorePointer(child: Container(height: 12 * sss)),
                    Center(
                      child: Row(
                        children: [
                          GroupArea(
                            initialGroupIndex: ref.watch(
                              currentGroupIndexProvider,
                            ),
                          ),

                          IgnorePointer(
                            child: SizedBox(width: 45 * sss, height: 200 * sss),
                          ),

                          ModArea(
                            currentGroupData:
                                ref.watch(modGroupDataProvider)[ref.watch(
                                  currentGroupIndexProvider,
                                )],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (ref.watch(searchBarShownProvider))
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 15.0 * sss),
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
      ),
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

class GroupArea extends ConsumerStatefulWidget {
  final int initialGroupIndex;
  const GroupArea({super.key, required this.initialGroupIndex});

  @override
  ConsumerState<GroupArea> createState() => _GroupAreaState();
}

class _GroupAreaState extends ConsumerState<GroupArea>
    with ModNavigationListener, ModSearcherListener {
  final CarouselSliderController _carouselSliderGroupController =
      CarouselSliderController();
  final TextEditingController _groupNameTextFieldController =
      TextEditingController();
  bool groupTextFieldEnabled = false;
  final FocusNode groupTextFieldFocusNode = FocusNode();
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    getCurrentGroupName(widget.initialGroupIndex, calledFromInitState: true);
    ModNavigationListener.addListener(this);
    ModSearcherListener.addListener(this);
  }

  @override
  void dispose() {
    ModNavigationListener.removeListener(this);
    ModSearcherListener.removeListener(this);
    groupTextFieldFocusNode.dispose();
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

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 93.6 * sss,
          height: 130 * sss,
          child: RightClickMenuRegion(
            menuItems: [
              CustomMenuItem(
                scale: sss,
                onSelected: () async {
                  if (!context.mounted) return;
                  int? groupIndex = await addGroup(
                    ref,
                    p.join(
                      getCurrentModsPath(ref.read(targetGameProvider)),
                      ConstantVar.managedFolderName,
                    ),
                  );
                  if (!context.mounted) return;
                  if (groupIndex != null) {
                    getCurrentGroupName(groupIndex - 1);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _carouselSliderGroupController.animateToPage(
                        groupIndex - 1,
                        duration: Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    });
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
                          'Max group reached (48 Groups). Unable to add more group.'
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
            ],
            child: CarouselSlider.builder(
              itemCount: ref.watch(modGroupDataProvider).length,
              itemBuilder: (context, index, realIndex) {
                return RightClickMenuRegion(
                  menuItems: [
                    CustomMenuItem(
                      scale: sss,
                      onSelected: () async {
                        if (!context.mounted) return;
                        int? groupIndex = await addGroup(
                          ref,
                          p.join(
                            getCurrentModsPath(ref.read(targetGameProvider)),
                            ConstantVar.managedFolderName,
                          ),
                        );
                        if (!context.mounted) return;
                        if (groupIndex != null) {
                          getCurrentGroupName(groupIndex - 1);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _carouselSliderGroupController.animateToPage(
                              groupIndex - 1,
                              duration: Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          });
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
                                'Max group reached (48 Groups). Unable to add more group.'
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
                    if (index == currentPageIndex)
                      CustomMenuItem(
                        scale: sss,
                        onSelected: () {
                          if (!context.mounted) return;
                          setState(() {
                            groupTextFieldEnabled = true;
                          });
                          _groupNameTextFieldController
                              .selection = TextSelection(
                            baseOffset: 0,
                            extentOffset:
                                _groupNameTextFieldController.text.length,
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            groupTextFieldFocusNode.requestFocus();
                          });
                        },
                        label: 'Rename'.tr(),
                      ),
                    if (index == currentPageIndex)
                      CustomMenuItem.submenu(
                        items: [
                          CustomMenuItem(
                            scale: sss,

                            onSelected: () async {
                              if (!context.mounted) return;
                              bool success = await tryGetIcon(
                                ref
                                    .read(modGroupDataProvider)[index]
                                    .groupDir
                                    .path,
                                ref.read(autoIconProvider),
                              );
                              if (!context.mounted) return;
                              if (!success) {
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
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
                                      'Auto group icon failed. No matching character hash.'
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
                            label: 'Try auto icon'.tr(),
                          ),
                          if (index == currentPageIndex)
                            CustomMenuItem(
                              scale: sss,
                              onSelected: () async {
                                if (!context.mounted) return;
                                await setGroupOrModIcon(
                                  ref,
                                  ref
                                      .read(modGroupDataProvider)[index]
                                      .groupDir,
                                  ref
                                      .read(modGroupDataProvider)[index]
                                      .groupIcon,
                                  fromClipboard: true,
                                  isGroup: true,
                                  modDir: null,
                                );
                              },
                              label: 'Clipboard icon'.tr(),
                            ),
                          if (index == currentPageIndex)
                            CustomMenuItem(
                              scale: sss,
                              onSelected: () {
                                if (!context.mounted) return;
                                setGroupOrModIcon(
                                  ref,
                                  ref
                                      .read(modGroupDataProvider)[index]
                                      .groupDir,
                                  ref
                                      .read(modGroupDataProvider)[index]
                                      .groupIcon,
                                  fromClipboard: false,
                                  isGroup: true,
                                  modDir: null,
                                );
                              },
                              label: 'Custom icon'.tr(),
                            ),
                        ],
                        scale: sss,
                        label: 'Group icon'.tr(),
                      ),
                    if (index == currentPageIndex)
                      CustomMenuItem(
                        scale: sss,
                        onSelected: () {
                          if (!context.mounted) return;
                          openFileExplorerToSpecifiedPath(
                            ref.read(modGroupDataProvider)[index].groupDir.path,
                          );
                        },
                        label: 'Open in File Explorer'.tr(),
                      ),
                    if (index == currentPageIndex)
                      CustomMenuItem(
                        scale: sss,
                        onSelected: () {
                          if (!context.mounted) return;
                          ref.read(alertDialogShownProvider.notifier).state =
                              true;
                          showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder:
                                (context) => RemoveModGroupDialog(
                                  name: _groupNameTextFieldController.text,
                                  validModsPath: ref.read(validModsPath)!,
                                  modOrGroupDir:
                                      ref
                                          .read(modGroupDataProvider)[index]
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
                      ref.read(modGroupDataProvider)[index].groupDir.path,
                    ),
                    waitDuration: Duration(milliseconds: 500),
                    child: GroupContainer(
                      index: index,
                      currentIndex: currentPageIndex,
                    ),
                  ),
                );
              },
              carouselController: _carouselSliderGroupController,
              options: CarouselOptions(
                initialPage: widget.initialGroupIndex,
                enableInfiniteScroll: true,
                scrollDirection: Axis.vertical,
                enlargeCenterPage: true,
                enlargeFactor: .05,
                onPageChanged: (index, reason, realIndex) {
                  getCurrentGroupName(index);
                },
                scrollPhysics:
                    groupTextFieldEnabled
                        ? NeverScrollableScrollPhysics()
                        : null,
              ),
            ),
          ),
        ),
        Container(height: 2 * sss),

        SizedBox(
          width: 93.6 * sss,
          child: Theme(
            data: Theme.of(context).copyWith(
              textSelectionTheme: TextSelectionThemeData(
                selectionColor: const Color.fromARGB(127, 33, 149, 243),
              ),
            ),
            child: TextField(
              focusNode: groupTextFieldFocusNode,
              enabled: groupTextFieldEnabled,
              cursorColor: Colors.blue,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13 * sss,
                fontWeight: FontWeight.w500,
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
      ],
    );
  }

  @override
  void onKeyEvent(KeyEvent value, Controller? controller) {
    if (ref.read(tabIndexProvider) == 1) {
      if (value.physicalKey == PhysicalKeyboardKey.keyS) {
        _carouselSliderGroupController.nextPage(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (value.physicalKey == PhysicalKeyboardKey.keyW) {
        _carouselSliderGroupController.previousPage(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void onSearched(int groupIndex, int? modIndex) {
    _carouselSliderGroupController.animateToPage(
      groupIndex,
      duration: Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

class GroupContainer extends ConsumerStatefulWidget {
  final int index;
  final int currentIndex;
  const GroupContainer({
    super.key,
    required this.index,
    required this.currentIndex,
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
      child: Container(
        height: 93.6 * sss,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            width: 3 * sss,
            color:
                isHovering && widget.index == widget.currentIndex
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
    );
  }
}

class ModArea extends ConsumerStatefulWidget {
  final ModGroupData currentGroupData;
  const ModArea({super.key, required this.currentGroupData});

  @override
  ConsumerState<ModArea> createState() => _ModAreaState();
}

class _ModAreaState extends ConsumerState<ModArea>
    with WindowListener, ModNavigationListener, ModSearcherListener {
  final CarouselSliderController _carouselSliderModController =
      CarouselSliderController();
  double windowWidth = 0;
  int _currentModRealIndex = 10000;

  double remap(
    double value,
    double oldMin,
    double oldMax,
    double newMin,
    double newMax,
  ) {
    return ((value - oldMin) / (oldMax - oldMin)) * (newMax - newMin) + newMin;
  }

  double getViewportFraction() {
    double zoomScale = ref.watch(zoomScaleProvider);
    if (windowWidth <= 0) {
      return 0.25 * remap(zoomScale, 0.85, 1.5, 1.3, 1.58) * zoomScale;
    }

    final k = 1579.37 * remap(zoomScale, 0.85, 1.5, 1.3, 1.58) * zoomScale;
    const exponent = 1.3219;
    double result = k / pow(windowWidth, exponent);
    return result;
  }

  void goToSelectedModIndex() {
    setState(() {
      _currentModRealIndex = 10000;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _carouselSliderModController.jumpToPage(
            _currentModRealIndex,
            isRealIndex: true,
          );
          _carouselSliderModController.animateToPage(
            widget.currentGroupData.previousSelectedModOnGroup,
            duration: Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } catch (e) {}
      });
    });
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    goToSelectedModIndex();
    ref.listenManual(currentGroupIndexProvider, (p, n) {
      goToSelectedModIndex();
    });
    onWindowResize();
    ModNavigationListener.addListener(this);
    ModSearcherListener.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    ModNavigationListener.removeListener(this);
    ModSearcherListener.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    if (mounted) {
      setState(() {
        windowWidth = size.width;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Expanded(
      child: SizedBox(
        height: 200 * sss * 1.2,
        child: RightClickMenuRegion(
          menuItems: [
            if (!ref.watch(windowIsPinnedProvider))
              CustomMenuItem(
                scale: sss,
                onSelected: () {
                  if (!context.mounted) return;
                  ref.read(windowIsPinnedProvider.notifier).state = true;
                },
                label: 'Add mods'.tr(),
              ),
          ],
          child: CarouselSlider.builder(
            itemCount: widget.currentGroupData.modsInGroup.length,
            carouselController: _carouselSliderModController,
            options: CarouselOptions(
              animateToClosest: false,
              initialPage: 0,
              enableInfiniteScroll: true,
              scrollDirection: Axis.horizontal,
              viewportFraction: getViewportFraction(),
              onPageChanged: (index, reason, realIndex) {
                setState(() {
                  _currentModRealIndex = realIndex;
                });
              },
            ),
            itemBuilder: (context, index, realIndex) {
              bool isCentered = _currentModRealIndex == realIndex;
              double itemHeight = isCentered ? 217.8 * sss : 156.816 * sss;
              return ModContainer(
                isSelected:
                    widget.currentGroupData.previousSelectedModOnGroup == index,
                index: index,
                currentGroupData: widget.currentGroupData,
                itemHeight: itemHeight,
                isCentered: isCentered,
                onSelected: () async {
                  simulateKeySelectMod(
                    ref
                        .read(modGroupDataProvider)[ref.read(
                          currentGroupIndexProvider,
                        )]
                        .realIndex,
                    index,
                  );
                  setSelectedModIndex(
                    ref,
                    index,
                    widget.currentGroupData.groupDir,
                  );
                },
                onTap:
                    () => _carouselSliderModController.animateToPage(
                      index,
                      duration: Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void onKeyEvent(KeyEvent value, Controller? controller) {
    if (ref.read(tabIndexProvider) == 1) {
      if (value.physicalKey == PhysicalKeyboardKey.keyA) {
        _carouselSliderModController.previousPage(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (value.physicalKey == PhysicalKeyboardKey.keyD) {
        _carouselSliderModController.nextPage(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void onSearched(int groupIndex, int? modIndex) {
    if (modIndex != null) {
      _carouselSliderModController.animateToPage(
        modIndex,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }
}

class ModContainer extends ConsumerStatefulWidget {
  final int index;
  final bool isSelected;
  final ModGroupData currentGroupData;
  final double itemHeight;
  final bool isCentered;
  final void Function() onSelected;
  final void Function() onTap;
  const ModContainer({
    super.key,
    required this.itemHeight,
    required this.isCentered,
    required this.onSelected,
    required this.onTap,
    required this.index,
    required this.isSelected,
    required this.currentGroupData,
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
    super.dispose();
  }

  void getModName() {
    _modNameTextFieldController.text =
        widget.currentGroupData.modsInGroup[widget.index].modName;
  }

  Future<void> setCurrentModName() async {
    final modGroupDatas = ref.read(modGroupDataProvider);

    // Clone the mod list with updated mod name
    final updatedMods = widget.currentGroupData.modsInGroup;
    final oldMod = updatedMods[widget.index];
    updatedMods[widget.index] = ModData(
      modDir: oldMod.modDir,
      modIcon: oldMod.modIcon,
      modName: _modNameTextFieldController.text,
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
            onDoubleTap: widget.isCentered ? widget.onSelected : null,
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
                          isModDisabled(
                                widget
                                    .currentGroupData
                                    .modsInGroup[widget.index]
                                    .modDir
                                    .path,
                              )
                              ? Colors.red
                              : widget.isSelected
                              ? Colors.blue
                              : isHovering
                              ? Colors.white
                              : const Color.fromARGB(127, 255, 255, 255),
                      width: 3 * sss,
                    ),
                    borderRadius: BorderRadius.circular(17 * sss),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16 * sss),
                    clipBehavior: Clip.antiAlias,
                    child:
                        widget.index != 0
                            ? RefreshableLocalImage(
                              imageWidget:
                                  widget
                                      .currentGroupData
                                      .modsInGroup[widget.index]
                                      .modIcon,
                              errorWidget: Icon(
                                size: 40 * sss,
                                Icons.image_outlined,
                                color: const Color.fromARGB(127, 255, 255, 255),
                              ),
                            )
                            : Icon(
                              size: 45 * sss,
                              Icons.close,
                              color: const Color.fromARGB(127, 255, 255, 255),
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(height: 3 * sss),
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
        if (widget.isCentered) {
          widget.onSelected();
          controller?.vibrate(Duration(milliseconds: 80));
        }
      }
      if (value.physicalKey == PhysicalKeyboardKey.keyR) {
        if (widget.isCentered) {
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
