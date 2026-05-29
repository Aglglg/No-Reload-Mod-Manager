//TODO: Right-click system

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/casual_style/dds_image_widget.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/custom_icons.dart';
import 'package:no_reload_mod_manager/utils/archive_manager.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_menu_item.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/mods_path_validator.dart';
import 'package:no_reload_mod_manager/utils/rightclick_menu.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:no_reload_mod_manager/utils/stack_collection.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

class TabModsCasual extends ConsumerStatefulWidget {
  const TabModsCasual({super.key});

  @override
  ConsumerState<TabModsCasual> createState() => _TabModsCasualState();
}

class _TabModsCasualState extends ConsumerState<TabModsCasual> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(targetGameProvider, (previous, next) {
      if (next == TargetGame.none) {
        ref.read(currentFullPathCasualStyle.notifier).state = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Padding(
      padding: EdgeInsets.only(
        top: ref.watch(windowIsPinnedProvider) ? 123 * sss : 110 * sss,
        right: 45 * sss,
        left: 45 * sss,
        bottom: 40 * sss,
      ),
      child: Column(
        children: [
          TopBarCasual(),
          SizedBox(height: 10 * sss),
          Expanded(child: ExplorerView()),
        ],
      ),
    );
  }
}

class _SortableEntry {
  final FileSystemEntity entity;
  final int typeOrder;
  final String lowerName;
  final bool isArchive;

  const _SortableEntry({
    required this.entity,
    required this.typeOrder,
    required this.lowerName,
    required this.isArchive,
  });
}

class ExplorerItem extends ConsumerStatefulWidget {
  final int index;
  final FileSystemEntity entry;
  final double width;
  final double height;
  final double spacing;
  final bool isSelected;
  final void Function() onSingleTap;

  const ExplorerItem({
    super.key,
    required this.index,
    required this.entry,
    required this.width,
    required this.height,
    required this.spacing,
    required this.isSelected,
    required this.onSingleTap,
  });

  @override
  ConsumerState<ExplorerItem> createState() => _ExplorerItemState();
}

class _ExplorerItemState extends ConsumerState<ExplorerItem> {
  bool hovered = false;
  bool isManagedFolder = false;
  bool isRemovedManagedFolder = false;
  bool isModsFolder = false;
  bool isImageFile = false;
  bool isDdsFile = false;
  bool isIniFile = false;
  bool isDisabledItem = false;
  String? imagePreviewPath;
  String? modOrGroupName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForImagePreview();
      checkForModOrGroupName();
      checkForSpecialItem();
    });
  }

  @override
  void didUpdateWidget(ExplorerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path) {
      setState(() {
        imagePreviewPath = null;
        modOrGroupName = null;
        isManagedFolder = false;
        isRemovedManagedFolder = false;
        isModsFolder = false;
        isImageFile = false;
        isDdsFile = false;
        isIniFile = false;
        isDisabledItem = false;
      });
      checkForImagePreview();
      checkForModOrGroupName();
      checkForSpecialItem();
    }
  }

  Future<void> checkForImagePreview() async {
    if (widget.entry is! Directory) return;
    for (var name in ConstantVar.modIconFilenames) {
      final path = p.join(widget.entry.path, name);
      if (await File(path).exists()) {
        await ResizeImage(
          FileImage(File(path)),
          width: ConstantVar.explorerViewImageCacheWidth,
        ).evict();
        if (!mounted) return;
        setState(() {
          imagePreviewPath = p.join(widget.entry.path, name);
        });
        return;
      }
    }
  }

  Future<void> checkForModOrGroupName() async {
    if (widget.entry is! Directory) return;
    final dirPath = widget.entry.path;
    String dirNameLower = fastBasename(widget.entry.path).toLowerCase();
    if (dirNameLower.startsWith('disabled')) {
      dirNameLower = dirNameLower.replaceFirst('disabled', '');
    }
    try {
      final fileModname = File(p.join(dirPath, 'modname'));
      final fileGroupname = File(p.join(dirPath, 'groupname'));

      if (await fileModname.exists()) {
        final name = await fileModname.readAsString();
        if (mounted && name.toLowerCase() != dirNameLower) {
          setState(() {
            modOrGroupName = name.trim();
          });
        }
      } else if (await fileGroupname.exists()) {
        final name = await fileGroupname.readAsString();
        if (mounted && name.toLowerCase() != dirNameLower) {
          setState(() {
            modOrGroupName = name.trim();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> checkForSpecialItem() async {
    if (!mounted) return;
    final modsPath = ref.read(validModsPath);
    if (modsPath == null) return;

    String managedPath = p.join(modsPath, ConstantVar.managedFolderName);
    String removedPath = p.join(modsPath, ConstantVar.managedRemovedFolderName);

    if (widget.entry is Directory) {
      bool isManaged = false;
      bool isRemoved = false;
      bool isMods = false;
      bool isDisabled = false;

      isDisabled = fastBasename(
        widget.entry.path.toLowerCase(),
      ).startsWith('disabled');

      try {
        isManaged = await FileSystemEntity.identical(
          managedPath,
          widget.entry.path,
        );
      } catch (_) {}
      try {
        isRemoved = await FileSystemEntity.identical(
          removedPath,
          widget.entry.path,
        );
      } catch (_) {}
      try {
        isMods = await FileSystemEntity.identical(modsPath, widget.entry.path);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        isManagedFolder = isManaged;
        isRemovedManagedFolder = isRemoved;
        isModsFolder = isMods;
        isDisabledItem = isDisabled;
      });
    } else if (widget.entry is File) {
      bool isDisabled = false;
      bool isImage = false;
      bool isIni = false;
      bool isDds = false;

      final ext = p.extension(widget.entry.path).toLowerCase();
      isIni = ext == '.ini';
      isDds = ext == '.dds';
      isImage = _imageExtensions.contains(ext);
      isDisabled =
          isIni &&
          fastBasename(widget.entry.path).toLowerCase().startsWith('disabled');

      if (isImage) {
        await ResizeImage(
          FileImage(File(widget.entry.path)),
          width: ConstantVar.explorerViewImageCacheWidth,
        ).evict();
      }
      if (!mounted) return;
      setState(() {
        isDisabledItem = isDisabled;
        isIniFile = isIni;
        isImageFile = isImage;
        isDdsFile = isDds;
      });
    }
  }

  static const _executableExtensions = {
    '.exe',
    '.com',
    '.scr',
    '.cpl',
    '.efi',
    '.mui',
    '.sys',
    '.drv',
    '.ocx',
    '.dll',
    '.bat',
    '.cmd',
    '.ps1',
    '.vbs',
    '.vbe',
    '.js',
    '.jse',
    '.wsf',
    '.wsh',
    '.msc',
    '.hta',
    '.py',
    '.pyw',
    '.rb',
    '.pl',
    '.php',
    '.jar',
    '.sh',
    '.lnk',
    '.url',
    '.pif',
  };

  static const _imageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif'};

  void showSnackbar(double sss, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2B2930),
        margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        closeIconColor: getAccentColor(ref),
        showCloseIcon: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13 * sss),
        ),
        dismissDirection: DismissDirection.down,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kPrimaryMouseButton) {
          widget.onSingleTap();
        }
      },
      child: GestureDetector(
        onDoubleTapDown: (_) async {
          if (widget.entry is Directory &&
              !ref.read(isCtrlPressed) &&
              !ref.read(isShiftPressed)) {
            await setCurrentPath(ref, widget.entry.path);
          }
          if (widget.entry is File &&
              !ref.read(isCtrlPressed) &&
              !ref.read(isShiftPressed)) {
            final ext = p.extension(widget.entry.path).toLowerCase();
            if (!_executableExtensions.contains(ext)) {
              await Process.run('explorer', [widget.entry.path]);
            } else {
              showSnackbar(
                sss,
                'Right-click and select Open if you insist to open this executable file',
              );
            }
          }
        },
        child: MouseRegion(
          onEnter:
              (_) => setState(() {
                hovered = true;
              }),
          onExit:
              (_) => setState(() {
                hovered = false;
              }),
          child: Tooltip(
            richMessage:
                modOrGroupName != null
                    ? TextSpan(
                      children: [
                        TextSpan(
                          text: "$modOrGroupName\n",
                          style: GoogleFonts.poppins(
                            fontSize: 12 * sss,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: fastBasename(widget.entry.path),
                          style: GoogleFonts.poppins(
                            fontSize: 12 * sss,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    )
                    : null,
            message:
                modOrGroupName == null
                    ? isManagedFolder
                        ? "Contains mods that's added to No-Reload Style and some required mod manager files"
                        : isRemovedManagedFolder
                        ? "Contains mods that's removed from No-Reload Style, safe to be deleted if it's unused mod"
                        : isModsFolder
                        ? "Contains your mods"
                        : fastBasename(widget.entry.path)
                    : null,
            textStyle: GoogleFonts.poppins(
              fontSize: 12 * sss,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            constraints: BoxConstraints(maxWidth: 300 * sss),
            waitDuration: Duration(milliseconds: 1000),

            child: Container(
              width: widget.width,
              height: widget.height,
              margin: EdgeInsets.only(
                right: widget.spacing,
                bottom: widget.spacing,
              ),
              decoration:
                  widget.isSelected
                      ? BoxDecoration(
                        color: Color.fromARGB(100, 127, 127, 127),
                        borderRadius: BorderRadius.all(
                          Radius.circular(5 * sss),
                        ),
                        border: Border.all(
                          color: Color.fromARGB(
                            hovered ? 100 : 50,
                            255,
                            255,
                            255,
                          ),
                          strokeAlign: BorderSide.strokeAlignInside,
                          width: 1.5 * sss,
                        ),
                      )
                      : BoxDecoration(
                        color: Color.fromARGB(0, 127, 127, 127),
                        borderRadius: BorderRadius.all(
                          Radius.circular(5 * sss),
                        ),
                        border: Border.all(
                          color: Color.fromARGB(
                            hovered ? 100 : 0,
                            255,
                            255,
                            255,
                          ),
                          strokeAlign: BorderSide.strokeAlignInside,
                          width: 1.5 * sss,
                        ),
                      ),
              child: Padding(
                padding: EdgeInsets.all(8.0 * sss),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        isImageFile
                            ? Padding(
                              padding: EdgeInsets.only(bottom: 5 * sss),
                              child: SizedBox(
                                height: 80 * sss,
                                child: Image.file(
                                  File(widget.entry.path),
                                  errorBuilder:
                                      (context, error, stackTrace) => Icon(
                                        Icons.image_rounded,
                                        size: 85 * sss,
                                        color:
                                            hovered
                                                ? getAccentColor(ref)
                                                : const Color.fromARGB(
                                                  255,
                                                  169,
                                                  169,
                                                  169,
                                                ),
                                      ),
                                  cacheWidth:
                                      ConstantVar.explorerViewImageCacheWidth,
                                  fit: BoxFit.contain,
                                  color: Color.fromARGB(
                                    hovered
                                        ? 255
                                        : isDisabledItem
                                        ? 127
                                        : 255,
                                    255,
                                    255,
                                    255,
                                  ),
                                  colorBlendMode: BlendMode.modulate,
                                ),
                              ),
                            )
                            : isDdsFile
                            ? DdsImage(
                              height: 85 * sss,
                              width: 85 * sss,
                              path: widget.entry.path,
                            )
                            : Center(
                              child: Icon(
                                widget.entry is Directory
                                    ? isManagedFolder || isRemovedManagedFolder
                                        ? CustomIcons.folder_bolt_rounded
                                        : isModsFolder
                                        ? CustomIcons.folder_home_rounded
                                        : Icons.folder_rounded
                                    : widget.entry is File
                                    ? SevenZip.isSupported(widget.entry.path)
                                        ? Icons.folder_zip_rounded
                                        : isIniFile
                                        ? Icons.text_snippet_rounded
                                        : Icons.insert_drive_file_rounded
                                    : Icons.file_present_rounded,
                                size: 85 * sss,
                                color:
                                    hovered
                                        ? getAccentColor(ref)
                                        : isDisabledItem
                                        ? const Color.fromARGB(255, 90, 90, 90)
                                        : const Color.fromARGB(
                                          255,
                                          169,
                                          169,
                                          169,
                                        ),
                              ),
                            ),
                        if (widget.entry is Directory &&
                            imagePreviewPath != null &&
                            !isManagedFolder &&
                            !isRemovedManagedFolder)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 25 * sss),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6 * sss),
                                child: Container(
                                  width: 64 * sss,
                                  height: 43 * sss,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      100,
                                      100,
                                      100,
                                      100,
                                    ),
                                  ),
                                  child: Image.file(
                                    File(imagePreviewPath!),
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            SizedBox(),
                                    cacheWidth:
                                        ConstantVar.explorerViewImageCacheWidth,
                                    fit: BoxFit.cover,
                                    color: Color.fromARGB(
                                      hovered
                                          ? 255
                                          : isDisabledItem
                                          ? 127
                                          : 255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    colorBlendMode: BlendMode.modulate,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      modOrGroupName != null
                          ? modOrGroupName!
                          : fastBasename(widget.entry.path),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12 * sss,
                        fontWeight: FontWeight.w500,
                        color:
                            hovered
                                ? getAccentColor(ref)
                                : isDisabledItem
                                ? const Color.fromARGB(255, 90, 90, 90)
                                : const Color.fromARGB(255, 169, 169, 169),
                      ),
                    ),
                    if (modOrGroupName != null)
                      Text(
                        fastBasename(widget.entry.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 10 * sss,
                          fontWeight: FontWeight.w500,
                          color: const Color.fromARGB(255, 127, 127, 127),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExplorerView extends ConsumerStatefulWidget {
  const ExplorerView({super.key});

  @override
  ConsumerState<ExplorerView> createState() => ExplorerViewState();
}

class ExplorerViewState extends ConsumerState<ExplorerView> {
  List<FileSystemEntity> _entries = [];
  Set<int> selectedItems = {};
  int lastSelectedItem = 0;
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initCurrentPath();
    });

    ref.listenManual(currentFullPathCasualStyle, (previous, next) {
      _loadEntries(next);
      _scrollToStart();

      resetItemSelection();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToStart() async {
    // Wait until scrollController has a valid position
    await Future.delayed(const Duration(milliseconds: 100));
    if (!scrollController.hasClients) return;

    await scrollController.animateTo(
      scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> initCurrentPath() async {
    final modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      String? currentPath = getCurrentPath(ref);
      if (currentPath != null) {
        final validatedPath = await getValidCurrentPath(currentPath, modsPath);
        if (validatedPath != currentPath) {
          currentPath = validatedPath;
        }
      } else {
        currentPath = modsPath;
      }

      await setCurrentPath(ref, currentPath);

      await _loadEntries(currentPath);
    }
  }

  int _loadGeneration = 0;

  Future<void> _loadEntries(String? path) async {
    if (path == null) return;

    final generation = ++_loadGeneration;

    final entries = <FileSystemEntity>[];

    await for (final entity in Directory(
      path,
    ).list(followLinks: false, recursive: false)) {
      if (_loadGeneration != generation) return; // superseded
      entries.add(entity);

      if (entries.length % 100 == 0) {
        if (!mounted || _loadGeneration != generation) return;
        setState(() {
          _entries = entries.toList(growable: false);
        });
        await Future.delayed(Duration.zero);
      }
    }

    if (!mounted || _loadGeneration != generation) return;
    setState(() {
      _entries = entries;
    });

    await Future.microtask(() {
      if (!mounted || _loadGeneration != generation) return;
      final sorted = _sortEntries(entries);
      if (mounted && _loadGeneration == generation) {
        setState(() {
          _entries = sorted;
        });
      }
    });
  }

  void resetItemSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        selectedItems = {};
        lastSelectedItem = 0;
      });
      ref.read(isShiftPressed.notifier).state = false;
      ref.read(isCtrlPressed.notifier).state = false;
    });
  }

  List<FileSystemEntity> _sortEntries(List<FileSystemEntity> entries) {
    final modsPath = ref.read(validModsPath);
    final sortable =
        entries
            .where((e) => fastBasename(e.path).toLowerCase() != 'desktop.ini')
            .map((e) {
              bool archive = SevenZip.isSupported(e.path);
              bool ini = e.path.endsWith('.ini');
              String lowerName = fastBasename(e.path).toLowerCase();
              bool disabled = lowerName.startsWith('disabled');

              bool isModsFolder =
                  modsPath != null &&
                  e.path.toLowerCase() == modsPath.toLowerCase();
              bool isManagedFolder =
                  modsPath != null &&
                  e.path.toLowerCase() ==
                      p
                          .join(modsPath, ConstantVar.managedFolderName)
                          .toLowerCase();
              bool isManagedRemovedFolder =
                  modsPath != null &&
                  e.path.toLowerCase() ==
                      p
                          .join(modsPath, ConstantVar.managedRemovedFolderName)
                          .toLowerCase();

              return _SortableEntry(
                entity: e,
                typeOrder:
                    isModsFolder || isManagedFolder || isManagedRemovedFolder
                        ? -1
                        : e is Directory
                        ? disabled
                            ? 1
                            : 0
                        : archive
                        ? disabled
                            ? 3
                            : 2
                        : ini
                        ? disabled
                            ? 5
                            : 4
                        : 6,
                lowerName: lowerName,
                isArchive: archive,
              );
            })
            .toList();

    sortable.sort((a, b) {
      final typeDiff = a.typeOrder - b.typeOrder;
      if (typeDiff != 0) return typeDiff;
      return compareNatural(a.lowerName, b.lowerName);
    });

    return sortable.map((e) => e.entity).toList();
  }

  Future<void> handleForwardAndBackwardNavigation(
    PointerDownEvent event,
  ) async {
    StateProvider<StackCollection<String>>? explorerViewOpenedPaths;
    StateProvider<StackCollection<String>>? explorerViewOpenedForwardPaths;

    switch (ref.read(targetGameProvider)) {
      case TargetGame.Arknights_Endfield:
        explorerViewOpenedPaths = explorerViewOpenedPathsEndfield;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsEndfield;
        break;
      case TargetGame.Genshin_Impact:
        explorerViewOpenedPaths = explorerViewOpenedPathsGenshin;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsGenshin;
        break;
      case TargetGame.Honkai_Star_Rail:
        explorerViewOpenedPaths = explorerViewOpenedPathsHsr;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsHsr;
        break;
      case TargetGame.Wuthering_Waves:
        explorerViewOpenedPaths = explorerViewOpenedPathsWuwa;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsWuwa;
        break;
      case TargetGame.Zenless_Zone_Zero:
        explorerViewOpenedPaths = explorerViewOpenedPathsZzz;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsZzz;
        break;
      default:
    }

    if (event.buttons == kBackMouseButton && explorerViewOpenedPaths != null) {
      final pathHistory = ref.read(explorerViewOpenedPaths);
      final lastPath = pathHistory.pop();
      if (lastPath != null) {
        await setCurrentPath(
          ref,
          lastPath,
          addToHistory: false,
          addToForwardHistory: true,
        );
      }
    } else if (event.buttons == kForwardMouseButton &&
        explorerViewOpenedForwardPaths != null) {
      final pathHistory = ref.read(explorerViewOpenedForwardPaths);
      final lastPath = pathHistory.pop();
      if (lastPath != null) {
        await setCurrentPath(ref, lastPath, clearForwardHistory: false);
      }
    }
  }

  void _onBackgroundTap() {
    if (!ref.read(isShiftPressed) && !ref.read(isCtrlPressed)) {
      setState(() => selectedItems = {});
    }
  }

  Widget backgroundRightClickMenu(double sss, Widget child) {
    return RightClickMenuRegion(
      menuItems: <ContextMenuEntry>[
        if (ref.watch(tabIndexProvider) != 2)
          CustomMenuItem(
            scale: sss,
            onSelected: () async {
              triggerRefresh(ref);
            },
            label: 'Refresh'.tr(),
          ),
        ref.watch(windowIsPinnedProvider)
            ? CustomMenuItem(
              scale: sss,
              onSelected:
                  () => ref.read(windowIsPinnedProvider.notifier).state = false,
              label: 'Unpin window'.tr(),
            )
            : CustomMenuItem(
              scale: sss,
              onSelected:
                  () => ref.read(windowIsPinnedProvider.notifier).state = true,
              label: 'Pin window'.tr(),
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
            ref.read(targetGameProvider.notifier).state = TargetGame.none;
            await windowManager.hide();
            clearImagesCache();
            DynamicDirectoryWatcher.stop();
          },
          label: 'Hide window'.tr(),
        ),
      ],
      additionalCalledFunction: _onBackgroundTap,
      child: GestureDetector(
        onTap: _onBackgroundTap,
        child: Container(color: Colors.transparent, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Listener(
      onPointerDown: (event) async {
        await handleForwardAndBackwardNavigation(event);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = 120 * sss;
          final itemHeight = 180 * sss;
          final spacing = 10 * sss;

          final itemsPerRow =
              ((constraints.maxWidth + spacing) / (itemWidth + spacing))
                  .floor();

          final rowCount = (_entries.length / itemsPerRow).ceil();

          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
              scrollbars: false,
            ),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thickness: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return 8 * sss;
                  }
                  return 3 * sss;
                }),
              ),
              child: Scrollbar(
                controller: scrollController,
                radius: const Radius.circular(999),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverFixedExtentList(
                      itemExtent: itemHeight + spacing, // was itemHeight
                      delegate: SliverChildBuilderDelegate((context, rowIndex) {
                        final start = rowIndex * itemsPerRow;
                        final end = min(start + itemsPerRow, _entries.length);
                        return Column(
                          children: [
                            SizedBox(
                              height: itemHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (int i = start; i < end; i++) ...[
                                    ExplorerItem(
                                      index: i,
                                      entry: _entries[i],
                                      width: itemWidth,
                                      height: itemHeight,
                                      spacing: 0, // margin externalized
                                      isSelected: selectedItems.contains(i),
                                      onSingleTap: () {
                                        setState(() {
                                          if (ref.read(isShiftPressed)) {
                                            int greaterNumber =
                                                lastSelectedItem > i
                                                    ? lastSelectedItem
                                                    : i;
                                            int leastNumber =
                                                lastSelectedItem < i
                                                    ? lastSelectedItem
                                                    : i;
                                            Set<int> selections = {};
                                            if (ref.read(isCtrlPressed)) {
                                              selections = selectedItems;
                                            }
                                            for (
                                              var i = leastNumber;
                                              i <= greaterNumber;
                                              i++
                                            ) {
                                              selections.add(i);
                                            }
                                            selectedItems = selections;
                                            return;
                                          } else if (ref.read(isCtrlPressed)) {
                                            final temp = selectedItems;
                                            if (temp.contains(i)) {
                                              temp.remove(i);
                                            } else {
                                              temp.add(i);
                                            }
                                            selectedItems = temp;
                                          } else {
                                            selectedItems = {i};
                                          }

                                          lastSelectedItem = i;
                                        });
                                      },
                                    ),
                                    backgroundRightClickMenu(
                                      sss,
                                      SizedBox(
                                        width: spacing,
                                        height: itemHeight,
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: backgroundRightClickMenu(
                                      sss,
                                      SizedBox(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            backgroundRightClickMenu(
                              sss,
                              SizedBox(height: spacing, width: double.infinity),
                            ),
                          ],
                        );
                      }, childCount: rowCount),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: backgroundRightClickMenu(sss, SizedBox.expand()),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TopBarCasual extends ConsumerStatefulWidget {
  const TopBarCasual({super.key});

  @override
  ConsumerState<TopBarCasual> createState() => _TopBarCasualState();
}

class _TopBarCasualState extends ConsumerState<TopBarCasual> {
  final pathTextfieldController = TextEditingController();
  final pathTextfieldFocusNode = FocusNode();
  bool hoveredPathTextfield = false;
  bool pathTextfieldFocused = false;

  bool backwardHovered = false;
  bool forwardHovered = false;
  bool searchHovered = false;

  @override
  void initState() {
    super.initState();
    pathTextfieldFocusNode.addListener(() async {
      setState(() {
        pathTextfieldFocused = pathTextfieldFocusNode.hasFocus;
      });
      pathTextfieldController.text = await getTextFieldPath();

      pathTextfieldController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: pathTextfieldController.text.length,
      );
    });
  }

  @override
  void dispose() {
    pathTextfieldController.dispose();
    pathTextfieldFocusNode.dispose();
    super.dispose();
  }

  Future<String> getTextFieldPath() async {
    final modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      String? currentPath = getCurrentPath(ref);
      if (currentPath != null) {
        final validatedPath = await getValidCurrentPath(currentPath, modsPath);
        if (validatedPath != currentPath) {
          currentPath = validatedPath;
          await setCurrentPath(ref, currentPath);
        }
      } else {
        currentPath = modsPath;
      }
      final relPath = p.relative(
        currentPath,
        from: p.dirname(p.dirname(modsPath)),
      );
      return relPath;
    }
    return "";
  }

  Future<void> handleForwardAndBackwardNavigation(
    PointerDownEvent event,
  ) async {
    StateProvider<StackCollection<String>>? explorerViewOpenedPaths;
    StateProvider<StackCollection<String>>? explorerViewOpenedForwardPaths;

    switch (ref.read(targetGameProvider)) {
      case TargetGame.Arknights_Endfield:
        explorerViewOpenedPaths = explorerViewOpenedPathsEndfield;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsEndfield;
        break;
      case TargetGame.Genshin_Impact:
        explorerViewOpenedPaths = explorerViewOpenedPathsGenshin;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsGenshin;
        break;
      case TargetGame.Honkai_Star_Rail:
        explorerViewOpenedPaths = explorerViewOpenedPathsHsr;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsHsr;
        break;
      case TargetGame.Wuthering_Waves:
        explorerViewOpenedPaths = explorerViewOpenedPathsWuwa;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsWuwa;
        break;
      case TargetGame.Zenless_Zone_Zero:
        explorerViewOpenedPaths = explorerViewOpenedPathsZzz;
        explorerViewOpenedForwardPaths = explorerViewOpenedForwardPathsZzz;
        break;
      default:
    }

    if (event.buttons == kBackMouseButton && explorerViewOpenedPaths != null) {
      final pathHistory = ref.read(explorerViewOpenedPaths);
      final lastPath = pathHistory.pop();
      if (lastPath != null) {
        await setCurrentPath(
          ref,
          lastPath,
          addToHistory: false,
          addToForwardHistory: true,
        );
      }
    } else if (event.buttons == kForwardMouseButton &&
        explorerViewOpenedForwardPaths != null) {
      final pathHistory = ref.read(explorerViewOpenedForwardPaths);
      final lastPath = pathHistory.pop();
      if (lastPath != null) {
        await setCurrentPath(ref, lastPath, clearForwardHistory: false);
      }
    }
  }

  bool backwardButtonEmpty() {
    StateProvider<StackCollection<String>>? provider;
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Arknights_Endfield:
        provider = explorerViewOpenedPathsEndfield;
        break;
      case TargetGame.Genshin_Impact:
        provider = explorerViewOpenedPathsGenshin;
        break;
      case TargetGame.Honkai_Star_Rail:
        provider = explorerViewOpenedPathsHsr;
        break;
      case TargetGame.Wuthering_Waves:
        provider = explorerViewOpenedPathsWuwa;
        break;
      case TargetGame.Zenless_Zone_Zero:
        provider = explorerViewOpenedPathsZzz;
        break;
      default:
    }
    if (provider != null) {
      return ref.watch(provider).isEmpty;
    }
    return false;
  }

  bool forwardButtonEmpty() {
    StateProvider<StackCollection<String>>? provider;
    switch (ref.watch(targetGameProvider)) {
      case TargetGame.Arknights_Endfield:
        provider = explorerViewOpenedForwardPathsEndfield;
        break;
      case TargetGame.Genshin_Impact:
        provider = explorerViewOpenedForwardPathsGenshin;
        break;
      case TargetGame.Honkai_Star_Rail:
        provider = explorerViewOpenedForwardPathsHsr;
        break;
      case TargetGame.Wuthering_Waves:
        provider = explorerViewOpenedForwardPathsWuwa;
        break;
      case TargetGame.Zenless_Zone_Zero:
        provider = explorerViewOpenedForwardPathsZzz;
        break;
      default:
    }
    if (provider != null) {
      return ref.watch(provider).isEmpty;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MouseRegion(
          onEnter:
              (_) => setState(() {
                backwardHovered = true;
              }),
          onExit:
              (_) => setState(() {
                backwardHovered = false;
              }),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            child: Tooltip(
              message: "Backward (side mouse button)",
              textStyle: GoogleFonts.poppins(
                fontSize: 12 * sss,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              constraints: BoxConstraints(maxWidth: 300 * sss),
              waitDuration: Duration(milliseconds: 1000),
              child: Icon(
                Icons.keyboard_backspace_rounded,
                size: 24 * sss,
                color:
                    backwardHovered
                        ? getAccentColor(ref)
                        : Color.fromARGB(
                          backwardButtonEmpty() ? 90 : 169,
                          255,
                          255,
                          255,
                        ),
              ),
            ),
            onTap:
                () => handleForwardAndBackwardNavigation(
                  PointerDownEvent(buttons: kBackMouseButton),
                ),
          ),
        ),
        SizedBox(width: 7 * sss),
        MouseRegion(
          onEnter:
              (_) => setState(() {
                forwardHovered = true;
              }),
          onExit:
              (_) => setState(() {
                forwardHovered = false;
              }),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            child: Tooltip(
              message: "Forward (side mouse button)",
              textStyle: GoogleFonts.poppins(
                fontSize: 12 * sss,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              constraints: BoxConstraints(maxWidth: 300 * sss),
              waitDuration: Duration(milliseconds: 1000),
              child: Transform.flip(
                flipX: true,
                child: Icon(
                  Icons.keyboard_backspace_rounded,
                  size: 23 * sss,
                  color:
                      forwardHovered
                          ? getAccentColor(ref)
                          : Color.fromARGB(
                            forwardButtonEmpty() ? 90 : 169,
                            255,
                            255,
                            255,
                          ),
                ),
              ),
            ),
            onTap:
                () => handleForwardAndBackwardNavigation(
                  PointerDownEvent(buttons: kForwardMouseButton),
                ),
          ),
        ),
        SizedBox(width: 10 * sss),

        Icon(
          Icons.folder_rounded,
          size: 24 * sss,
          color: const Color.fromARGB(169, 255, 255, 255),
        ),
        SizedBox(width: 10 * sss),

        // PATH
        Expanded(
          flex: 4,
          child: MouseRegion(
            onEnter:
                (_) => setState(() {
                  hoveredPathTextfield = true;
                }),
            onExit:
                (_) => setState(() {
                  hoveredPathTextfield = false;
                }),
            child: Stack(
              children: [
                PathTextField(
                  isHovered: hoveredPathTextfield,
                  pathTextfieldController: pathTextfieldController,
                  pathTextfieldFocusNode: pathTextfieldFocusNode,
                  showText: pathTextfieldFocused,
                ),
                PathBreadcrumbs(
                  show: !pathTextfieldFocused,
                  isHovered: hoveredPathTextfield,
                  onEmptyAreaTap: () {
                    pathTextfieldFocusNode.requestFocus();
                  },
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: 10 * sss),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            child: Icon(
              Icons.sort_rounded,
              size: 24 * sss,
              color: const Color.fromARGB(169, 255, 255, 255),
            ),
          ),
        ),
        SizedBox(width: 7 * sss),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            child: Icon(
              Icons.search_rounded,
              size: 23 * sss,
              color: const Color.fromARGB(169, 255, 255, 255),
            ),
          ),
        ),
      ],
    );
  }
}

class PathTextField extends ConsumerStatefulWidget {
  final TextEditingController pathTextfieldController;
  final FocusNode pathTextfieldFocusNode;
  final bool isHovered;
  final bool showText;
  const PathTextField({
    super.key,
    required this.pathTextfieldController,
    required this.pathTextfieldFocusNode,
    required this.isHovered,
    required this.showText,
  });

  @override
  ConsumerState<PathTextField> createState() => _PathTextFieldState();
}

class _PathTextFieldState extends ConsumerState<PathTextField> {
  void showSnackbar(double sss, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2B2930),
        margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        closeIconColor: getAccentColor(ref),
        showCloseIcon: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.yellow, fontSize: 13 * sss),
        ),
        dismissDirection: DismissDirection.down,
      ),
    );
  }

  Future<void> inputPath(double sss, String path) async {
    final modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      if (path.isEmpty) {
        path = p.dirname(modsPath);
      }
      //example D:\XXMI Launcher, not D:\XXMI Launcher\GIMI (not the MI path)
      final basePath = p.dirname(p.dirname(modsPath));
      String? fullPath;

      // Strip surrounding quotes
      path = path.trim();
      if ((path.startsWith('"') && path.endsWith('"')) ||
          (path.startsWith("'") && path.endsWith("'"))) {
        path = path.substring(1, path.length - 1).trim();
      }

      if (path.startsWith(r"\\?\")) {
        path = path.replaceFirst(r"\\?\", '');
      }

      if (p.isRelative(path)) {
        fullPath = p.join(basePath, path);
      } else {
        fullPath = path;
      }

      fullPath = ModsPathValidator.sanitizePath(fullPath);
      final currentPath = ref.read(currentFullPathCasualStyle);

      if (fullPath == null) {
        showSnackbar(sss, "The specified path doesn't exist");
      } else {
        final valid = await isValidCurrentPath(fullPath, modsPath);
        switch (valid) {
          case -1:
            showSnackbar(
              sss,
              "The specified path is outside of the working directory",
            );
            break;
          case 0:
            showSnackbar(sss, "The specified path doesn't exist");
            break;
          case 1:
            if (currentPath != fullPath) {
              await setCurrentPath(ref, fullPath);
            }
            break;
          case 2:
            if (currentPath != p.dirname(fullPath)) {
              await setCurrentPath(ref, p.dirname(fullPath));
            }
            break;
          default:
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return TextField(
      controller: widget.pathTextfieldController,
      focusNode: widget.pathTextfieldFocusNode,
      onSubmitted: (_) async {
        await inputPath(sss, widget.pathTextfieldController.text);
      },
      onTapOutside: (_) async {
        widget.pathTextfieldFocusNode.unfocus();
        await inputPath(sss, widget.pathTextfieldController.text);
      },
      decoration: InputDecoration(
        isDense: true,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: const Color.fromARGB(100, 255, 255, 255),
            style: widget.isHovered ? BorderStyle.solid : BorderStyle.none,
            width: 2 * sss,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: getAccentColor(ref), width: 2 * sss),
        ),
      ),
      style: GoogleFonts.poppins(
        fontSize: 14 * sss,
        fontWeight: FontWeight.w500,
        color: widget.showText ? Colors.white : Colors.transparent,
      ),
    );
  }
}

class PathBreadcrumbs extends ConsumerStatefulWidget {
  final void Function() onEmptyAreaTap;
  final bool show;
  final bool isHovered;
  const PathBreadcrumbs({
    super.key,
    required this.show,
    required this.isHovered,
    required this.onEmptyAreaTap,
  });

  @override
  ConsumerState<PathBreadcrumbs> createState() => _PathBreadcrumbsState();
}

class _PathBreadcrumbsState extends ConsumerState<PathBreadcrumbs>
    with WindowListener {
  // folderName, fullPath
  List<(String, String)> splittedPaths = [];
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      constructSplittedPaths();
    });
    listenToChangesInCurrentPath();
    _scrollToEnd();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    scrollController.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() {
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(covariant PathBreadcrumbs oldWidget) {
    if (!oldWidget.show) {
      _scrollToEnd();
    } else {
      if (!widget.isHovered) {
        prepareScrollToEnd();
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> prepareScrollToEnd() async {
    await Future.delayed(Duration(seconds: 2));
    if (!widget.isHovered && mounted) {
      await _scrollToEnd();
    }
  }

  Future<void> _scrollToEnd() async {
    // Wait until scrollController has a valid position
    await Future.delayed(const Duration(milliseconds: 100));
    if (!scrollController.hasClients) return;

    await scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void listenToChangesInCurrentPath() {
    ref.listenManual(currentFullPathCasualStyle, (_, _) {
      constructSplittedPaths();
    });
  }

  Future<void> constructSplittedPaths() async {
    final modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      String? currentPath = getCurrentPath(ref);
      if (currentPath != null) {
        final validatedPath = await getValidCurrentPath(currentPath, modsPath);
        if (validatedPath != currentPath) {
          currentPath = validatedPath;
          await setCurrentPath(ref, currentPath);
        }
      } else {
        currentPath = modsPath;
      }
      final relPath = p.relative(
        currentPath,
        from: p.dirname(p.dirname(modsPath)),
      );

      final parts =
          relPath.split(p.separator).where((e) => e.trim().isNotEmpty).toList();

      final List<(String, String)> result = [];

      String accumulatedPath = p.dirname(p.dirname(modsPath));

      for (final part in parts) {
        accumulatedPath = p.join(accumulatedPath, part);

        result.add((
          part, // folder name
          accumulatedPath, // full path
        ));
      }

      setState(() {
        splittedPaths = result;
      });
    }
  }

  List<Widget> getClickablePaths(double sss) {
    final widgets =
        splittedPaths.asMap().entries.expand((entry) {
          final index = entry.key;
          final value = entry.value;
          final folderName = value.$1;
          final fullPath = value.$2;

          return [
            ClickableText(
              text: folderName,
              fontSize: 14 * sss,
              color:
                  index == splittedPaths.length - 1
                      ? getAccentColor(ref)
                      : const Color.fromARGB(169, 255, 255, 255),
              hoverColor: Colors.white,
              onTap: () async {
                await setCurrentPath(ref, fullPath);
              },
            ),

            if (index != splittedPaths.length - 1)
              Text(
                p.separator,
                style: GoogleFonts.poppins(
                  fontSize: 14 * sss,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(169, 255, 255, 255),
                ),
              ),
          ];
        }).toList();

    widgets.add(
      MouseRegion(
        cursor: SystemMouseCursors.text,
        child: GestureDetector(
          onTap: widget.onEmptyAreaTap,
          child: Container(
            width: 40 * sss,
            height: 15 * sss,
            color: Colors.transparent,
          ),
        ),
      ),
    );
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return widget.show
        ? ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: scrollController,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: getClickablePaths(sss),
            ),
          ),
        )
        : SizedBox();
  }
}

class ClickableText extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final double fontSize;
  final Color color;
  final Color? hoverColor;

  const ClickableText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.color,
    this.onTap,
    this.hoverColor,
  });

  @override
  State<ClickableText> createState() => _ClickableTextState();
}

class _ClickableTextState extends State<ClickableText> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          widget.text,
          style: GoogleFonts.poppins(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
            color:
                _isHovering && widget.hoverColor != null
                    ? widget.hoverColor
                    : widget.color,
          ),
        ),
      ),
    );
  }
}

