import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart' as bitsdojo;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:window_manager/window_manager.dart';

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
              onPressed: () async {
                await windowManager.hide();
                ref.read(replicatedContextMenuProvider.notifier).state = false;

                if (!ref.read(alertDialogShownProvider)) {
                  ref.read(targetGameProvider.notifier).state =
                      TargetGame.Wuthering_Waves;
                  changeWindowTitleName(
                    TargetGame.Wuthering_Waves.name,
                    ref: ref,
                  );
                }
                ref.read(windowIsPinnedProvider.notifier).state = true;

                await windowManager.show();
              },
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
              onPressed: () async {
                await windowManager.hide();

                ref.read(replicatedContextMenuProvider.notifier).state = false;

                if (!ref.read(alertDialogShownProvider)) {
                  ref.read(targetGameProvider.notifier).state =
                      TargetGame.Genshin_Impact;
                  changeWindowTitleName(
                    TargetGame.Genshin_Impact.name,
                    ref: ref,
                  );
                }
                ref.read(windowIsPinnedProvider.notifier).state = true;

                await windowManager.show();
              },
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
              onPressed: () async {
                await windowManager.hide();

                ref.read(replicatedContextMenuProvider.notifier).state = false;

                if (!ref.read(alertDialogShownProvider)) {
                  ref.read(targetGameProvider.notifier).state =
                      TargetGame.Honkai_Star_Rail;
                  changeWindowTitleName(
                    TargetGame.Honkai_Star_Rail.name,
                    ref: ref,
                  );
                }
                ref.read(windowIsPinnedProvider.notifier).state = true;

                await windowManager.show();
              },
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
              onPressed: () async {
                await windowManager.hide();

                ref.read(replicatedContextMenuProvider.notifier).state = false;

                if (!ref.read(alertDialogShownProvider)) {
                  ref.read(targetGameProvider.notifier).state =
                      TargetGame.Zenless_Zone_Zero;
                  changeWindowTitleName(
                    TargetGame.Zenless_Zone_Zero.name,
                    ref: ref,
                  );
                }
                ref.read(windowIsPinnedProvider.notifier).state = true;

                await windowManager.show();
              },
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
              onPressed: () async {
                await windowManager.hide();

                ref.read(replicatedContextMenuProvider.notifier).state = false;

                if (!ref.read(alertDialogShownProvider)) {
                  ref.read(targetGameProvider.notifier).state =
                      TargetGame.Arknights_Endfield;
                  changeWindowTitleName(
                    TargetGame.Arknights_Endfield.name,
                    ref: ref,
                  );
                }
                ref.read(windowIsPinnedProvider.notifier).state = true;

                await windowManager.show();
              },
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
              onPressed: () async {
                await windowManager.center();
              },
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
              onPressed: () {
                ref.read(replicatedContextMenuProvider.notifier).state = false;

                bitsdojo.appWindow.hide();
                clearImagesCache();
                DynamicDirectoryWatcher.stop();
              },
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
              onPressed: () {
                exit(0);
              },
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
