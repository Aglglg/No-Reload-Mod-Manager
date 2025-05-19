import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;

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
            //Max actually 40, but 41, because index 0 is None mod
            if (widget.currentModsCountInGroup! + droppedFolders.length > 41) {
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

class OnDropModFolderDialog extends ConsumerStatefulWidget {
  final String dialogTitleText;
  final List<Directory> droppedFolders;
  final String? copyDestination;
  final Function onConfirmFunction;
  final TextSpan? additionalContent;

  const OnDropModFolderDialog({
    super.key,
    required this.dialogTitleText,
    required this.droppedFolders,
    required this.copyDestination,
    required this.onConfirmFunction,
    required this.additionalContent,
  });

  @override
  ConsumerState<OnDropModFolderDialog> createState() =>
      _OnDropFolderDialogState();
}

class _OnDropFolderDialogState extends ConsumerState<OnDropModFolderDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showClose = false;
  List<Directory> validFolders = [];
  List<Directory> foldersOnManagedPath = [];
  List<Directory> foldersOnThisToolPath = [];
  List<Directory> parentFolderOfManagedPath = [];
  List<Directory> parentFolderOfThisToolPath = [];
  List<Directory> parentFolderOfDestPath = [];
  List<TextSpan> contents = [
    TextSpan(
      text: "Checking folders...".tr(),
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
    ),
  ];

  Future<bool> isValidFolder(Directory f) async {
    if (!isUnderManagedFolder(f.path) &&
        !isFolderOnThisToolPath(f) &&
        !await isParentOfManagedFolder(f.path) &&
        !isParentOfThisToolPath(f) &&
        !isParentOfDestFolder(f)) {
      return true;
    }
    return false;
  }

  bool isUnderManagedFolder(String inputPath) {
    var dir = Directory(p.normalize(inputPath));

    // Walk up to root
    while (true) {
      final folderName = p.basename(dir.path);
      if (folderName.toLowerCase() == '_managed_') {
        return true;
      }

      final parent = dir.parent;
      if (parent.path == dir.path) break; // Reached root
      dir = parent;
    }

    return false;
  }

  bool isFolderOnThisToolPath(Directory f) {
    String thisToolExePath = Platform.resolvedExecutable;
    String thisToolPath = p.dirname(thisToolExePath);
    if (p.isWithin(thisToolPath, p.normalize(f.path))) {
      return true;
    }
    return false;
  }

  ///////////////
  /// Recursively checks if the given [dirPath] or any of its subdirectories
  /// contains a folder named '_MANAGED_' (case-insensitive).
  Future<bool> isParentOfManagedFolder(String dirPath) async {
    final dir = Directory(dirPath);

    if (!await dir.exists()) return false;

    // Check if the base name of the given path is '_MANAGED_'
    final currentName = p.basename(dirPath);
    if (currentName.toLowerCase() == '_managed_') return true;

    // Recursively list all subdirectories
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);
        if (folderName.toLowerCase() == '_managed_') {
          return true;
        }
      }
    }

    return false;
  }

  bool isParentOfThisToolPath(Directory f) {
    String thisToolExePath = Platform.resolvedExecutable;
    String thisToolPath = p.dirname(thisToolExePath);
    if (p.isWithin(f.path, p.normalize(thisToolPath)) ||
        f.path == thisToolPath) {
      return true;
    }
    return false;
  }

  bool isParentOfDestFolder(Directory f) {
    if (widget.copyDestination != null) {
      if (p.isWithin(f.path, p.normalize(widget.copyDestination!))) {
        return true;
      }
    }
    return false;
  }

  Future<List<Directory>> getParentFoldersWithManaged(
    List<Directory> droppedFolders,
  ) async {
    final results = await Future.wait(
      droppedFolders.map((f) async => await isParentOfManagedFolder(f.path)),
    );

    // Now filter using the results
    final filteredFolders = <Directory>[];
    for (int i = 0; i < results.length; i++) {
      if (results[i]) {
        filteredFolders.add(droppedFolders[i]);
      }
    }

    return filteredFolders;
  }

  Future<List<Directory>> getValidFolders(
    List<Directory> droppedFolders,
  ) async {
    final results = await Future.wait(
      droppedFolders.map((f) async => await isValidFolder(f)),
    );

    // Now filter using the results
    final filteredFolders = <Directory>[];
    for (int i = 0; i < results.length; i++) {
      if (results[i]) {
        filteredFolders.add(droppedFolders[i]);
      }
    }

    return filteredFolders;
  }

  @override
  void initState() {
    super.initState();
    checkFolders();
  }

  Future<void> checkFolders() async {
    final mValidFolders = await getValidFolders(widget.droppedFolders);
    ////////////////////
    final mFoldersOnManagedPath =
        widget.droppedFolders
            .where((f) => isUnderManagedFolder(f.path))
            .toList();
    final mFoldersOnThisToolPath =
        widget.droppedFolders.where((f) => isFolderOnThisToolPath(f)).toList();
    //////////////////////
    final mParentFolderOfManagedPath = await getParentFoldersWithManaged(
      widget.droppedFolders,
    );
    final mParentFolderOfThisToolPath =
        widget.droppedFolders.where((f) => isParentOfThisToolPath(f)).toList();
    final mParentFolderOfDestPath =
        widget.droppedFolders.where((f) => isParentOfDestFolder(f)).toList();

    setState(() {
      validFolders = mValidFolders;
      foldersOnManagedPath = mFoldersOnManagedPath;
      foldersOnThisToolPath = mFoldersOnThisToolPath;
      parentFolderOfManagedPath = mParentFolderOfManagedPath;
      parentFolderOfThisToolPath = mParentFolderOfThisToolPath;
      parentFolderOfDestPath = mParentFolderOfDestPath;
    });

    addContent();
  }

  Future<void> addContent() async {
    List<TextSpan> resultLogs = [];
    resultLogs.add(
      TextSpan(
        text: "Valid folders detected:".tr(),
        style: GoogleFonts.poppins(
          color: Colors.green,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
    for (Directory folder in validFolders) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }
    if (validFolders.isEmpty) {
      resultLogs.add(
        TextSpan(
          text: "${'None'.tr()}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }

    //ON _MANAGED_ PATH
    if (foldersOnManagedPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text: "Folders excluded (on _MANAGED_ path):".tr(),
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    for (Directory folder in foldersOnManagedPath) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }
    if (foldersOnManagedPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text: "Please move these folders outside first".tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    //ON TOOL PATH
    if (foldersOnThisToolPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text: "Folders excluded for safety (on this tool exe path):".tr(),
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    for (Directory folder in foldersOnThisToolPath) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }
    if (foldersOnThisToolPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text:
              "Adding folders from this tool path might break this tool functionality"
                  .tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    //IS PARENT OF TOOL PATH
    if (parentFolderOfThisToolPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text:
              "Folders excluded for safety (parent folder of this tool exe path):"
                  .tr(),
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    for (Directory folder in parentFolderOfThisToolPath) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }
    if (parentFolderOfThisToolPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text: "This folder contains this tool exe file".tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    //IS PARENT OF DEST FOLDER
    if (parentFolderOfDestPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text:
              "Folders excluded because folder is parent folder of target group folder:"
                  .tr(),
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    for (Directory folder in parentFolderOfDestPath) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }
    if (parentFolderOfDestPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text:
              "This folder contains the target group folder/parent folder of target group"
                  .tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    //IS PARENT OF MANAGED FOLDER
    if (parentFolderOfManagedPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text: "Folders excluded to prevent unexpected error:".tr(),
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    for (Directory folder in parentFolderOfManagedPath) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }
    if (parentFolderOfManagedPath.isNotEmpty) {
      resultLogs.add(
        TextSpan(
          text:
              "This folder contains subfolders with name _MANAGED_ or is parent folder of _MANAGED_ folder"
                  .tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    if (widget.additionalContent != null) {
      resultLogs.add(widget.additionalContent!);
    }

    setState(() {
      _showClose = true;
      contents = resultLogs;
    });

    await _scrollToBottom();
  }

  Future<void> _scrollToBottom() async {
    // Wait until scrollController has a valid position
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_scrollController.hasClients) return;

    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.dialogTitleText,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: RichText(text: TextSpan(children: contents)),
          ),
        ),
      ),
      actions:
          _showClose
              ? [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = false;
                  },
                  child: Text(
                    'Cancel'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
                if (validFolders.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(alertDialogShownProvider.notifier).state = false;
                      widget.onConfirmFunction(validFolders);
                    },
                    child: Text(
                      'Confirm'.tr(),
                      style: GoogleFonts.poppins(color: Colors.green),
                    ),
                  ),
              ]
              : [],
    );
  }
}
