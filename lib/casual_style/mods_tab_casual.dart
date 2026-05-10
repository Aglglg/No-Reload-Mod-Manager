//TODO: SEPARATE CURRENT PATH PER GAME
//TODO: SAVE CURRENT PATH WITH SHARED PREF
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/mods_path_validator.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

class TabModsCasual extends ConsumerStatefulWidget {
  const TabModsCasual({super.key});

  @override
  ConsumerState<TabModsCasual> createState() => _TabModsCasualState();
}

class _TabModsCasualState extends ConsumerState<TabModsCasual> {
  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Padding(
      padding: EdgeInsets.only(
        top: ref.watch(windowIsPinnedProvider) ? 123 * sss : 98 * sss,
        right: 45 * sss,
        left: 45 * sss,
        bottom: 40 * sss,
      ),
      child: Column(
        children: [
          TopBarCasual(),
          Expanded(
            child: Container(
              color: const Color.fromARGB(0, 202, 196, 141),
              child: Text(
                "ITS JUST A FILE EXPLORER",
                style: GoogleFonts.poppins(
                  fontSize: 25 * sss,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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

  Future<String> getTextFieldPath() async {
    final modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      String? currentPath = getCurrentPath(ref);
      if (currentPath != null) {
        currentPath = await getValidCurrentPath(currentPath, modsPath);
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

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
      //example D:\XXMI Launcher, not D:\XXMI Launcher\GIMI
      final basePath = p.dirname(p.dirname(modsPath));
      String? fullPath;

      // Strip surrounding quotes
      path = path.trim();
      if ((path.startsWith('"') && path.endsWith('"')) ||
          (path.startsWith("'") && path.endsWith("'"))) {
        path = path.substring(1, path.length - 1).trim();
      }

      if (p.isRelative(path)) {
        fullPath = p.join(basePath, path);
      } else {
        fullPath = path;
      }

      fullPath = ModsPathValidator.sanitizePath(fullPath);

      if (fullPath == null) {
        showSnackbar(sss, "The specified path doesn't exist");
      } else {
        final valid = await isValidCurrentPath(fullPath, modsPath);
        switch (valid) {
          case -1:
            showSnackbar(
              sss,
              "The specified is outside of the working directory",
            );
            break;
          case 0:
            showSnackbar(sss, "The specified path doesn't exist");
            break;
          case 1:
            setCurrentPath(ref, fullPath);
            break;
          case 2:
            setCurrentPath(ref, p.dirname(fullPath));
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
    constructSplittedPaths();
    listenToChangesInCurrentPath();
    _scrollToEnd();
    windowManager.addListener(this);
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
    if (!widget.isHovered) {
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
        currentPath = await getValidCurrentPath(currentPath, modsPath);
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
              onTap: () {
                setCurrentPath(ref, fullPath);
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

String? getCurrentPath(WidgetRef ref) {
  return ref.read(currentFullPathCasualStyle);
}

void setCurrentPath(WidgetRef ref, String currentFullPath) {
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
