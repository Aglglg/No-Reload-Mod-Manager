import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/tabs/mods_tab.dart';
import 'package:no_reload_mod_manager/utils/auto_group_icon.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_navigator.dart';
import 'package:no_reload_mod_manager/utils/mod_searcher.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:no_reload_mod_manager/utils/ui_dialogues.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
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
                            ? 98 * sss
                            : 84 * sss,
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
                                ? getAccentColor(ref)
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
                  top: ref.watch(windowIsPinnedProvider) ? 123 * sss : 98 * sss,
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
                      ref.watch(windowIsPinnedProvider) ? 255 * sss : 230 * sss,
                  right: 45 * sss,
                  left: 45 * sss,
                  bottom: 45 * sss,
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
              padding: EdgeInsets.only(
                top: 95.0 * sss,
                right: 45 * sss,
                left: 45 * sss,
              ),
              child: SizedBox(
                height: 38 * sss,
                child: SearchBar(
                  focusNode: searchFocus,
                  controller: searchController,
                  onChanged: (value) {
                    ref.read(searchBarMode.notifier).state = 1;
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
                  leading: Icon(Icons.search, size: 20 * sss),
                  hintText:
                      'Search group by name or real folder name only'.tr(),
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

class ModAreaGrid extends ConsumerStatefulWidget {
  final ModGroupData currentGroupData;
  const ModAreaGrid({super.key, required this.currentGroupData});

  @override
  ConsumerState<ModAreaGrid> createState() => _ModAreaGridState();
}

class _ModAreaGridState extends ConsumerState<ModAreaGrid>
    with ModNavigationListener {
  late List<GlobalKey> _itemKeys;
  int indexOfActiveGridMod = -1;
  double widgetWidth = 0;
  bool mouseWasMoved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToItem(widget.currentGroupData.previousSelectedModOnGroup);
    });
    ref.listenManual(currentGroupIndexProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToItem(widget.currentGroupData.previousSelectedModOnGroup);
      });
    });
    ModNavigationListener.addListener(this);
  }

  @override
  void dispose() {
    ModNavigationListener.removeListener(this);
    super.dispose();
  }

  void _scrollToItem(int index) {
    final context = _itemKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.5, // 0.0 = top, 1.0 = bottom
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double sss = ref.watch(zoomScaleProvider);
    _itemKeys = List.generate(
      widget.currentGroupData.modsInGroup.length,
      (_) => GlobalKey(),
    );
    return MouseRegion(
      onHover: (_) {
        if (!mouseWasMoved) {
          setState(() {
            mouseWasMoved = true;
            indexOfActiveGridMod = -1;
          });
          ref.read(wasUsingKeyboard.notifier).state = false;
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          widgetWidth = constraints.maxWidth;
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
                spacing: 8 * sss,
                runSpacing: 15 * sss,
                children:
                    widget.currentGroupData.modsInGroup.asMap().entries.map((
                      modData,
                    ) {
                      return ModContainer(
                        key: _itemKeys[modData.key],
                        itemHeight: 217.8 * sss,
                        isCentered: false,
                        isActiveInGrid: modData.key == indexOfActiveGridMod,
                        isGrid: true,
                        onSelected: () async {
                          _scrollToItem(modData.key);
                          unawaited(
                            simulateKeySelectMod(
                              widget.currentGroupData.realIndex,
                              widget
                                  .currentGroupData
                                  .modsInGroup[modData.key]
                                  .realIndex,
                            ),
                          );
                          unawaited(
                            setSelectedModIndex(
                              ref,
                              modData
                                  .key, //just view index, not actual mod index
                              widget.currentGroupData.groupPath,
                            ),
                          );
                        },
                        onTap: () {},
                        index: modData.key,
                        isSelected:
                            widget
                                .currentGroupData
                                .previousSelectedModOnGroup ==
                            modData.key,
                        currentGroupData: widget.currentGroupData,
                      );
                    }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void onKeyEvent(KeyEvent value, Controller? controller) {
    double sss = ref.read(zoomScaleProvider);
    int itemsPerLine =
        ((widgetWidth + (8 * sss)) / ((156.816 * sss) + (8 * sss))).floor();
    if (mouseWasMoved) {
      setState(() {
        mouseWasMoved = false;
      });
    }

    if (ref.read(tabIndexProvider) == 1) {
      if (value.physicalKey == PhysicalKeyboardKey.keyD ||
          value.physicalKey == PhysicalKeyboardKey.keyA ||
          value.physicalKey == PhysicalKeyboardKey.keyW ||
          value.physicalKey == PhysicalKeyboardKey.keyS) {
        ref.read(wasUsingKeyboard.notifier).state = true;
      }
      if (value.physicalKey == PhysicalKeyboardKey.keyD) {
        setState(() {
          if (indexOfActiveGridMod >=
              widget.currentGroupData.modsInGroup.length - 1) {
            indexOfActiveGridMod = 0;
          } else {
            indexOfActiveGridMod = indexOfActiveGridMod + 1;
          }
        });
        _scrollToItem(indexOfActiveGridMod);
      } else if (value.physicalKey == PhysicalKeyboardKey.keyA) {
        setState(() {
          if (indexOfActiveGridMod <= 0) {
            indexOfActiveGridMod =
                widget.currentGroupData.modsInGroup.length - 1;
          } else {
            indexOfActiveGridMod = indexOfActiveGridMod - 1;
          }
        });
        _scrollToItem(indexOfActiveGridMod);
      } else if (value.physicalKey == PhysicalKeyboardKey.keyW) {
        int targetIndex = indexOfActiveGridMod - itemsPerLine;
        if (targetIndex < 0) {
          targetIndex = widget.currentGroupData.modsInGroup.length - 1;
        }
        setState(() {
          indexOfActiveGridMod = targetIndex;
        });
        _scrollToItem(indexOfActiveGridMod);
      } else if (value.physicalKey == PhysicalKeyboardKey.keyS) {
        int targetIndex = indexOfActiveGridMod + itemsPerLine;
        if (targetIndex > widget.currentGroupData.modsInGroup.length - 1) {
          targetIndex = widget.currentGroupData.modsInGroup.length - 1;
        }
        if (indexOfActiveGridMod ==
            widget.currentGroupData.modsInGroup.length - 1) {
          targetIndex = 0;
        }
        setState(() {
          indexOfActiveGridMod = targetIndex;
        });
        _scrollToItem(indexOfActiveGridMod);
      }
    }
  }
}

class GroupAreaGrid extends ConsumerStatefulWidget {
  final int initialGroupIndex;
  const GroupAreaGrid({super.key, required this.initialGroupIndex});

  @override
  ConsumerState<GroupAreaGrid> createState() => _GroupAreaState();
}

class _GroupAreaState extends ConsumerState<GroupAreaGrid>
    with ModNavigationListener, ModSearcherListener, WindowListener {
  final CarouselSliderController _carouselSliderGroupController =
      CarouselSliderController();
  final TextEditingController _groupNameTextFieldController =
      TextEditingController();
  bool groupTextFieldEnabled = false;
  final FocusNode groupTextFieldFocusNode = FocusNode();
  int currentPageIndex = 0;
  bool isHoveringGroupName = false;
  double windowWidth = 0;

  int? hoveredIndex;

  @override
  void initState() {
    super.initState();
    getCurrentGroupName(widget.initialGroupIndex, calledFromInitState: true);
    ModNavigationListener.addListener(this);
    ModSearcherListener.addListener(this);
    windowManager.addListener(this);
    onWindowResize();
  }

  @override
  void dispose() {
    ModNavigationListener.removeListener(this);
    ModSearcherListener.removeListener(this);
    groupTextFieldFocusNode.dispose();
    _groupNameTextFieldController.dispose();
    windowManager.removeListener(this);
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
      groupPath: oldList[currentPageIndex].groupPath,
      iconPath: oldList[currentPageIndex].iconPath,
      groupName: _groupNameTextFieldController.text,
      favoriteDateTime: oldList[currentPageIndex].favoriteDateTime,
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
      ref.read(modGroupDataProvider)[currentPageIndex].groupPath,
      ref.read(modGroupDataProvider)[currentPageIndex].groupName,
    );
  }

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
    double sss = ref.watch(zoomScaleProvider);
    if (windowWidth <= 0) {
      return 0.5;
    }

    final viewportFraction = ((65 * sss) + (30 * sss)) / windowWidth;
    return viewportFraction;
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 93.6 * sss,
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
                              closeIconColor: getAccentColor(ref),
                              showCloseIcon: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
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
                  ],
                  child: CarouselSlider.builder(
                    itemCount: ref.watch(modGroupDataProvider).length,
                    carouselController: _carouselSliderGroupController,
                    options: CarouselOptions(
                      initialPage: widget.initialGroupIndex,
                      enableInfiniteScroll: false,
                      scrollDirection: Axis.horizontal,
                      onPageChanged: (index, reason, realIndex) {
                        getCurrentGroupName(index);
                      },
                      scrollPhysics:
                          groupTextFieldEnabled
                              ? NeverScrollableScrollPhysics()
                              : null,
                      animateToClosest: true,
                      viewportFraction: getViewportFraction(),
                    ),
                    itemBuilder: (context, index, realIndex) {
                      final groupData = ref.watch(modGroupDataProvider)[index];
                      return Stack(
                        children: [
                          RightClickMenuRegion(
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
                                          _carouselSliderGroupController
                                              .animateToPage(
                                                groupIndex - 1,
                                                duration: Duration(
                                                  milliseconds: 250,
                                                ),
                                                curve: Curves.easeOut,
                                              );
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
                                        closeIconColor: getAccentColor(ref),
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
                                        groupData.groupPath,
                                        ref.read(targetGameProvider),
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
                                            closeIconColor: getAccentColor(ref),
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
                                            action: SnackBarAction(
                                              textColor: getAccentColor(ref),
                                              label: "Contribute".tr(),
                                              onPressed: () async {
                                                try {
                                                  if (!await launchUrl(
                                                    Uri.parse(
                                                      ConstantVar
                                                          .urlAutoIconInfo,
                                                    ),
                                                  )) {}
                                                } catch (_) {}
                                              },
                                            ),
                                            dismissDirection:
                                                DismissDirection.down,
                                          ),
                                        );
                                      } else {
                                        if (groupData.iconPath != null) {
                                          await ResizeImage(
                                            FileImage(
                                              File(groupData.iconPath!),
                                            ),
                                            width:
                                                ConstantVar
                                                    .groupImageCacheWidth,
                                          ).evict();
                                        }

                                        final currentGroups = ref.read(
                                          modGroupDataProvider,
                                        );

                                        final updatedGroups =
                                            currentGroups.map((group) {
                                              if (group.groupPath ==
                                                  groupData.groupPath) {
                                                return ModGroupData(
                                                  groupPath: group.groupPath,
                                                  iconPath: p.join(
                                                    groupData.groupPath,
                                                    'icon.png',
                                                  ),
                                                  groupName: group.groupName,
                                                  favoriteDateTime:
                                                      group.favoriteDateTime,
                                                  modsInGroup:
                                                      group.modsInGroup,
                                                  realIndex: group.realIndex,
                                                  previousSelectedModOnGroup:
                                                      group
                                                          .previousSelectedModOnGroup,
                                                );
                                              }
                                              return group;
                                            }).toList();

                                        ref
                                            .read(modGroupDataProvider.notifier)
                                            .state = updatedGroups;
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
                                        groupData.groupPath,
                                        groupData.iconPath,
                                        fromClipboard: true,
                                        isGroup: true,
                                        modPath: null,
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
                                        groupData.groupPath,
                                        groupData.iconPath,
                                        fromClipboard: false,
                                        isGroup: true,
                                        modPath: null,
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
                                        groupData.groupPath,
                                        groupData.iconPath,
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
                                    groupData.groupPath,
                                  );
                                },
                                label: 'Open in File Explorer'.tr(),
                              ),
                              CustomMenuItem(
                                scale: sss,
                                onSelected: () async {
                                  if (!context.mounted) return;

                                  String? watchedPath =
                                      DynamicDirectoryWatcher.watcher?.path;
                                  DynamicDirectoryWatcher.stop();

                                  final mods = groupData.modsInGroup;
                                  final modPathsSuccess = <String>[];
                                  for (var mod in mods) {
                                    final success = await completeDisableMod(
                                      mod.modPath,
                                    );
                                    if (success) {
                                      modPathsSuccess.add(mod.modPath);
                                    }
                                  }

                                  if (watchedPath != null) {
                                    DynamicDirectoryWatcher.watch(watchedPath);
                                  }

                                  //UPDATE RIVERPOD
                                  final currentGroups = ref.read(
                                    modGroupDataProvider,
                                  );

                                  final updatedGroups =
                                      currentGroups.map((group) {
                                        if (group.groupPath ==
                                            groupData.groupPath) {
                                          final updatedMods =
                                              group.modsInGroup.map((mod) {
                                                if (modPathsSuccess.contains(
                                                  mod.modPath,
                                                )) {
                                                  return ModData(
                                                    modPath: p.join(
                                                      p.dirname(mod.modPath),
                                                      "DISABLED${p.basename(mod.modPath)}",
                                                    ),
                                                    iconPath: mod.iconPath,
                                                    modName: mod.modName,
                                                    realIndex: mod.realIndex,
                                                    isOldAutoFixed:
                                                        mod.isOldAutoFixed,
                                                    isSyntaxErrorRemoved:
                                                        mod.isSyntaxErrorRemoved,
                                                    isUnoptimized:
                                                        mod.isUnoptimized,
                                                    isNamespaced:
                                                        mod.isNamespaced,
                                                    isDisabled: true,
                                                    favoriteDateTime:
                                                        mod.favoriteDateTime,
                                                  );
                                                }
                                                return mod;
                                              }).toList();

                                          updatedMods.removeWhere(
                                            (element) => element.realIndex == 0,
                                          );

                                          updatedMods.sort((a, b) {
                                            if (a.isDisabled != b.isDisabled) {
                                              return a.isDisabled ? 1 : -1;
                                            }

                                            final aFavorite =
                                                a.favoriteDateTime != null;
                                            final bFavorite =
                                                b.favoriteDateTime != null;

                                            if (aFavorite != bFavorite) {
                                              return aFavorite ? -1 : 1;
                                            }

                                            if (aFavorite) {
                                              final cmp = b.favoriteDateTime!
                                                  .compareTo(
                                                    a.favoriteDateTime!,
                                                  );
                                              if (cmp != 0) return cmp;
                                            }

                                            return compareNatural(
                                              a.modName.toLowerCase(),
                                              b.modName.toLowerCase(),
                                            );
                                          });

                                          updatedMods.insert(
                                            0,
                                            ModData(
                                              modPath: "None",
                                              iconPath: p.join(
                                                group.groupPath,
                                                ConstantVar
                                                    .noneSlotIconFileName,
                                              ),
                                              modName: "None".tr(),
                                              realIndex: 0,
                                              isOldAutoFixed: false,
                                              isSyntaxErrorRemoved: false,
                                              isUnoptimized: false,
                                              isNamespaced: false,
                                              isDisabled: false,
                                              favoriteDateTime: null,
                                            ),
                                          );

                                          return ModGroupData(
                                            groupPath: group.groupPath,
                                            iconPath: group.iconPath,
                                            groupName: group.groupName,
                                            favoriteDateTime:
                                                group.favoriteDateTime,
                                            modsInGroup: updatedMods,
                                            realIndex: group.realIndex,
                                            previousSelectedModOnGroup:
                                                group
                                                    .previousSelectedModOnGroup,
                                          );
                                        }
                                        return group;
                                      }).toList();

                                  ref
                                      .read(modGroupDataProvider.notifier)
                                      .state = updatedGroups;

                                  if (!context.mounted) return;
                                  showUpdateModSnackbar(
                                    context,
                                    ProviderScope.containerOf(
                                      context,
                                      listen: false,
                                    ),
                                  );
                                },
                                label: 'Disable all mods'.tr(),
                              ),
                              CustomMenuItem(
                                scale: sss,
                                onSelected: () async {
                                  if (!context.mounted) return;

                                  String? watchedPath =
                                      DynamicDirectoryWatcher.watcher?.path;
                                  DynamicDirectoryWatcher.stop();

                                  final mods = groupData.modsInGroup;
                                  final modPathsSuccess = <String>[];
                                  for (var mod in mods) {
                                    final success = await enableMod(
                                      mod.modPath,
                                    );
                                    if (success) {
                                      modPathsSuccess.add(mod.modPath);
                                    }
                                  }

                                  if (watchedPath != null) {
                                    DynamicDirectoryWatcher.watch(watchedPath);
                                  }

                                  //UPDATE RIVERPOD
                                  final currentGroups = ref.read(
                                    modGroupDataProvider,
                                  );

                                  final updatedGroups =
                                      currentGroups.map((group) {
                                        if (group.groupPath ==
                                            groupData.groupPath) {
                                          final updatedMods =
                                              group.modsInGroup.map((mod) {
                                                if (modPathsSuccess.contains(
                                                  mod.modPath,
                                                )) {
                                                  return ModData(
                                                    modPath: mod.modPath
                                                        .replaceFirst(
                                                          RegExp(
                                                            r'disabled',
                                                            caseSensitive:
                                                                false,
                                                          ),
                                                          '',
                                                        ),
                                                    iconPath: mod.iconPath,
                                                    modName: mod.modName,
                                                    realIndex: mod.realIndex,
                                                    isOldAutoFixed:
                                                        mod.isOldAutoFixed,
                                                    isSyntaxErrorRemoved:
                                                        mod.isSyntaxErrorRemoved,
                                                    isUnoptimized:
                                                        mod.isUnoptimized,
                                                    isNamespaced:
                                                        mod.isNamespaced,
                                                    isDisabled: false,
                                                    favoriteDateTime:
                                                        mod.favoriteDateTime,
                                                  );
                                                }
                                                return mod;
                                              }).toList();

                                          updatedMods.removeWhere(
                                            (element) => element.realIndex == 0,
                                          );

                                          updatedMods.sort((a, b) {
                                            if (a.isDisabled != b.isDisabled) {
                                              return a.isDisabled ? 1 : -1;
                                            }

                                            final aFavorite =
                                                a.favoriteDateTime != null;
                                            final bFavorite =
                                                b.favoriteDateTime != null;

                                            if (aFavorite != bFavorite) {
                                              return aFavorite ? -1 : 1;
                                            }

                                            if (aFavorite) {
                                              final cmp = b.favoriteDateTime!
                                                  .compareTo(
                                                    a.favoriteDateTime!,
                                                  );
                                              if (cmp != 0) return cmp;
                                            }

                                            return compareNatural(
                                              a.modName.toLowerCase(),
                                              b.modName.toLowerCase(),
                                            );
                                          });

                                          updatedMods.insert(
                                            0,
                                            ModData(
                                              modPath: "None",
                                              iconPath: p.join(
                                                group.groupPath,
                                                ConstantVar
                                                    .noneSlotIconFileName,
                                              ),
                                              modName: "None".tr(),
                                              realIndex: 0,
                                              isOldAutoFixed: false,
                                              isSyntaxErrorRemoved: false,
                                              isUnoptimized: false,
                                              isNamespaced: false,
                                              isDisabled: false,
                                              favoriteDateTime: null,
                                            ),
                                          );

                                          return ModGroupData(
                                            groupPath: group.groupPath,
                                            iconPath: group.iconPath,
                                            groupName: group.groupName,
                                            favoriteDateTime:
                                                group.favoriteDateTime,
                                            modsInGroup: updatedMods,
                                            realIndex: group.realIndex,
                                            previousSelectedModOnGroup:
                                                group
                                                    .previousSelectedModOnGroup,
                                          );
                                        }
                                        return group;
                                      }).toList();

                                  ref
                                      .read(modGroupDataProvider.notifier)
                                      .state = updatedGroups;

                                  if (!context.mounted) return;
                                  showUpdateModSnackbar(
                                    context,
                                    ProviderScope.containerOf(
                                      context,
                                      listen: false,
                                    ),
                                  );
                                },
                                label: 'Enable all mods'.tr(),
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
                                          name: groupData.groupName,
                                          validModsPath:
                                              ref.read(validModsPath)!,
                                          modOrGroupPath: groupData.groupPath,
                                          isGroup: true,
                                        ),
                                  );
                                },
                                label: 'Remove group'.tr(),
                              ),
                            ],
                            child: Tooltip(
                              textAlign: TextAlign.center,
                              preferBelow: true,
                              verticalOffset: 55 * sss,
                              message:
                                  "${groupData.groupName}\n${p.basename(groupData.groupPath)}",
                              textStyle: GoogleFonts.poppins(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 12 * sss,
                              ),
                              waitDuration: Duration(milliseconds: 500),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GroupContainer(
                                    index: index,
                                    size: index == currentPageIndex ? 80 : 65,
                                    selectedColor:
                                        index == currentPageIndex
                                            ? getAccentColor(ref)
                                            : null,
                                    onTap:
                                        () => _carouselSliderGroupController
                                            .animateToPage(
                                              index,
                                              duration: Duration(
                                                milliseconds: 250,
                                              ),
                                              curve: Curves.easeOut,
                                            ),
                                    onMouseEnter:
                                        () => setState(() {
                                          hoveredIndex = index;
                                        }),
                                    onMouseExit:
                                        () => setState(() {
                                          hoveredIndex = null;
                                        }),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (hoveredIndex == index &&
                              index == currentPageIndex)
                            Transform.translate(
                              offset: Offset(-3 * sss, 4 * sss),
                              child: SizedBox(
                                width: 80 * sss,
                                height: 80 * sss,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: GestureDetector(
                                    onTap: () async {
                                      final bool wasFavorite =
                                          groupData.favoriteDateTime != null;
                                      final currentGroups = ref.read(
                                        modGroupDataProvider,
                                      );

                                      final visualOnlyGroups =
                                          currentGroups.map((group) {
                                            if (group.groupPath ==
                                                groupData.groupPath) {
                                              return ModGroupData(
                                                groupPath: group.groupPath,
                                                iconPath: group.iconPath,
                                                groupName: group.groupName,
                                                favoriteDateTime:
                                                    wasFavorite
                                                        ? null
                                                        : DateTime.now(),
                                                modsInGroup: group.modsInGroup,
                                                realIndex: group.realIndex,
                                                previousSelectedModOnGroup:
                                                    group
                                                        .previousSelectedModOnGroup,
                                              );
                                            }
                                            return group;
                                          }).toList();

                                      ref
                                          .read(modGroupDataProvider.notifier)
                                          .state = visualOnlyGroups;

                                      String? watchedPath =
                                          DynamicDirectoryWatcher.watcher?.path;
                                      DynamicDirectoryWatcher.stop();
                                      try {
                                        final favFile = File(
                                          p.join(groupData.groupPath, 'fav'),
                                        );
                                        if (wasFavorite) {
                                          await favFile.delete();
                                        } else {
                                          await favFile.create();
                                        }
                                      } catch (_) {}
                                      if (watchedPath != null) {
                                        DynamicDirectoryWatcher.watch(
                                          watchedPath,
                                        );
                                      }

                                      await Future.delayed(
                                        const Duration(milliseconds: 500),
                                      );

                                      //SORT
                                      final finalGroups = [
                                        ...ref.read(modGroupDataProvider),
                                      ];
                                      final method = ref.read(sortGroupMethod);

                                      finalGroups.sort((a, b) {
                                        final aFavorite =
                                            a.favoriteDateTime != null;
                                        final bFavorite =
                                            b.favoriteDateTime != null;

                                        if (aFavorite != bFavorite) {
                                          return aFavorite ? -1 : 1;
                                        }

                                        if (aFavorite) {
                                          final dateCmp = b.favoriteDateTime!
                                              .compareTo(a.favoriteDateTime!);
                                          if (dateCmp != 0) return dateCmp;
                                        }

                                        if (method == 1) {
                                          return compareNatural(
                                            a.groupName.toLowerCase(),
                                            b.groupName.toLowerCase(),
                                          );
                                        }

                                        return a.realIndex.compareTo(
                                          b.realIndex,
                                        );
                                      });

                                      ref
                                          .read(modGroupDataProvider.notifier)
                                          .state = finalGroups;

                                      //Force current group index update
                                      final length =
                                          ref.read(modGroupDataProvider).length;
                                      final current = ref.read(
                                        currentGroupIndexProvider,
                                      );

                                      ref
                                          .read(
                                            currentGroupIndexProvider.notifier,
                                          )
                                          .state = length > 1
                                              ? (current + 1) % length
                                              : current;

                                      getCurrentGroupName(index);
                                    },
                                    child: MouseRegion(
                                      onEnter:
                                          (_) => setState(() {
                                            hoveredIndex = index;
                                          }),
                                      onExit:
                                          (_) => setState(() {
                                            hoveredIndex = null;
                                          }),
                                      cursor: SystemMouseCursors.click,

                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color.fromARGB(
                                            100,
                                            0,
                                            0,
                                            0,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(3.0 * sss),
                                          child: Icon(
                                            groupData.favoriteDateTime != null
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: Colors.amber,
                                            size:
                                                index == currentPageIndex
                                                    ? 23 * sss
                                                    : 18 * sss,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6 * sss),
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
                mouseCursor: SystemMouseCursors.text,
                focusNode: groupTextFieldFocusNode,
                enabled: groupTextFieldEnabled,
                cursorColor: getAccentColor(ref),
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
                    borderSide: BorderSide(color: getAccentColor(ref)),
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

  @override
  void onKeyEvent(KeyEvent value, Controller? controller) {
    if (ref.read(tabIndexProvider) == 1) {
      if (value.physicalKey == PhysicalKeyboardKey.keyE) {
        _carouselSliderGroupController.nextPage(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (value.physicalKey == PhysicalKeyboardKey.keyQ) {
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
