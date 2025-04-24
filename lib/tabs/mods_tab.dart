import 'dart:math';
import 'package:no_reload_mod_manager/utils/mods_dropzone.dart';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class TabMods extends ConsumerStatefulWidget {
  const TabMods({super.key});

  @override
  ConsumerState<TabMods> createState() => _TabModsState();
}

class _TabModsState extends ConsumerState<TabMods> with WindowListener {
  int _currentModIndex = 0;
  double windowWidth = 0;
  final CarouselSliderController _carouselSliderModController =
      CarouselSliderController();
  final CarouselSliderController _carouselSliderGroupController =
      CarouselSliderController();

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
    return ExcludeFocusTraversal(
      child: Stack(
        children: [
          if (ref.watch(fromTrayProvider) &&
              ref.watch(tabIndexProvider) == 1 &&
              !ref.watch(alertDialogShownProvider))
            ModsDropZone(
              dialogTitleText: "Add mods",
              onConfirmFunction: (validFolders) => print("CONFIRM ADD"),
            ),
          Container(
            color: Colors.transparent,
            child: MoveWindow(onDoubleTap: () {}),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 67, right: 49, left: 49),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (ref.watch(fromTrayProvider)) Container(height: 9),
                if (ref.watch(fromTrayProvider))
                  Text(
                    'Drag & Drop mod folders here to add to this group (1 folder = 1 mod)',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.poppins(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Container(height: 10),
                Center(
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 93.6,
                            height: 130,
                            color: Colors.transparent,
                            child: CarouselSlider(
                              carouselController:
                                  _carouselSliderGroupController,
                              options: CarouselOptions(
                                enableInfiniteScroll: true,
                                scrollDirection: Axis.vertical,
                                enlargeCenterPage: true,
                                enlargeFactor: .05,
                              ),
                              items:
                                  [1, 2, 3, 4, 5].map((i) {
                                    return Builder(
                                      builder: (BuildContext context) {
                                        return Container(
                                          height: 93.6,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              width: 3,
                                              color: const Color.fromARGB(
                                                127,
                                                255,
                                                255,
                                                255,
                                              ),
                                              strokeAlign:
                                                  BorderSide.strokeAlignInside,
                                            ),
                                            color: Colors.transparent,
                                          ),
                                          child: Center(
                                            // child: Text(
                                            //   'Group $i',
                                            //   style: TextStyle(
                                            //     fontSize: 16.0,
                                            //     color: Colors.white,
                                            //   ),
                                            // ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                            ),
                          ),
                          Container(height: 2),

                          SizedBox(
                            width: 93.6,
                            child: Text(
                              'Rover Female',
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),

                      Container(
                        width: 49,
                        height: 200,
                        color: Colors.transparent,
                      ),

                      Expanded(
                        child: Container(
                          height: 200,
                          color: Colors.transparent,
                          child: CarouselSlider.builder(
                            itemCount: 41,
                            carouselController: _carouselSliderModController,
                            options: CarouselOptions(
                              enableInfiniteScroll: true,
                              scrollDirection: Axis.horizontal,
                              viewportFraction: getViewportFraction(),
                              onPageChanged: (index, reason) {
                                setState(() {
                                  _currentModIndex = index;
                                });
                              },
                            ),
                            itemBuilder: (context, index, realIndex) {
                              bool isSelected = _currentModIndex == index;
                              double itemHeight =
                                  isSelected ? 150 * 1.1 : 108 * 1.1;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                    height: itemHeight,
                                    width: 108 * 1.1,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: Border.all(
                                        strokeAlign:
                                            BorderSide.strokeAlignInside,
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
                                      child: GestureDetector(
                                        onDoubleTap:
                                            _currentModIndex == index
                                                ? () {
                                                  print("A");
                                                }
                                                : null,
                                        onTap:
                                            () => _carouselSliderModController
                                                .animateToPage(
                                                  index,
                                                  duration: Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  curve: Curves.easeOut,
                                                ),
                                        child: Image.asset(
                                          'assets/images/AAA.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(height: 3),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Mod $index',
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TabModsNotReady extends StatelessWidget {
  final String notReadyReason;

  const TabModsNotReady({super.key, required this.notReadyReason});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.transparent,
          child: MoveWindow(onDoubleTap: () {}),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 85),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                notReadyReason,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
        ),
      ],
    );
  }
}

class TabModsLoading extends StatelessWidget {
  const TabModsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.transparent,
          child: MoveWindow(onDoubleTap: () {}),
        ),
        Padding(
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
        ),
      ],
    );
  }
}
