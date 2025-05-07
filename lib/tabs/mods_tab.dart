import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
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

class _TabModsState extends ConsumerState<TabMods> {
  String getTextDragAndDrop() {
    String text = '';
    if (ref.watch(modGroupDataProvider).isEmpty) {
      text = "Right-click and add group, then you can add mods.";
    } else {
      if (ref.watch(windowIsPinnedProvider)) {
        text =
            'Drag & Drop mod folders here to add mods to this group (1 folder = 1 mod).';
      }
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 67, right: 49, left: 49),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (ref.watch(windowIsPinnedProvider) ||
              ref.watch(modGroupDataProvider).isEmpty)
            Center(
              child: Column(
                children: [
                  if (ref.watch(modGroupDataProvider).isNotEmpty)
                    IgnorePointer(child: Container(height: 9)),
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
                        fontSize: 12,
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
                IgnorePointer(child: Container(height: 10)),
                Center(
                  child: Row(
                    children: [
                      GroupArea(
                        initialGroupIndex: ref.watch(currentGroupIndexProvider),
                      ),

                      IgnorePointer(child: SizedBox(width: 49, height: 200)),

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
    );
  }
}

class GroupArea extends ConsumerStatefulWidget {
  final int initialGroupIndex;
  const GroupArea({super.key, required this.initialGroupIndex});

  @override
  ConsumerState<GroupArea> createState() => _GroupAreaState();
}

class _GroupAreaState extends ConsumerState<GroupArea>
    with ModNavigationListener {
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
  }

  @override
  void dispose() {
    ModNavigationListener.removeListener(this);
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 93.6,
          height: 130,
          child: RightClickMenuWrapper(
            menuItems: [
              PopupMenuItem(
                height: 37,
                onTap: () async {
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
                        duration: Duration(days: 1),
                        behavior: SnackBarBehavior.floating,
                        closeIconColor: Colors.blue,
                        showCloseIcon: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        content: Text(
                          'Max group reached (48 Groups). Unable to add more group.',
                          style: GoogleFonts.poppins(
                            color: Colors.yellow,
                            fontSize: 13,
                          ),
                        ),
                        dismissDirection: DismissDirection.down,
                      ),
                    );
                  }
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
            ],
            child: CarouselSlider.builder(
              itemCount: ref.watch(modGroupDataProvider).length,
              itemBuilder: (context, index, realIndex) {
                return RightClickMenuWrapper(
                  menuItems: [
                    PopupMenuItem(
                      height: 37,
                      onTap: () async {
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
                              duration: Duration(days: 1),
                              behavior: SnackBarBehavior.floating,
                              closeIconColor: Colors.blue,
                              showCloseIcon: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              content: Text(
                                'Max group reached (48 Groups). Unable to add more group.',
                                style: GoogleFonts.poppins(
                                  color: Colors.yellow,
                                  fontSize: 13,
                                ),
                              ),
                              dismissDirection: DismissDirection.down,
                            ),
                          );
                        }
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
                    if (index == currentPageIndex)
                      PopupMenuItem(
                        height: 37,
                        onTap: () {
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
                        value: 'Rename',
                        child: Text(
                          'Rename',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (index == currentPageIndex)
                      PopupMenuItem(
                        height: 37,
                        onTap: () async {
                          await setGroupOrModIcon(
                            ref,
                            ref.read(modGroupDataProvider)[index].groupDir,
                            ref.read(modGroupDataProvider)[index].groupIcon,
                            fromClipboard: true,
                            isGroup: true,
                            modDir: null,
                          );
                        },
                        value: 'Clipboard icon',
                        child: Text(
                          'Clipboard icon',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (index == currentPageIndex)
                      PopupMenuItem(
                        height: 37,
                        onTap: () {
                          setGroupOrModIcon(
                            ref,
                            ref.read(modGroupDataProvider)[index].groupDir,
                            ref.read(modGroupDataProvider)[index].groupIcon,
                            fromClipboard: false,
                            isGroup: true,
                            modDir: null,
                          );
                        },
                        value: 'Change icon',
                        child: Text(
                          'Change icon',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    if (index == currentPageIndex)
                      PopupMenuItem(
                        height: 37,
                        onTap: () {
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
                        value: 'Remove group',
                        child: Text(
                          'Remove group',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                  child: GroupContainer(
                    index: index,
                    currentIndex: currentPageIndex,
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
        Container(height: 2),

        SizedBox(
          width: 93.6,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(0),
                hintText: "Group Name",
                hintStyle: GoogleFonts.poppins(
                  color: const Color.fromARGB(90, 255, 255, 255),
                  fontSize: 13,
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
        height: 93.6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            width: 3,
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
              size: 35,
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
    with WindowListener, ModNavigationListener {
  final CarouselSliderController _carouselSliderModController =
      CarouselSliderController();
  double windowWidth = 0;
  int _currentModRealIndex = 10000;

  double getViewportFraction() {
    if (windowWidth <= 0) return 0.25 * 1.1;

    const k = 1579.37 * 1.1;
    const exponent = 1.3219;
    double result = k / pow(windowWidth, exponent);
    return result;
  }

  void goToSelectedModIndex() {
    setState(() {
      _currentModRealIndex = 10000;
    });
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
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    ModNavigationListener.removeListener(this);
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
    return Expanded(
      child: SizedBox(
        height: 200,
        child: RightClickMenuWrapper(
          menuItems: [
            if (!ref.watch(windowIsPinnedProvider))
              PopupMenuItem(
                height: 37,
                onTap:
                    () =>
                        ref.read(windowIsPinnedProvider.notifier).state = true,
                value: 'Add mod',
                child: Text(
                  'Add mod',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
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
              double itemHeight = isCentered ? 150 * 1.1 : 108 * 1.1;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RightClickMenuWrapper(
          menuItems: [
            PopupMenuItem(
              height: 37,
              onTap: widget.onSelected,
              value: 'Select',
              child: Text(
                'Select',
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
            if (!ref.watch(windowIsPinnedProvider))
              PopupMenuItem(
                height: 37,
                onTap:
                    () =>
                        ref.read(windowIsPinnedProvider.notifier).state = true,
                value: 'Add mod',
                child: Text(
                  'Add mod',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            if (widget.index != 0)
              PopupMenuItem(
                height: 37,
                onTap: () {
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
                value: 'Rename',
                child: Text(
                  'Rename',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),

            if (widget.index != 0)
              PopupMenuItem(
                height: 37,
                onTap: () async {
                  await setGroupOrModIcon(
                    ref,
                    widget.currentGroupData.groupDir,
                    widget.currentGroupData.modsInGroup[widget.index].modIcon,
                    fromClipboard: true,
                    isGroup: false,
                    modDir:
                        widget
                            .currentGroupData
                            .modsInGroup[widget.index]
                            .modDir,
                  );
                },
                value: 'Clipboard icon',
                child: Text(
                  'Clipboard icon',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            if (widget.index != 0)
              PopupMenuItem(
                height: 37,
                onTap: () async {
                  await setGroupOrModIcon(
                    ref,
                    widget.currentGroupData.groupDir,
                    widget.currentGroupData.modsInGroup[widget.index].modIcon,
                    fromClipboard: false,
                    isGroup: false,
                    modDir:
                        widget
                            .currentGroupData
                            .modsInGroup[widget.index]
                            .modDir,
                  );
                },
                value: 'Change icon',
                child: Text(
                  'Change icon',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),

            if (widget.index != 0)
              PopupMenuItem(
                height: 37,
                onTap: () {
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
                value: 'Remove mod',
                child: Text(
                  'Remove mod',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
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
              child: AnimatedContainer(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeOut,
                height: widget.itemHeight,
                width: 108 * 1.1,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    strokeAlign: BorderSide.strokeAlignInside,
                    color:
                        widget.isSelected
                            ? Colors.blue
                            : isHovering
                            ? Colors.white
                            : const Color.fromARGB(127, 255, 255, 255),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                              size: 40,
                              Icons.image_outlined,
                              color: const Color.fromARGB(127, 255, 255, 255),
                            ),
                          )
                          : Icon(
                            size: 45,
                            Icons.close,
                            color: const Color.fromARGB(127, 255, 255, 255),
                          ),
                ),
              ),
            ),
          ),
        ),
        Container(height: 3),
        SizedBox(
          width: 120,
          child: TextField(
            focusNode: modTextFieldFocusNode,
            enabled: modTextFieldEnabled,
            cursorColor: Colors.blue,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(0),
              hintText: "Mod Name",
              hintStyle: GoogleFonts.poppins(
                color: const Color.fromARGB(90, 255, 255, 255),
                fontSize: 12,
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
    }
  }
}

class TabModsNotReady extends StatelessWidget {
  final String notReadyReason;

  const TabModsNotReady({super.key, required this.notReadyReason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Warning",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            notReadyReason,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
          ),
          Container(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "1. Go to Settings.",
                // textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
              Text(
                "2. Make sure Mods Path is correct.",
                // textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
              Text(
                "3. Press Update Mod Data button.",
                // textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TabModsLoading extends StatelessWidget {
  const TabModsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 57),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Loading mods...\nRe-open with hotkey or System Tray if stuck.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
