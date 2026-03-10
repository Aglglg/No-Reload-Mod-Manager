import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';

class ModsPresetsTab extends ConsumerStatefulWidget {
  const ModsPresetsTab({super.key});

  @override
  ConsumerState<ModsPresetsTab> createState() => _ModsPresetsTabState();
}

class _ModsPresetsTabState extends ConsumerState<ModsPresetsTab> {
  int? expandedIndex;

  @override
  Widget build(BuildContext context) {
    final sss = ref.watch(zoomScaleProvider);
    return Stack(
      children: [
        Padding(
          padding: EdgeInsetsGeometry.only(
            top: 70 * sss,
            right: 45 * sss,
            left: 30 * sss,
            bottom: 0 * sss,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  ref.read(modsSubTabIndexProvider.notifier).state = 1;
                },
                icon: Icon(Icons.chevron_left_rounded),
                iconSize: 24 * sss,
                style: IconButton.styleFrom(overlayColor: Colors.white),
              ),
              IgnorePointer(
                child: Text(
                  "Presets",
                  textAlign: TextAlign.start,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14 * sss,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsGeometry.only(
            top: 110 * sss,
            right: 45 * sss,
            left: 45 * sss,
            bottom: 40 * sss,
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
              scrollbars: false,
            ),
            child: ListView(
              scrollDirection: Axis.vertical,

              children: List.generate(3, (index) {
                return PresetTile(
                  sss: sss,
                  title:
                      index == 0
                          ? "Best Preset"
                          : index == 1
                          ? "Good Preset"
                          : "Okay Preset",
                  expanded: expandedIndex == index,
                  onToggle: () {
                    setState(() {
                      expandedIndex = expandedIndex == index ? null : index;
                    });
                  },
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class PresetTile extends StatefulWidget {
  final double sss;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  const PresetTile({
    super.key,
    required this.sss,
    required this.title,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<PresetTile> createState() => _PresetTileState();
}

class _PresetTileState extends State<PresetTile> {
  bool isHovering = false;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onDoubleTap: () {
            print("DOUBLE TAP");
          },
          child: MouseRegion(
            onEnter: (event) {
              setState(() {
                isHovering = true;
              });
            },
            onExit: (event) {
              setState(() {
                isHovering = false;
              });
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8 * widget.sss),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18 * widget.sss),
                border: Border.all(
                  color:
                      isHovering
                          ? Colors.white
                          : const Color.fromARGB(128, 255, 255, 255),
                  width: 3 * widget.sss,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18 * widget.sss),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20 * widget.sss,
                        vertical: 12 * widget.sss,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14 * widget.sss,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'A preset of nice mods',
                            style: GoogleFonts.poppins(
                              color: const Color.fromARGB(200, 255, 255, 255),
                              fontSize: 12 * widget.sss,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: widget.expanded ? 1 : 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: widget.expanded ? 1 : 0,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                14 * widget.sss,
                                6 * widget.sss,
                                14 * widget.sss,
                                14 * widget.sss,
                              ),
                              child: Wrap(
                                spacing: 8 * widget.sss,
                                runSpacing: 15 * widget.sss,
                                children: List.generate(
                                  4,
                                  (_) => Container(
                                    color: Colors.white,
                                    width: 200 * widget.sss,
                                    height: 100 * widget.sss,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: Container(
            color: Colors.transparent,
            height: 67 * widget.sss,
            width: 60,
            child: InkResponse(
              radius: 22 * widget.sss,
              onTap: widget.onToggle,
              child: AnimatedRotation(
                turns: widget.expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 25 * widget.sss,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