Future<void> addOpenedPathHistory(WidgetRef ref, String fullPath) async {
  StateProvider<StackCollection<String>>? prov;

  switch (ref.read(targetGameProvider)) {
    case TargetGame.Arknights_Endfield:
      prov = explorerViewOpenedPathsEndfield;
      break;
    case TargetGame.Genshin_Impact:
      prov = explorerViewOpenedPathsGenshin;
      break;
    case TargetGame.Honkai_Star_Rail:
      prov = explorerViewOpenedPathsHsr;
      break;
    case TargetGame.Wuthering_Waves:
      prov = explorerViewOpenedPathsWuwa;
      break;
    case TargetGame.Zenless_Zone_Zero:
      prov = explorerViewOpenedPathsZzz;
      break;
    default:
  }

  if (prov != null) {
    final addedPaths = ref.read(prov);
    final lastAddedPath = addedPaths.peek;
    if (lastAddedPath == null) {
      final newAddedPaths = addedPaths;
      newAddedPaths.push(fullPath);
      ref.read(prov.notifier).state = newAddedPaths;
    } else if (!await FileSystemEntity.identical(lastAddedPath, fullPath)) {
      final newAddedPaths = addedPaths;
      newAddedPaths.push(fullPath);
      ref.read(prov.notifier).state = newAddedPaths;
    }
  }
}

