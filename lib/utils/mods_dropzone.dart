import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:no_reload_mod_manager/utils/ui_dialogues.dart';

class ModsDropZone extends ConsumerStatefulWidget {
  final String? copyDestination;
  final TextSpan? additionalContent;
  final bool? checkForMaxMods;
  final int? currentModsCountInGroup;
  final bool? acceptArchived;
  final String dialogTitleText;
  final void Function(List<Directory> validFolders) onConfirmFunction;
  const ModsDropZone({
    super.key,
    required this.dialogTitleText,
    required this.onConfirmFunction,
    this.acceptArchived = false,
    this.checkForMaxMods = false,
    this.currentModsCountInGroup,
    this.additionalContent,
    this.copyDestination,
  });

  @override
  ConsumerState<ModsDropZone> createState() => _ModsDropZoneState();
}

class _ModsDropZoneState extends ConsumerState<ModsDropZone> {
  bool _dragging = false;

  bool isFolderAndExist(File f) {
    if (Directory(f.path).existsSync()) {
      return true;
    }
    return false;
  }

  void showMaxMessage(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2B2930),
        margin: EdgeInsets.only(left: 20, right: 20, bottom: 20),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        closeIconColor: Colors.blue,
        showCloseIcon: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.yellow,
            fontSize: 13 * ref.read(zoomScaleProvider),
          ),
        ),
        dismissDirection: DismissDirection.down,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) {
        final List<File> droppedFiles =
            details.files.map((f) => File(f.path)).toList();

        final List<Directory> droppedFolders =
            droppedFiles
                .where((f) => isFolderAndExist(f))
                .map((f) => Directory(f.path))
                .toList();

        if (widget.checkForMaxMods != null &&
            widget.currentModsCountInGroup != null) {
          if (widget.checkForMaxMods == true) {
            //Max actually 500, but 501, because index 0 is None mod
            if (widget.currentModsCountInGroup! + droppedFolders.length > 501) {
              showMaxMessage(
                'Max mod info'.tr(
                  args: [
                    (widget.currentModsCountInGroup! - 1).toString(),
                    droppedFolders.length.toString(),
                  ],
                ),
              );
              return;
            }
          }
        }

        if (droppedFolders.isNotEmpty) {
          ref.read(alertDialogShownProvider.notifier).state = true;
          showDialog(
            barrierDismissible: false,
            context: context,
            builder:
                (context) => OnDropModFolderDialog(
                  droppedFolders: droppedFolders,
                  copyDestination: widget.copyDestination,
                  dialogTitleText: widget.dialogTitleText,
                  onConfirmFunction: widget.onConfirmFunction,
                  additionalContent: widget.additionalContent,
                ),
          );
        }
      },
      onDragEntered: (details) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _dragging = false;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              _dragging
                  ? const Color.fromARGB(30, 33, 149, 243)
                  : Colors.transparent,
        ),
      ),
    );
  }
}
