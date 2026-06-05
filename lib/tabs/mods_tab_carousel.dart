import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
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

class TabModsCarousel extends ConsumerStatefulWidget {
  const TabModsCarousel({super.key});

  @override
  ConsumerState<TabModsCarousel> createState() => _TabModsCarouselState();
}

class _TabModsCarouselState extends ConsumerState<TabModsCarousel>
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
                        ? 81 * sss
                        : 67 * sss,
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: 45 * sss,
                  right: 45 * sss,
                  top: ref.watch(windowIsPinnedProvider) ? 95 * sss : 67 * sss,
                ),
                child: Column(
                  children: [
                    Center(
                      child: Row(
                        children: [
                          GroupAreaCarousel(
                            initialGroupIndex: ref.watch(
                              currentGroupIndexProvider,
                            ),
                          ),

                          IgnorePointer(
                            child: SizedBox(width: 45 * sss, height: 200 * sss),
                          ),

                          ModAreaCarousel(
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
              ),
            ],
          ),
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
                  leading: Icon(Icons.search, size: 20 * sss),
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

class GroupAreaCarousel extends ConsumerStatefulWidget {
  final int initialGroupIndex;
  const GroupAreaCarousel({super.key, required this.initialGroupIndex});

  @override
  ConsumerState<GroupAreaCarousel> createState() => _GroupAreaState();
}

class _GroupAreaState extends ConsumerState<GroupAreaCarousel>
    with ModNavigationListener, ModSearcherListener {
  final CarouselSliderController _carouselSliderGroupController =
      CarouselSliderController();
  final TextEditingController _groupNameTextFieldController =
      TextEditingController();
  bool groupTextFieldEnabled = false;
  final FocusNode groupTextFieldFocusNode = FocusNode();
  int currentPageIndex = 0;
  int? hoveredIndex;

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
                        ref.read(sortGroupMethod) == 0 ? Icons.check : null,
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
                        ref.read(sortGroupMethod) == 1 ? Icons.check : null,
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
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _carouselSliderGroupController.animateToPage(
                                  groupIndex - 1,
                                  duration: Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              });
                            } else {
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
                                    groupData.groupPath,
                                    ref.read(targetGameProvider),
                                  );
                                  if (!context.mounted) return;
                                  if (!success) {
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
                                                  ConstantVar.urlAutoIconInfo,
                                                ),
                                              )) {}
                                            } catch (_) {}
                                          },
                                        ),
                                        dismissDirection: DismissDirection.down,
                                      ),
                                    );
                                  } else {
                                    if (groupData.iconPath != null) {
                                      await ResizeImage(
                                        FileImage(File(groupData.iconPath!)),
                                        width: ConstantVar.groupImageCacheWidth,
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
                                        .state = updatedGroups;
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
                                      groupData.groupPath,
                                      groupData.iconPath,
                                      fromClipboard: true,
                                      isGroup: true,
                                      modPath: null,
                                    );
                                  },
                                  label: 'Clipboard icon'.tr(),
                                ),
                              if (index == currentPageIndex)
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
                              if (index == currentPageIndex)
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
                        if (index == currentPageIndex)
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
                        if (index == currentPageIndex)
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
                                                isNamespaced: mod.isNamespaced,
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
                                              .compareTo(a.favoriteDateTime!);
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
                                            ConstantVar.noneSlotIconFileName,
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
                                            group.previousSelectedModOnGroup,
                                      );
                                    }
                                    return group;
                                  }).toList();

                              ref.read(modGroupDataProvider.notifier).state =
                                  updatedGroups;

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
                        if (index == currentPageIndex)
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
                                final success = await enableMod(mod.modPath);
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
                                                        caseSensitive: false,
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
                                                isNamespaced: mod.isNamespaced,
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
                                              .compareTo(a.favoriteDateTime!);
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
                                            ConstantVar.noneSlotIconFileName,
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
                                            group.previousSelectedModOnGroup,
                                      );
                                    }
                                    return group;
                                  }).toList();

                              ref.read(modGroupDataProvider.notifier).state =
                                  updatedGroups;

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
                        if (index == currentPageIndex)
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
                                      name: _groupNameTextFieldController.text,
                                      validModsPath: ref.read(validModsPath)!,
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
                        verticalOffset: 60 * sss,
                        message:
                            "${groupData.groupName}\n${p.basename(groupData.groupPath)}",
                        textStyle: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 12 * sss,
                        ),
                        waitDuration: Duration(milliseconds: 500),
                        child: GroupContainer(
                          index: index,
                          size: 93.6,
                          onTap:
                              () =>
                                  _carouselSliderGroupController.animateToPage(
                                    index,
                                    duration: Duration(milliseconds: 250),
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
                      ),
                    ),
                    if (index == currentPageIndex && hoveredIndex == index)
                      Transform.translate(
                        offset: Offset(-5 * sss, -5 * sss),
                        child: SizedBox(
                          width: 93.6 * sss,
                          height: 93.6 * sss,
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
                                              group.previousSelectedModOnGroup,
                                        );
                                      }
                                      return group;
                                    }).toList();

                                ref.read(modGroupDataProvider.notifier).state =
                                    visualOnlyGroups;

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
                                  DynamicDirectoryWatcher.watch(watchedPath);
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
                                  final aFavorite = a.favoriteDateTime != null;
                                  final bFavorite = b.favoriteDateTime != null;

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

                                  return a.realIndex.compareTo(b.realIndex);
                                });

                                ref.read(modGroupDataProvider.notifier).state =
                                    finalGroups;

                                //Force current group index update
                                final length =
                                    ref.read(modGroupDataProvider).length;
                                final current = ref.read(
                                  currentGroupIndexProvider,
                                );

                                ref
                                    .read(currentGroupIndexProvider.notifier)
                                    .state = length > 1
                                        ? (current + 1) % length
                                        : current;

                                getCurrentGroupName(
                                  index,
                                  calledFromInitState: true,
                                );
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
                                child: Padding(
                                  padding: EdgeInsets.all(5.0 * sss),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color.fromARGB(100, 0, 0, 0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(3.0 * sss),
                                      child: Icon(
                                        groupData.favoriteDateTime != null
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: Colors.amber,
                                        size: 23 * sss,
                                      ),
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
                selectionColor: getAccentColor(ref, alpha: 127),
              ),
            ),
            child: TextField(
              maxLines: 2,
              focusNode: groupTextFieldFocusNode,
              textInputAction: TextInputAction.done,
              enabled: groupTextFieldEnabled,
              cursorColor: getAccentColor(ref),
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
                    color: getAccentColor(ref),
                    style: BorderStyle.none,
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

class ModAreaCarousel extends ConsumerStatefulWidget {
  final ModGroupData currentGroupData;
  const ModAreaCarousel({super.key, required this.currentGroupData});

  @override
  ConsumerState<ModAreaCarousel> createState() => _ModAreaState();
}

class _ModAreaState extends ConsumerState<ModAreaCarousel>
    with WindowListener, ModNavigationListener, ModSearcherListener {
  final CarouselSliderController _carouselSliderModController =
      CarouselSliderController();
  double windowWidth = 0;
  int _currentModCarouselRealIndex = 10000;

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
      return 0.25 * remap(sss, 0.85, 2.0, 1.3, 1.74) * sss;
    }

    final k = 1579.37 * remap(sss, 0.85, 2.0, 1.3, 1.74) * sss;
    const exponent = 1.3219;
    double result = k / pow(windowWidth, exponent);
    result = result.clamp(0.09767833948818701 * sss, 1.0);
    return result;
  }

  void goToSelectedModIndex() {
    setState(() {
      _currentModCarouselRealIndex = 10000;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _carouselSliderModController.jumpToPage(
            _currentModCarouselRealIndex,
            isRealIndex: true,
          );
          _carouselSliderModController.animateToPage(
            widget.currentGroupData.previousSelectedModOnGroup,
            duration: Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } catch (_) {}
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
        height: 215 * sss * 1.2,
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
              animateToClosest: true,
              initialPage: 0,
              enableInfiniteScroll: true,
              scrollDirection: Axis.horizontal,
              viewportFraction: getViewportFraction(),
              onPageChanged: (index, reason, carouselRealIndex) {
                setState(() {
                  _currentModCarouselRealIndex = carouselRealIndex;
                });
              },
            ),
            itemBuilder: (context, index, carouselRealIndex) {
              bool isCentered =
                  _currentModCarouselRealIndex == carouselRealIndex;
              double itemHeight = isCentered ? 217.8 * sss : 156.816 * sss;
              return ModContainer(
                isSelected:
                    widget.currentGroupData.previousSelectedModOnGroup == index,
                index: index,
                currentGroupData: widget.currentGroupData,
                itemHeight: itemHeight,
                isCentered: isCentered,
                isGrid: false,
                isActiveInGrid: false,
                onSelected: () async {
                  unawaited(
                    simulateKeySelectMod(
                      widget.currentGroupData.realIndex,
                      widget.currentGroupData.modsInGroup[index].realIndex,
                    ),
                  );
                  unawaited(
                    setSelectedModIndex(
                      ref,
                      index, //just view index, not actual mod index
                      widget.currentGroupData.groupPath,
                    ),
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