Future<void> addOpenedForwardPathHistory(
  WidgetRef ref,
  String fullPath,
  bool clear,
) async {
  StateProvider<StackCollection<String>>? prov;

  switch (ref.read(targetGameProvider)) {
    case TargetGame.Arknights_Endfield:
      prov = explorerViewOpenedForwardPathsEndfield;
      break;
    case TargetGame.Genshin_Impact:
      prov = explorerViewOpenedForwardPathsGenshin;
      break;
    case TargetGame.Honkai_Star_Rail:
      prov = explorerViewOpenedForwardPathsHsr;
      break;
    case TargetGame.Wuthering_Waves:
      prov = explorerViewOpenedForwardPathsWuwa;
      break;
    case TargetGame.Zenless_Zone_Zero:
      prov = explorerViewOpenedForwardPathsZzz;
      break;
    default:
  }

  if (prov != null) {
    if (clear) {
      ref.read(prov.notifier).state = StackCollection();
      return;
    }
    final addedPaths = ref.read(prov);
    final lastAddedPath = addedPaths.peek;
    if (lastAddedPath == null) {
      final newAddedPaths = addedPaths;
      newAddedPaths.push(fullPath);
      ref.read(prov.notifier).state = newAddedPaths;
    } else if (!await FileSystemEntity.identical(lastAddedPath, fullPath)) {
      final newAddedPaths = addedPaths;
      newAddedPaths.push(fullPath);
      ref.read(prov.notifier).state = newAddedPaths;
    }
  }
}

