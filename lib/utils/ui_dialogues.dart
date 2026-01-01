import 'dart:io';
import 'dart:ui';

import 'package:archive/archive_io.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/main.dart';
import 'package:no_reload_mod_manager/utils/auto_group_icon.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_group_folder_icon.dart';
import 'package:no_reload_mod_manager/utils/force_read_as_utf8.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;

class GenerateGroupIcoFileDialog extends ConsumerStatefulWidget {
  final String validModsPath;
  const GenerateGroupIcoFileDialog({super.key, required this.validModsPath});

  @override
  ConsumerState<GenerateGroupIcoFileDialog> createState() =>
      _GenerateGroupIcoFileDialogState();
}

class _GenerateGroupIcoFileDialogState
    extends ConsumerState<GenerateGroupIcoFileDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showConfirm = true;
  bool _isLoading = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    showWarning();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void showWarning() {
    setState(() {
      contents = [
        TextSpan(
          text: "Generate ico files for all group folders?".tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),

        TextSpan(
          text:
              "It may takes some times depending on how many groups you have."
                  .tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ];
    });
  }

  Future<void> generateIcons() async {
    setState(() {
      _showConfirm = false;
      _isLoading = true;
    });

    final String managedPath = p.join(
      widget.validModsPath,
      ConstantVar.managedFolderName,
    );

    setState(() {
      contents = [];
    });

    final modGroups = await getGroupFolders(managedPath);

    for (var group in modGroups) {
      setState(() {
        contents = [
          ...contents,
          TextSpan(
            text: "Generating folder icon".tr(
              args: [p.basename(group.$1.path)],
            ),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ];
      });

      await setFolderIcon(group.$1.path, p.join(group.$1.path, 'icon.png'));

      setState(() {
        final newContents = List<TextSpan>.from(contents);
        newContents.removeLast();
        newContents.add(
          TextSpan(
            text: "Generated folder icon".tr(args: [p.basename(group.$1.path)]),
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          ),
        );
        contents = newContents;
      });
      _scrollToBottom();
    }

    setState(() {
      _isLoading = false;
      contents = [
        ...contents,
        TextSpan(
          text: "Task completed!".tr(),
          style: GoogleFonts.poppins(
            color: Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    });
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
        "Generate group folder icon".tr(),
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
          _showConfirm
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
                TextButton(
                  onPressed: () async {
                    await generateIcons();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ]
              : _isLoading
              ? []
              : [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = false;
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
    );
  }
}

class ChangeLanguageDialog extends ConsumerWidget {
  final Locale locale;
  const ChangeLanguageDialog({super.key, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text(
        'Change language'.tr(),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Language changed, please Restart.'.tr(),
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(alertDialogShownProvider.notifier).state = false;
            checkToRelaunch(forcedRelaunch: true);
          },
          child: Text(
            'Restart'.tr(),
            style: GoogleFonts.poppins(color: Colors.blue),
          ),
        ),
      ],
    );
  }
}

class PrefCorruptedDialog extends ConsumerStatefulWidget {
  const PrefCorruptedDialog({super.key});

  @override
  ConsumerState<PrefCorruptedDialog> createState() =>
      _PrefCorruptedDialogState();
}

class _PrefCorruptedDialogState extends ConsumerState<PrefCorruptedDialog> {
  final ScrollController _scrollController = ScrollController();
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    showCorruptedPrefInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> showCorruptedPrefInfo() async {
    setState(() {
      contents = [];
      contents.add(
        TextSpan(
          text:
              "Settings data corrupted. Data automatically deleted to prevent error."
                  .tr(),
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
      contents.add(
        TextSpan(
          text:
              "Make sure to re-check 'Mods Path' and anything else, on Settings tab."
                  .tr(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      contents.add(
        TextSpan(
          text: "Don't worry, mod datas are still fine!".tr(),
          style: GoogleFonts.poppins(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    });

    _scrollToBottom();
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
        'Warning'.tr(),
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
          child: Text(
            'Close'.tr(),
            style: GoogleFonts.poppins(color: Colors.blue),
          ),
        ),
      ],
    );
  }
}

//-------------------------------------MOD MANAGER--------------------------------------
//-------------------------------------MOD MANAGER--------------------------------------
//-------------------------------------MOD MANAGER--------------------------------------
class OnDropModFolderDialog extends ConsumerStatefulWidget {
  final String dialogTitleText;
  final List<Directory> droppedFolders;
  final List<File> droppedArchives;
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
    required this.droppedArchives,
  });

  @override
  ConsumerState<OnDropModFolderDialog> createState() =>
      _OnDropFolderDialogState();
}

class _OnDropFolderDialogState extends ConsumerState<OnDropModFolderDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showClose = false;
  List<Directory> validFolders = [];
  List<File> validArchives = [];
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
    checkFoldersAndArchives();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> checkFoldersAndArchives() async {
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
    /////////////////////
    setState(() {
      validFolders = mValidFolders;
      validArchives = widget.droppedArchives;
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
    for (File archive in validArchives) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(archive.path)}\n",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    for (Directory folder in validFolders) {
      resultLogs.add(
        TextSpan(
          text: "${p.basename(folder.path)}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }
    if (validFolders.isEmpty && validArchives.isEmpty) {
      resultLogs.add(
        TextSpan(
          text: "${'None'.tr()}\n",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      );
    }

    //IN _MANAGED_ PATH
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

    //IN TOOL PATH
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
                if (validFolders.isNotEmpty || validArchives.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(alertDialogShownProvider.notifier).state = false;
                      widget.onConfirmFunction(validFolders, validArchives);
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

class CopyModDialog extends ConsumerStatefulWidget {
  final List<Directory> modDirs;
  final List<File> modArchives;
  final String modsPath;
  final String targetGroupPath;
  const CopyModDialog({
    super.key,
    required this.modDirs,
    required this.modArchives,
    required this.modsPath,
    required this.targetGroupPath,
  });

  @override
  ConsumerState<CopyModDialog> createState() => _CopyModDialogState();
}

class _CopyModDialogState extends ConsumerState<CopyModDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showClose = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    copyMods();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> directoryHasZeroSize(Directory dir) async {
    if (!await dir.exists()) return false;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          final length = await entity.length();
          if (length > 0) {
            return false; // stop immediately if bytes already not 0
          }
        } catch (_) {
          // ignore inaccessible files
        }
      }
    }

    return true; // no files or all empty
  }

  Future<void> copyMods() async {
    setState(() {
      contents = [];
      contents.add(
        TextSpan(
          text: 'Copying mods...'.tr(),
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    });

    List<TextSpan> operationLogs = [];

    //MOD FOLDERs
    for (var folder in widget.modDirs) {
      Directory? disabledFolder = await renameSourceFolderToBeDisabledPrefix(
        folder,
      );
      if (disabledFolder != null) {
        String destFolderName = removeAllDisabledPrefixes(
          p.basename(disabledFolder.path),
        );

        try {
          String destDirPath = p.join(widget.targetGroupPath, destFolderName);
          destDirPath = await checkForDuplicateFolderName(destDirPath);

          await copyDirectory(disabledFolder, Directory(destDirPath));
          //Even though source folder already disabled, after successfully copied, just delete it. Actually just simulating cut/move.
          //Rename source folder is also the same as testing whether that folder is used by other programs or not.
          await deleteUnusedFolder(disabledFolder);
          operationLogs.add(
            TextSpan(
              text: 'Folder copied'.tr(args: [p.basename(folder.path)]),
              style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
            ),
          );
        } catch (_) {
          operationLogs.add(
            TextSpan(
              text:
                  '${'Error! Cannot copy folder'.tr(args: [p.basename(folder.path)])}.\n${ConstantVar.defaultErrorInfo}\n\n',
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
            ),
          );
        }
      } else {
        operationLogs.add(
          TextSpan(
            text:
                '${'Error! Cannot copy folder'.tr(args: [p.basename(folder.path)])}.\n${ConstantVar.defaultErrorInfo}\n\n',
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
          ),
        );
      }
    }

    //MOD ARCHIVEs
    for (var archive in widget.modArchives) {
      String destFolderName = removeAllDisabledPrefixes(
        p.basenameWithoutExtension(archive.path),
      );
      try {
        String destDirPath = p.join(widget.targetGroupPath, destFolderName);
        destDirPath = await checkForDuplicateFolderName(destDirPath);

        //extract
        await extractFileToDisk(archive.path, destDirPath);

        //check extract result, if folder not there after extraction, throw error, invalid archive
        try {
          if (!await Directory(destDirPath).exists()) {
            throw Exception("Failed to extract");
          }
        } catch (e) {
          if (e.toString().contains("Failed to extract")) {
            rethrow;
          }
          //if not that error that means error when doing Directory().exists(), skip
        }

        //check bytes size, if all 0, that means archive may be having password, failed
        if (await directoryHasZeroSize(Directory(destDirPath))) {
          await deleteUnusedFolder(Directory(destDirPath));
          throw Exception("Passworded archive");
        }

        operationLogs.add(
          TextSpan(
            text: 'Archive extracted'.tr(args: [p.basename(archive.path)]),
            style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
          ),
        );
      } catch (e) {
        if (e.toString().contains("Passworded archive")) {
          operationLogs.add(
            TextSpan(
              text: 'Error! Archive may have password, not supported'.tr(
                args: [p.basename(archive.path)],
              ),
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
            ),
          );
        } else if (e.toString().contains("Failed to extract")) {
          operationLogs.add(
            TextSpan(
              text: 'Error! Archive not supported'.tr(
                args: [p.basename(archive.path)],
              ),
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
            ),
          );
        } else {
          operationLogs.add(
            TextSpan(
              text:
                  '${'Error! Cannot extract mod archive'.tr(args: [p.basename(archive.path)])}.\n${ConstantVar.defaultErrorInfo}\n\n',
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
            ),
          );
        }
      }
    }

    setState(() {
      _showClose = true;
      contents = operationLogs;
    });

    _scrollToBottom();
  }

  Future<Directory?> renameSourceFolderToBeDisabledPrefix(
    Directory folder,
  ) async {
    final parent = folder.parent.path;
    final originalName = p.basename(folder.path);
    final newName = 'DISABLED$originalName';
    final newPath = p.join(parent, newName);

    if (originalName.toLowerCase().startsWith('disabled')) {
      return folder;
    } else {
      try {
        return await folder.rename(newPath);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> deleteUnusedFolder(Directory folder) async {
    try {
      await folder.delete(recursive: true);
    } catch (_) {}
  }

  String removeAllDisabledPrefixes(String input) {
    return input.replaceFirst(
      RegExp(r'^(disabled\s*)+', caseSensitive: false),
      '',
    );
  }

  Future<String> checkForDuplicateFolderName(String destPath) async {
    String fixedDestPath = destPath;
    while (await Directory(fixedDestPath).exists()) {
      fixedDestPath = '${fixedDestPath}_';
    }
    return fixedDestPath;
  }

  Future<void> copyDirectory(Directory source, Directory destination) async {
    try {
      if (!await destination.exists()) {
        await destination.create(recursive: true);
      }

      await for (FileSystemEntity entity in source.list(recursive: false)) {
        final newPath = p.join(destination.path, p.basename(entity.path));
        if (entity is File) {
          await entity.copy(newPath);
        } else if (entity is Directory) {
          await copyDirectory(entity, Directory(newPath));
        }
      }
    } catch (_) {
      throw Exception("Error");
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

  void _onConfirmToUpdateModClicked() {
    showUpdateModSnackbar(
      context,
      ProviderScope.containerOf(context, listen: false),
    );
    triggerRefresh(ref);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Copy mods'.tr(),
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
                    _onConfirmToUpdateModClicked();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ]
              : [],
    );
  }
}

class UpdateModDialog extends ConsumerStatefulWidget {
  final String modsPath;
  const UpdateModDialog({super.key, required this.modsPath});

  @override
  ConsumerState<UpdateModDialog> createState() => _UpdateModDialogState();
}

class _UpdateModDialogState extends ConsumerState<UpdateModDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showClose = false;
  bool _needReload = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    validatingModsPath();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> modsPathIsLocatedInTheSameDirectoryAsDllAndMainIniFile(
    String path,
  ) async {
    final basePath = p.dirname(path);
    final d3dxIni = p.join(basePath, "d3dx.ini");
    final d3d11Dll = p.join(basePath, "d3d11.dll");
    if (await File(d3dxIni).exists() && await File(d3d11Dll).exists()) {
      return true;
    }
    return false;
  }

  Future<void> validatingModsPath() async {
    setState(() {
      contents = [];
      contents.add(
        TextSpan(
          text: 'Validating Mods Path...'.tr(),
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    });

    bool validModsPath = false;

    try {
      final modsPath = p.normalize(widget.modsPath);

      if (!await Directory(modsPath).exists()) {
        setState(() {
          _showClose = true;
          contents = [
            TextSpan(
              text: "Mods path doesn't exist".tr(),
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ];
        });
      } else if ((modsPath.toLowerCase().endsWith('mods') ||
              modsPath.toLowerCase().endsWith('mods\\')) &&
          await modsPathIsLocatedInTheSameDirectoryAsDllAndMainIniFile(
            modsPath,
          )) {
        setState(() {
          contents = [
            TextSpan(
              text: "Modifying mods...".tr(),
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ];
        });
        //
        validModsPath = true;
        //
      } else {
        setState(() {
          _showClose = true;
          contents = [
            TextSpan(
              text:
                  "Mods path is invalid. Make sure you're targetting \"Mods\" folder."
                      .tr(),
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ];
        });
      }
    } catch (_) {
      setState(() {
        _showClose = true;
        contents = [
          TextSpan(
            text:
                "Mods path is invalid, please remove all illegal characters."
                    .tr(),
            style: GoogleFonts.poppins(color: Colors.red),
          ),
        ];
      });
    }

    if (validModsPath) {
      await manageMods(p.normalize(widget.modsPath));
    }
  }

  Future<void> manageMods(String modsPath) async {
    final operationResults = await updateModData(modsPath, (needReload) {
      setState(() {
        _needReload = needReload;
      });
    }, ref.read(targetGameProvider).name);
    setState(() {
      _showClose = true;
      contents = operationResults;
    });
    _scrollToBottom();
    final groupFolders = await getGroupFolders(
      p.join(modsPath, ConstantVar.managedFolderName),
    );

    //No need to update mod data
    SharedPrefUtils().setCurrentTargetGameNeedUpdateMod(
      ref.read(targetGameProvider),
      false,
    );

    //Auto group Icon
    final futures = <Future>[];

    for (var group in groupFolders) {
      final iconPath = p.join(group.$1.path, 'icon.png');
      final iconFile = File(iconPath);

      if (!await iconFile.exists()) {
        if (!context.mounted) return;
        futures.add(tryGetIcon(group.$1.path, ref.read(autoIconProvider)));
      }
    }

    await Future.wait(futures);
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
        'Manage mods'.tr(),
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
                _needReload
                    ? TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        ref.read(alertDialogShownProvider.notifier).state =
                            false;
                        await simulateKeyF10();
                        triggerRefresh(ref);
                      },
                      child: Text(
                        'Close & Reload'.tr(),
                        style: GoogleFonts.poppins(color: Colors.blue),
                      ),
                    )
                    : TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(alertDialogShownProvider.notifier).state =
                            false;
                        triggerRefresh(ref);
                      },
                      child: Text(
                        'Close'.tr(),
                        style: GoogleFonts.poppins(color: Colors.blue),
                      ),
                    ),
              ]
              : [],
    );
  }
}

class RevertModDialog extends ConsumerStatefulWidget {
  final List<Directory> modDirs;
  const RevertModDialog({super.key, required this.modDirs});

  @override
  ConsumerState<RevertModDialog> createState() => _RevertModDialogState();
}

class _RevertModDialogState extends ConsumerState<RevertModDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showClose = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    revertMods();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> revertMods() async {
    setState(() {
      contents = [];
      contents.add(
        TextSpan(
          text: 'Reverting mods...'.tr(),
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      );
    });
    final operationResults = await revertManagedMod(widget.modDirs);
    setState(() {
      _showClose = true;
      contents = operationResults;
    });
    _scrollToBottom();
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
        'Revert mods'.tr(),
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
                    'Close'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ]
              : [],
    );
  }
}

class DuplicatedUtilitiesDialog extends ConsumerStatefulWidget {
  final List<String> utilityPaths;
  const DuplicatedUtilitiesDialog({super.key, required this.utilityPaths});

  @override
  ConsumerState<DuplicatedUtilitiesDialog> createState() =>
      _DuplicatedUtilitiesDialogState();
}

class _DuplicatedUtilitiesDialogState
    extends ConsumerState<DuplicatedUtilitiesDialog> {
  final ScrollController _scrollController = ScrollController();
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    showPaths();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> showPaths() async {
    setState(() {
      contents = [];
      for (var path in widget.utilityPaths) {
        contents.add(
          TextSpan(
            text: '$path\n\n',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        );
      }
    });

    _scrollToBottom();
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

  Future<void> _disableAllUtilities() async {
    for (var path in widget.utilityPaths) {
      String newPath = p.join(p.dirname(path), "DISABLED${p.basename(path)}");
      try {
        await File(path).rename(newPath);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Details'.tr(),
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
          onPressed: () async {
            Navigator.of(context).pop();
            ref.read(alertDialogShownProvider.notifier).state = false;
            await _disableAllUtilities();
          },
          child: Text(
            'Disable all'.tr(),
            style: GoogleFonts.poppins(color: Colors.blue),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(alertDialogShownProvider.notifier).state = false;
          },
          child: Text(
            'Close'.tr(),
            style: GoogleFonts.poppins(color: Colors.blue),
          ),
        ),
      ],
    );
  }
}

////////////////////////
///
///

class RemoveModGroupDialog extends ConsumerStatefulWidget {
  final String name;
  final String validModsPath;
  final Directory modOrGroupDir;
  final bool isGroup;
  const RemoveModGroupDialog({
    super.key,
    required this.name,
    required this.validModsPath,
    required this.modOrGroupDir,
    required this.isGroup,
  });

  @override
  ConsumerState<RemoveModGroupDialog> createState() =>
      _RemoveModGroupDialogState();
}

class _RemoveModGroupDialogState extends ConsumerState<RemoveModGroupDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showConfirm = true;
  bool _isLoading = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    showWarning();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void showWarning() {
    setState(() {
      contents = [
        TextSpan(
          text: "${widget.name}\n",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        TextSpan(
          text:
              widget.isGroup
                  ? "Removing group will revert and remove all changes you made while these mods on this group where managed."
                      .tr()
                  : "Removing mod will revert and remove all changes you made while this mod where managed."
                      .tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        TextSpan(
          text: "Folder will be moved".tr(
            args: ["Mods/${ConstantVar.managedRemovedFolderName}"],
          ),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      ];
    });
  }

  Future<void> renameOrMoveFolder() async {
    setState(() {
      _showConfirm = false;
      _isLoading = true;
      contents = [
        TextSpan(
          text: "Loading...".tr(),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      ];
    });
    String baseFolderName = p.basename(widget.modOrGroupDir.path);
    String managedPath = p.join(
      widget.validModsPath,
      ConstantVar.managedRemovedFolderName,
    );
    String availableFolderName = await _getAvailableFolderName(
      baseFolderName,
      managedPath,
    );
    String destPath = p.join(managedPath, availableFolderName);

    try {
      if (!await Directory(managedPath).exists()) {
        await Directory(managedPath).create(recursive: true);
      }

      Directory movedDir = await widget.modOrGroupDir.rename(destPath);
      List<TextSpan> operationLogs = await revertManagedMod([movedDir]);
      operationLogs.insert(
        0,
        TextSpan(
          text: "Folder moved to unmanaged".tr(
            args: ['Mods/${ConstantVar.managedRemovedFolderName}'],
          ),
          style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
        ),
      );

      setState(() {
        contents = operationLogs;
      });
    } catch (_) {
      setState(() {
        contents = [
          TextSpan(
            text:
                "${'Failed to move folder'.tr()}.\n${ConstantVar.defaultErrorInfo}",
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
          ),
        ];
      });
    }

    setState(() {
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<String> _getAvailableFolderName(
    String baseFolderName,
    String destParentPath,
  ) async {
    String folderName = baseFolderName;
    while (await Directory(p.join(destParentPath, folderName)).exists()) {
      folderName = "${folderName}_";
    }
    return folderName;
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

  void _onConfirmToUpdateModClicked() {
    String? modsPath = ref.read(validModsPath);
    if (modsPath != null) {
      showUpdateModSnackbar(
        context,
        ProviderScope.containerOf(context, listen: false),
      );
      triggerRefresh(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isGroup ? 'Remove group'.tr() : 'Remove mod'.tr(),
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
          _showConfirm
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
                TextButton(
                  onPressed: () async {
                    await renameOrMoveFolder();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
              ]
              : _isLoading
              ? []
              : [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = false;
                    _onConfirmToUpdateModClicked();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
    );
  }
}

class EditModLinkDialog extends ConsumerStatefulWidget {
  final File modLinkFile;
  const EditModLinkDialog({super.key, required this.modLinkFile});

  @override
  ConsumerState<EditModLinkDialog> createState() => _EditModLinkDialogState();
}

class _EditModLinkDialogState extends ConsumerState<EditModLinkDialog> {
  final textController = TextEditingController();
  @override
  void initState() {
    super.initState();
    loadModLink();
  }

  Future<void> loadModLink() async {
    try {
      String url = await forceReadAsStringUtf8(widget.modLinkFile);
      textController.text = url;
    } catch (_) {}
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Mod link'.tr(),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: TextField(
        controller: textController,
        decoration: InputDecoration(
          isDense: true,
          disabledBorder: InputBorder.none,
          hintText: 'https://modlink.example',
          hintStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            color: const Color.fromARGB(30, 255, 255, 255),
            fontSize: 14,
          ),
        ),
        maxLines: null,
        keyboardType: TextInputType.none,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w400,
          color: Colors.white,
          fontSize: 13,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'[\n\r\u0085\u2028\u2029]')),
        ],
      ),
      actions: [
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
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await widget.modLinkFile.writeAsString(textController.text);
          },
          child: Text(
            'Confirm'.tr(),
            style: GoogleFonts.poppins(color: Colors.blue),
          ),
        ),
      ],
    );
  }
}

class DisableAllModsDialog extends ConsumerStatefulWidget {
  final String validModsPath;
  const DisableAllModsDialog({super.key, required this.validModsPath});

  @override
  ConsumerState<DisableAllModsDialog> createState() =>
      _DisableAllModsDialogState();
}

class _DisableAllModsDialogState extends ConsumerState<DisableAllModsDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showConfirm = true;
  bool _isLoading = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    showWarning();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void showWarning() {
    setState(() {
      contents = [
        TextSpan(
          text: 'Disable all managed mods?'.tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
        TextSpan(
          text: 'Usually only for troubleshooting purpose.'.tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ];
    });
  }

  Future<void> disableAllMods() async {
    setState(() {
      _showConfirm = false;
      _isLoading = true;
    });

    final String managedPath = p.join(
      widget.validModsPath,
      ConstantVar.managedFolderName,
    );

    setState(() {
      contents = [
        TextSpan(
          text: "Disabling all mods...".tr(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    });

    final modGroups = await getGroupFolders(managedPath);

    List<(Directory groupDir, ModData modData)> failedDisabledMod = [];

    for (var group in modGroups) {
      final mods = await getModsOnGroup(group.$1, false);
      for (var mod in mods) {
        if (p.basename(mod.modDir.path).toLowerCase().startsWith('disabled')) {
          continue;
        }

        //Dummy mod, for none, returned by getModsOnGroup
        if (mod.modDir.path == 'None') continue;

        bool success = await completeDisableMod(mod.modDir);
        if (!success) failedDisabledMod.add((group.$1, mod));
      }
    }

    List<TextSpan> failedDisableInfo = [];
    for (var mod in failedDisabledMod) {
      String groupName = '';
      try {
        groupName = await forceReadAsStringUtf8(
          File(p.join(mod.$1.path, 'groupname')),
        );
      } catch (_) {}
      failedDisableInfo.add(
        TextSpan(
          text: "$groupName - ${mod.$2.modName}\n${mod.$2.modDir.path}\n\n",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    setState(() {
      _isLoading = false;

      if (failedDisabledMod.isEmpty) {
        contents = [
          TextSpan(
            text: "All managed mods have been disabled".tr(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ];
      } else {
        contents = [
          ...failedDisableInfo,
          TextSpan(
            text:
                "Some mods cannot be disabled, please rename and disable these mods manually via File Explorer."
                    .tr(),
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 189, 170, 0),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ];
      }
    });

    _scrollToBottom();
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
        "Disable all mods".tr(),
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
          _showConfirm
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
                TextButton(
                  onPressed: () async {
                    await disableAllMods();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ]
              : _isLoading
              ? []
              : [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = true;
                    await showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder:
                          (context) => UpdateModDialog(
                            modsPath: ref.read(validModsPath)!,
                          ),
                    );
                  },
                  child: Text(
                    'Update Mod Data'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
    );
  }
}

class EnableAllModsDialog extends ConsumerStatefulWidget {
  final String validModsPath;
  const EnableAllModsDialog({super.key, required this.validModsPath});

  @override
  ConsumerState<EnableAllModsDialog> createState() =>
      _EnableAllModsDialogState();
}

class _EnableAllModsDialogState extends ConsumerState<EnableAllModsDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showConfirm = true;
  bool _isLoading = false;
  List<TextSpan> contents = [];

  @override
  void initState() {
    super.initState();
    showWarning();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void showWarning() {
    setState(() {
      contents = [
        TextSpan(
          text: 'Enable all managed mods?'.tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ];
    });
  }

  Future<void> enableAllMods() async {
    setState(() {
      _showConfirm = false;
      _isLoading = true;
    });

    final String managedPath = p.join(
      widget.validModsPath,
      ConstantVar.managedFolderName,
    );

    setState(() {
      contents = [
        TextSpan(
          text: "Enabling all mods...".tr(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    });

    final modGroups = await getGroupFolders(managedPath);

    List<(Directory groupDir, ModData modData)> failedEnableMod = [];

    for (var group in modGroups) {
      final mods = await getModsOnGroup(group.$1, true);
      for (var mod in mods) {
        if (p.basename(mod.modDir.path).toLowerCase().startsWith('disabled')) {
          //Dummy mod, for none, returned by getModsOnGroup
          if (mod.modDir.path == 'None') continue;

          bool success = await enableMod(mod.modDir);
          if (!success) failedEnableMod.add((group.$1, mod));
        }
      }
    }

    List<TextSpan> failedEnableInfo = [];
    for (var mod in failedEnableMod) {
      String groupName = '';
      try {
        groupName = await forceReadAsStringUtf8(
          File(p.join(mod.$1.path, 'groupname')),
        );
      } catch (_) {}
      //
      failedEnableInfo.add(
        TextSpan(
          text: "$groupName - ${mod.$2.modName}\n${mod.$2.modDir.path}\n\n",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    setState(() {
      _isLoading = false;

      if (failedEnableMod.isEmpty) {
        contents = [
          TextSpan(
            text: "All managed mods have been enabled".tr(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ];
      } else {
        contents = [
          ...failedEnableInfo,
          TextSpan(
            text:
                "Some mods cannot be enabled, please rename and enable these mods manually via File Explorer."
                    .tr(),
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 189, 170, 0),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ];
      }
    });

    _scrollToBottom();
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
        "Enable all mods".tr(),
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
          _showConfirm
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
                TextButton(
                  onPressed: () async {
                    await enableAllMods();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ]
              : _isLoading
              ? []
              : [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = true;
                    await showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder:
                          (context) => UpdateModDialog(
                            modsPath: ref.read(validModsPath)!,
                          ),
                    );
                  },
                  child: Text(
                    'Update Mod Data'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
    );
  }
}

class ChangeNamespaceDialog extends ConsumerStatefulWidget {
  final String modPath;
  const ChangeNamespaceDialog({super.key, required this.modPath});

  @override
  ConsumerState<ChangeNamespaceDialog> createState() =>
      _ChangeNamespaceDialogState();
}

class _ChangeNamespaceDialogState extends ConsumerState<ChangeNamespaceDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _showSaveButton = false;
  bool _isLoading = false;
  bool _wasSaved = false;
  bool _namespaceChanged = false;
  List<TextSpan> contents = [];

  List<String> iniFilesPath = [];
  //original, modified
  Map<String, String> namespacesMap = {};
  Map<String, TextEditingController> textControllersMap = {};

  @override
  void initState() {
    super.initState();
    readNamespaces();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> readNamespaces() async {
    setState(() {
      _isLoading = true;
      _showSaveButton = false;
      contents = [
        TextSpan(
          text: 'Loading mods'.tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ];
    });

    //get all ini files within specified mod folder
    iniFilesPath = await findIniFilesRecursiveExcludeDisabled(widget.modPath);

    //get the namespaces
    for (var path in iniFilesPath) {
      final namespace = await getNamespace(File(path));
      if (namespace.isNotEmpty) {
        //ignore case
        bool alreadyExist = namespacesMap.keys.any(
          (k) => k.toLowerCase() == namespace.toLowerCase(),
        );
        //Only add to list, if wasn't previously found.
        //Sometimes there's a mod that separate constants and commandlist, but still using same namespace (no problem)
        //Or sometimes there's a situation that clearly contains multiple duplicated namespaces, don't care
        if (!alreadyExist) {
          namespacesMap[namespace] = namespace;
        }
      }
    }

    //Generate controller based on namespaceMap
    for (var entry in namespacesMap.entries) {
      final controller = TextEditingController();
      controller.text = entry.value;
      textControllersMap[entry.key] = controller;
    }

    setState(() {
      _isLoading = false;
      _showSaveButton = true;
      contents = [
        TextSpan(
          text:
              "Change the namespace if it's duplicated with another mod.".tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        TextSpan(
          text:
              'To avoid duplication, it should be unique and easy to read, not generic or too long.'
                  .tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 255, 255, 255),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ];
    });
  }

  Future<void> saveNamespace() async {
    setState(() {
      _isLoading = true;
      _showSaveButton = false;
    });

    //Update namespaceMap based on text controllers & its pair
    for (var entry in textControllersMap.entries) {
      if (namespacesMap.containsKey(entry.key)) {
        namespacesMap[entry.key] = entry.value.text;
      }
    }

    //detect if duplcated values
    final values = namespacesMap.values.map((v) => v.toLowerCase()).toList();
    var uniqueValues = values.toSet();
    bool containsEmptyValue = uniqueValues.any(
      (element) => element.trim().isEmpty,
    );

    //Check if current namespace contains previously used namespace but on another file/slot.
    bool valueWasUsedPreviously = false;
    for (var entry in textControllersMap.entries) {
      if (namespacesMap.containsKey(entry.value.text) &&
          entry.key != entry.value.text) {
        valueWasUsedPreviously = true;
        break;
      }
    }

    //Do not save if empty
    if (containsEmptyValue) {
      setState(() {
        contents = [
          ...contents.take(
            2,
          ), // only take that namespace informations from previous assignment, do not take "can't save...", incase user press it multiple times
        ];
      });
      await Future.delayed(
        Duration(milliseconds: 50),
      ); //small delay to simulate blinking text
      setState(() {
        contents = [
          ...contents,
          TextSpan(
            text: "Can't save empty values.".tr(),
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 189, 170, 0),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ];
      });

      setState(() {
        _isLoading = false;
        _showSaveButton = true;
      });
    }
    //If Duplicated, just show warning, do not save
    else if (uniqueValues.length != values.length) {
      setState(() {
        contents = [
          ...contents.take(
            2,
          ), // only take that namespace informations from previous assignment, do not take "can't save...", incase user press it multiple times
        ];
      });
      await Future.delayed(
        Duration(milliseconds: 50),
      ); //small delay to simulate blinking text
      setState(() {
        contents = [
          ...contents,
          TextSpan(
            text: "Can't save duplicated values.".tr(),
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 189, 170, 0),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ];
      });

      setState(() {
        _isLoading = false;
        _showSaveButton = true;
      });
    } else if (valueWasUsedPreviously) {
      //Check if current namespace contains previously used namespace but on another file/slot.
      for (var entry in textControllersMap.entries) {
        if (namespacesMap.containsKey(entry.value.text) &&
            entry.key != entry.value.text) {
          setState(() {
            contents = [
              ...contents.take(
                2,
              ), // only take that namespace informations from previous assignment, do not take "can't save...", incase user press it multiple times
            ];
          });
          await Future.delayed(
            Duration(milliseconds: 50),
          ); //small delay to simulate blinking text
          setState(() {
            contents = [
              ...contents,
              TextSpan(
                text:
                    "Namespace is already used by another slot in this mod."
                        .tr(),
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 189, 170, 0),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ];
          });

          setState(() {
            _isLoading = false;
            _showSaveButton = true;
          });
        }
      }
    }
    //IF not duplicated, try save
    else {
      bool success = true;

      for (final entry in namespacesMap.entries) {
        //skip if nothing changed
        if (entry.key == entry.value) {
          continue;
        }
        _namespaceChanged = true;
        success = await replaceNamespace(entry.key, entry.value, iniFilesPath);
        if (!success) {
          break;
        }
      }

      setState(() {
        _isLoading = false;
        _showSaveButton = false;
        _wasSaved = true;
        contents = [
          success
              ? TextSpan(
                text:
                    _namespaceChanged
                        ? 'Namespace modified.'.tr()
                        : 'Nothing changed.'.tr(),
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              )
              : TextSpan(
                text:
                    '${'Failed to modify namespaces.'.tr()}\n\n${ConstantVar.defaultErrorInfo}',
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 189, 170, 0),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        "Change namespace".tr(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: TextSpan(children: contents)),
                if (namespacesMap.isEmpty && !_isLoading)
                  Text(
                    'No namespaces found.'.tr(),
                    style: GoogleFonts.poppins(
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  )
                else if (!_wasSaved)
                  ...textControllersMap.entries.map((controller) {
                    return TextField(
                      readOnly: _isLoading,
                      controller: controller.value,
                      decoration: InputDecoration(
                        disabledBorder: InputBorder.none,
                        hintText: 'A-Z a-z 0-9 _ \\',
                        hintStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w400,
                          color: const Color.fromARGB(71, 255, 255, 255),
                          fontSize: 14,
                        ),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.none,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9a-zA-Z\\_]'),
                        ),
                        FilteringTextInputFormatter.deny(
                          RegExp(r'[\n\r\u0085\u2028\u2029]'),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
      actions:
          _showSaveButton
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
                if (namespacesMap.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await saveNamespace();
                    },
                    child: Text(
                      'Confirm'.tr(),
                      style: GoogleFonts.poppins(color: Colors.blue),
                    ),
                  ),
              ]
              : _isLoading
              ? []
              : [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    ref.read(alertDialogShownProvider.notifier).state = false;
                    if (_namespaceChanged) {
                      await simulateKeyF10();
                    }
                  },
                  child: Text(
                    _namespaceChanged ? 'Close & Reload'.tr() : 'Close'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
    );
  }
}
