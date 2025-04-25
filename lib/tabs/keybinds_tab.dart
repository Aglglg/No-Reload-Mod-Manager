import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final List<Map<String, String>> keys = const [
  {'title': 'Key Weapon', 'subtitle': 'no_shift no_return A'},
  {'title': 'Key Something', 'subtitle': 'no_shift no_alt no_control A'},
  {'title': 'Key Something Long Very Text', 'subtitle': 'no_control A'},
  {'title': 'Key Weapon', 'subtitle': 'no_shift A'},
  {'title': 'Key Weapon', 'subtitle': 'no_shift A'},
  {'title': 'Key Weapon', 'subtitle': 'no_shift A'},
  {
    'title': 'Key Weapon',
    'subtitle': 'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  {
    'title': 'Key Weapon',
    'subtitle': 'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  {
    'title': 'Key Weapon',
    'subtitle': 'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  {
    'title': 'Key Weapon',
    'subtitle':
        'no_shift Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
];

class TabKeybinds extends StatefulWidget {
  const TabKeybinds({super.key});

  @override
  State<TabKeybinds> createState() => _TabKeybindsState();
}

class _TabKeybindsState extends State<TabKeybinds> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 85, right: 49, left: 49, bottom: 30),
      child: Align(
        alignment: Alignment.topCenter,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Text(
                "Rover - Rover Evelyn",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: ScrollConfiguration(
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
                    spacing: 9,
                    runSpacing: 9,
                    children:
                        keys.map((keyData) {
                          return _KeyCard(
                            title: keyData['title']!,
                            subtitle: keyData['subtitle']!,
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _KeyCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: const Color.fromARGB(100, 0, 0, 0),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color.fromARGB(127, 255, 255, 255),
          width: 3,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '[$title]',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),

          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w400,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
