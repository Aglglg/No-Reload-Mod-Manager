import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;

class ModsDropZone extends ConsumerStatefulWidget {
  final TextSpan? additionalContent;
  final String dialogTitleText;
  final void Function(List<Directory> validFolders) onConfirmFunction;
  final bool acceptArchived;
  const ModsDropZone({
    super.key,
    required this.dialogTitleText,
    required this.onConfirmFunction,
    this.acceptArchived = false,
    this.additionalContent,
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

  bool isValidFolder(Directory f) {
    if (!isFolderOnManagedPath(f) && !isFolderOnThisToolPath(f)) {
      return true;
    }
    return false;
  }

  bool isFolderOnManagedPath(Directory f) {
    if (f.path.contains(ConstantVar.managedFolderName)) {
      return true;
    }
    return false;
  }

  bool isFolderOnThisToolPath(Directory f) {
    String thisToolExePath = Platform.resolvedExecutable;
    String thisToolPath = p.dirname(thisToolExePath);
    if (p.isWithin(thisToolPath, p.normalize(f.path)) ||
        f.path == thisToolPath) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) {
        List<File> droppedFiles =
            details.files.map((f) => File(f.path)).toList();

        List<Directory> droppedFolders =
            droppedFiles
                .where((f) => isFolderAndExist(f))
                .map((f) => Directory(f.path))
                .toList();

        List<Directory> validFolders =
            droppedFolders.where((f) => isValidFolder(f)).toList();
        List<Directory> foldersOnManagedPath =
            droppedFolders.where((f) => isFolderOnManagedPath(f)).toList();
        List<Directory> foldersOnThisToolPath =
            droppedFolders.where((f) => isFolderOnThisToolPath(f)).toList();

        if (droppedFolders.isNotEmpty) {
          ref.read(alertDialogShownProvider.notifier).state = true;
          showDialog(
            barrierDismissible: false,
            context: context,
            builder:
                (context) => OnDropModFolderDialog(
                  validFolders: validFolders,
                  foldersOnManagedPath: foldersOnManagedPath,
                  foldersOnThisToolPath: foldersOnThisToolPath,
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
  final List<Directory> validFolders;
  final List<Directory> foldersOnThisToolPath;
  final List<Directory> foldersOnManagedPath;
  final Function onConfirmFunction;
  final TextSpan? additionalContent;

  const OnDropModFolderDialog({
    super.key,
    required this.dialogTitleText,
    required this.validFolders,
    required this.foldersOnThisToolPath,
    required this.foldersOnManagedPath,
    required this.onConfirmFunction,
    required this.additionalContent,
  });

  @override
  ConsumerState<OnDropModFolderDialog> createState() =>
      _OnDropFolderDialogState();
}

class _OnDropFolderDialogState extends ConsumerState<OnDropModFolderDialog> {
  final ScrollController _scrollController = ScrollController();
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    addContent();
    _scrollToBottom();
  }

  void addContent() {
    contents.add(
      TextSpan(
        text: "Valid folders detected:\n",
        style: GoogleFonts.poppins(
          color: Colors.green,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
    for (Directory folder in widget.validFolders) {
      contents.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
        ),
      );
    }
    if (widget.validFolders.isEmpty) {
      contents.add(
        TextSpan(
          text: "None\n",
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
        ),
      );
    }

    //ON _MANAGED_ PATH
    if (widget.foldersOnManagedPath.isNotEmpty) {
      contents.add(
        TextSpan(
          text: "\nFolders excluded (on _MANAGED_ path):\n",
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    for (Directory folder in widget.foldersOnManagedPath) {
      contents.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
        ),
      );
    }
    if (widget.foldersOnManagedPath.isNotEmpty) {
      contents.add(
        TextSpan(
          text: "Please move these folders outside first\n",
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    //ON TOOL PATH
    if (widget.foldersOnThisToolPath.isNotEmpty) {
      contents.add(
        TextSpan(
          text: "\nFolders excluded for safety (on this tool exe path):\n",
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
    for (Directory folder in widget.foldersOnThisToolPath) {
      contents.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
        ),
      );
    }
    if (widget.foldersOnThisToolPath.isNotEmpty) {
      contents.add(
        TextSpan(
          text:
              "Adding folders from this tool path might break this tool functionality\n",
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    if (widget.additionalContent != null) {
      contents.add(widget.additionalContent!);
    }
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
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(alertDialogShownProvider.notifier).state = false;
          },
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.blue)),
        ),
        if (widget.validFolders.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(alertDialogShownProvider.notifier).state = false;
              widget.onConfirmFunction(widget.validFolders);
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(color: Colors.green),
            ),
          ),
      ],
    );
  }
}
