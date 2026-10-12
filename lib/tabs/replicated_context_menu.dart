import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';

class ReplicatedContextMenu extends ConsumerWidget {
  const ReplicatedContextMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sss = ref.watch(zoomScaleProvider);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0 * sss),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.all(10.0 * sss),
                child: Text(
                  'Show (WuWa)'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.all(10.0 * sss),
                child: Text(
                  'Show (Genshin)'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.all(10.0 * sss),
                child: Text(
                  'Show (HSR)'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.all(10.0 * sss),
                child: Text(
                  'Show (ZZZ)'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.all(10.0 * sss),
                child: Text(
                  'Show (Endfield)'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6 * sss),
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0 * sss),
                child: Text(
                  "${'Reset Position'.tr()} (Alt+T)",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0 * sss),
                child: Text(
                  'Hide'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6 * sss),
            TextButton(
              onPressed: () {},
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0 * sss),
                child: Text(
                  'Exit'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11 * sss,
                    fontWeight: FontWeight.w500,
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
