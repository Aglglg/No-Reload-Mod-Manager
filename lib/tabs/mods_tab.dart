import 'dart:io';
import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/refreshable_image.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;

class TabMods extends ConsumerStatefulWidget {
  const TabMods({super.key});

  @override
  ConsumerState<TabMods> createState() => _TabModsState();
}

class _TabModsState extends ConsumerState<TabMods> {
  String getTextDragAndDrop() {
    String text = '';
    if (ref.watch(modGroupDataProvider).isEmpty) {
      text = "Right-click and add group then you can add mods.";
    } else {
      if (ref.watch(windowIsPinnedProvider)) {
        text =
            'Drag & Drop mod folders here to add to this group (1 folder = 1 mod).';
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
                    Container(height: 9),
                  Text(
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
                ],
              ),
            ),

          if (ref.watch(modGroupDataProvider).isNotEmpty)
            Column(
              children: [
                Container(height: 10),
                Center(
                  child: Row(
                    children: [
                      GroupArea(),

                      Container(
                        width: 49,
                        height: 200,
                        color: Colors.transparent,
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
    );
  }
}

class GroupArea extends ConsumerStatefulWidget {
  const GroupArea({super.key});

  @override
  ConsumerState<GroupArea> createState() => _GroupAreaState();
}

class _GroupAreaState extends ConsumerState<GroupArea> {
  final CarouselSliderController _carouselSliderGroupController =
      CarouselSliderController();
  final TextEditingController _groupNameTextFieldController =
      TextEditingController();
  bool groupTextFieldEnabled = false;
  final FocusNode groupTextFieldFocusNode = FocusNode();
  final initialPage = 0;
  String currentGroupName = '';
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    getCurrentGroupName(initialPage, calledFromInitState: true);
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
    );

    // 2. Create a new list with updated item
    final newList = [...oldList];
    newList[currentPageIndex] = updatedGroup;

    // 3. Write the new list back to the provider
    ref.read(modGroupDataProvider.notifier).state = newList;

    // 4. Write to the groupname file in disk
    setGroupName(
      ref.read(modGroupDataProvider)[currentPageIndex].groupDir,
      ref.read(modGroupDataProvider)[currentPageIndex].groupName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 93.6,
          height: 130,
          color: Colors.transparent,
          child: RightClickMenuWrapper(
            menuItems: [
              PopupMenuItem(
                onTap: () async {
                  int? groupIndex = await addGroup(
                    ref,
                    p.join(
                      getCurrentModsPath(ref.read(targetGameProvider)),
                      ConstantVar.managedFolderName,
                    ),
                  );

                  if (groupIndex != null) {
                    _carouselSliderGroupController.jumpToPage(groupIndex - 1);
                    getCurrentGroupName(groupIndex - 1);
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => ImageRefreshListener.notifyListeners(),
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
                      onTap: () async {
                        int? groupIndex = await addGroup(
                          ref,
                          p.join(
                            getCurrentModsPath(ref.read(targetGameProvider)),
                            ConstantVar.managedFolderName,
                          ),
                        );

                        if (groupIndex != null) {
                          _carouselSliderGroupController.jumpToPage(
                            groupIndex - 1,
                          );
                          getCurrentGroupName(groupIndex - 1);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => ImageRefreshListener.notifyListeners(),
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
                        onTap: () => print("Change icon"),
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
                        onTap: () => print("Remove group"),
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
                initialPage: initialPage,
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
                enabledBorder: OutlineInputBorder(
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
                    ? Colors.blue
                    : const Color.fromARGB(127, 255, 255, 255),
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          color: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: RefreshableLocalImage(
            fileImage: ref.watch(modGroupDataProvider)[widget.index].groupIcon,
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

class _ModAreaState extends ConsumerState<ModArea> with WindowListener {
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

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    ref.listenManual(currentGroupIndexProvider, (p, n) {
      setState(() {
        _currentModRealIndex = 10000;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _carouselSliderModController.jumpToPage(
            _currentModRealIndex,
            isRealIndex: true,
          );
        } catch (e) {}
      });
    });
    onWindowResize();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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
      child: Container(
        height: 200,
        color: Colors.transparent,
        child: RightClickMenuWrapper(
          menuItems: [
            if (!ref.watch(windowIsPinnedProvider))
              PopupMenuItem(
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
          child:
              widget.currentGroupData.modsInGroup.isNotEmpty
                  ? CarouselSlider.builder(
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
                      bool isSelected = _currentModRealIndex == realIndex;
                      double itemHeight = isSelected ? 150 * 1.1 : 108 * 1.1;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RightClickMenuWrapper(
                            menuItems: [
                              PopupMenuItem(
                                onTap: () {
                                  _carouselSliderModController.animateToPage(
                                    index,
                                    duration: Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                  print("A");
                                },
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
                                  onTap:
                                      () =>
                                          ref
                                              .read(
                                                windowIsPinnedProvider.notifier,
                                              )
                                              .state = true,
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
                              PopupMenuItem(
                                onTap: () => print("Rename mod"),
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
                              PopupMenuItem(
                                onTap: () => print("Change icon"),
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
                              PopupMenuItem(
                                onTap: () => print("Remove mod"),
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
                              onDoubleTap:
                                  isSelected
                                      ? () {
                                        _carouselSliderModController
                                            .animateToPage(
                                              index,
                                              duration: Duration(
                                                milliseconds: 200,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                        print("A");
                                      }
                                      : null,
                              onTap:
                                  () => _carouselSliderModController
                                      .animateToPage(
                                        index,
                                        duration: Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
                                      ),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                height: itemHeight,
                                width: 108 * 1.1,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(
                                    strokeAlign: BorderSide.strokeAlignInside,
                                    color: const Color.fromARGB(
                                      127,
                                      255,
                                      255,
                                      255,
                                    ),
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  clipBehavior: Clip.antiAlias,
                                  child: RefreshableLocalImage(
                                    fileImage:
                                        widget
                                            .currentGroupData
                                            .modsInGroup[index]
                                            .modIcon,
                                    errorWidget: Icon(
                                      size: 40,
                                      Icons.image_outlined,
                                      color: const Color.fromARGB(
                                        127,
                                        255,
                                        255,
                                        255,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(height: 3),
                          SizedBox(
                            width: 120,
                            child: Text(
                              widget
                                  .currentGroupData
                                  .modsInGroup[index]
                                  .modName,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                  : RightClickMenuWrapper(
                    menuItems: [
                      if (!ref.watch(windowIsPinnedProvider))
                        PopupMenuItem(
                          onTap:
                              () =>
                                  ref
                                      .read(windowIsPinnedProvider.notifier)
                                      .state = true,
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
                    child: Center(
                      child: Text(
                        textAlign: TextAlign.center,
                        "Empty",
                        style: GoogleFonts.poppins(
                          color: const Color.fromARGB(127, 255, 255, 255),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
        ),
      ),
    );
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
              "Loading mods...",
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