String? getCurrentPath(WidgetRef ref) {
  final result = ref.read(currentFullPathCasualStyle);
  return result ??
      SharedPrefUtils().getCurrentPath(ref.read(targetGameProvider));
}

Future<void> setCurrentPath(
  WidgetRef ref,
  String currentFullPath, {
  bool addToHistory = true,
  bool addToForwardHistory = false,
  bool clearForwardHistory = true,
}) async {
  if (addToHistory) {
    if (ref.read(currentFullPathCasualStyle) != null) {
      await addOpenedPathHistory(ref, ref.read(currentFullPathCasualStyle)!);
      if (clearForwardHistory) {
        await addOpenedForwardPathHistory(
          ref,
          ref.read(currentFullPathCasualStyle)!,
          true,
        );
      }
    }
  } else if (addToForwardHistory) {
    if (ref.read(currentFullPathCasualStyle) != null) {
      await addOpenedForwardPathHistory(
        ref,
        ref.read(currentFullPathCasualStyle)!,
        false,
      );
    }
  }

  await SharedPrefUtils().setCurrentPath(
    currentFullPath,
    ref.read(targetGameProvider),
  );
  ref.read(currentFullPathCasualStyle.notifier).state = currentFullPath;
}

Future<String> getValidCurrentPath(
  String currentFullPath,
  String modsPath,
) async {
  final String basePath = p.dirname(modsPath);

  if (p.isWithin(basePath, currentFullPath) || basePath == currentFullPath) {
    if (await Directory(currentFullPath).exists()) {
      return currentFullPath;
    } else if (await File(currentFullPath).exists()) {
      return p.dirname(currentFullPath);
    } else {
      // Walk up until we find an existing directory within bounds
      String candidate = p.dirname(currentFullPath);
      while (candidate != p.dirname(candidate)) {
        if (await Directory(candidate).exists()) {
          if (p.isWithin(basePath, candidate) || candidate == basePath) {
            return candidate;
          }
          break;
        }
        candidate = p.dirname(candidate);
      }
      return modsPath;
    }
  } else {
    return modsPath;
  }
}

/// -1 invalid outside basePath, 0 invalid, 1 valid, 2 valid but is a file
Future<int> isValidCurrentPath(String currentFullPath, String modsPath) async {
  final String basePath = p.dirname(modsPath);

  if (p.isWithin(basePath, currentFullPath) || basePath == currentFullPath) {
    if (await Directory(currentFullPath).exists()) {
      return 1;
    } else if (await File(currentFullPath).exists()) {
      return 2;
    } else {
      return 0;
    }
  } else {
    return -1;
  }
}

String fastBasename(String path) {
  final idx = path.lastIndexOf(Platform.pathSeparator);
  return idx == -1 ? path : path.substring(idx + 1);
}
