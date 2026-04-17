import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;

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
            child: Container(color: const Color.fromARGB(0, 255, 235, 59)),
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
  List<String> splittedPaths = [];

  @override
  void initState() {
    super.initState();
    final modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      final relPath = p.relative(
        modsPath,
        from: p.dirname(p.dirname(modsPath)),
      );
      final splitPaths =
          relPath
              .split(p.separator)
              .where((element) => element.trim().isNotEmpty)
              .toList();
      splittedPaths = splitPaths;
      for (var a in splittedPaths) {
        print(a);
      }
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
              fontSize: 13 * sss,
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
                  fontSize: 13 * sss,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(169, 255, 255, 255),
                ),
              ),
          ];
        }).toList();

    // Add your yellow widget at the end
    widgets.add(
      MouseRegion(
        cursor: SystemMouseCursors.text,
        child: Container(
          width: 40 * sss,
          height: 15 * sss,
          color: Colors.transparent,
        ),
      ),
    );

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.folder_rounded,
          size: 24 * sss,
          color: const Color.fromARGB(169, 255, 255, 255),
        ),
        SizedBox(width: 10 * sss),
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              TextField(
                decoration: InputDecoration(
                  isDense: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: const Color.fromARGB(169, 255, 255, 255),
                      style: true ? BorderStyle.solid : BorderStyle.none,
                      width: 1 * sss,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: getAccentColor(ref),
                      width: 1 * sss,
                    ),
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 13 * sss,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: getClickablePaths(sss),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 10 * sss),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            child: Icon(
              Icons.format_list_bulleted_rounded,
              size: 22 * sss,
              color: const Color.fromARGB(169, 255, 255, 255),
            ),
          ),
        ),
        SizedBox(width: 7 * sss),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            child: Icon(
              Icons.grid_view_rounded,
              size: 20 * sss,
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
        SizedBox(width: 7 * sss),
        Expanded(
          flex: 1,
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: getAccentColor(ref),
                  width: 1 * sss,
                ),
              ),
            ),
            style: GoogleFonts.poppins(
              fontSize: 13 * sss,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class PathBreadcrumbs extends StatefulWidget {
  const PathBreadcrumbs({super.key});

  @override
  State<PathBreadcrumbs> createState() => _PathBreadcrumbsState();
}

class _PathBreadcrumbsState extends State<PathBreadcrumbs> {
  @override
  Widget build(BuildContext context) {
    return Container();
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
