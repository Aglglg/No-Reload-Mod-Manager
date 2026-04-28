import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
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
    pathTextfieldFocusNode.addListener(() {
      setState(() {
        pathTextfieldFocused = pathTextfieldFocusNode.hasFocus;
      });
      pathTextfieldController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: pathTextfieldController.text.length,
      );
    });
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
  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return TextField(
      controller: widget.pathTextfieldController,
      focusNode: widget.pathTextfieldFocusNode,
      onTap: () {
        widget.pathTextfieldFocusNode.requestFocus();
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
  List<String> splittedPaths = [];
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    constructSplittedPaths();
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

  Future<void> constructSplittedPaths() async {
    final modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      String? currentPath = getCurrentPath();
      if (currentPath != null) {
        currentPath = await getValidCurrentPath(currentPath, modsPath);
      } else {
        currentPath = modsPath;
      }
      final relPath = p.relative(
        currentPath,
        from: p.dirname(p.dirname(modsPath)),
      );
      final splitPaths =
          relPath
              .split(p.separator)
              .where((element) => element.trim().isNotEmpty)
              .toList();
      splittedPaths = splitPaths;
    }
  }

  String? getCurrentPath() {
    switch (ref.read(targetGameProvider)) {
      case TargetGame.Arknights_Endfield:
        return ref.read(currentPathGenshinCasualStyle);
      case TargetGame.Genshin_Impact:
        return ref.read(currentPathGenshinCasualStyle);
      case TargetGame.Honkai_Star_Rail:
        return ref.read(currentPathHsrCasualStyle);
      case TargetGame.Wuthering_Waves:
        return ref.read(currentPathWuwaCasualStyle);
      case TargetGame.Zenless_Zone_Zero:
        return ref.read(currentPathZzzCasualStyle);
      default:
        return null;
    }
  }

  List<Widget> getClickablePaths(double sss) {
    final widgets =
        splittedPaths.asMap().entries.expand((entry) {
          final index = entry.key;
          final value = entry.value;

          return [
            ClickableText(
              text: value,
              fontSize: 14 * sss,
              color:
                  index == splittedPaths.length - 1
                      ? getAccentColor(ref)
                      : const Color.fromARGB(169, 255, 255, 255),
              hoverColor: Colors.white,
              onTap: () {
                print("TAP");
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

Future<String> getValidCurrentPath(String currentPath, String modsPath) async {
  final String basePath = p.dirname(modsPath);

  if (p.isWithin(basePath, currentPath) || basePath == currentPath) {
    if (await Directory(currentPath).exists()) {
      return currentPath;
    } else if (await File(currentPath).exists()) {
      return p.dirname(currentPath);
    } else {
      return modsPath;
    }
  } else {
    return modsPath;
  }
}
