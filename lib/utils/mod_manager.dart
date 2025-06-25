import 'dart:io';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/auto_group_icon.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulator_manager.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

bool _hasIndex(int index, int listLength) {
  return index >= 0 && index < listLength;
}

void triggerRefresh(WidgetRef ref) {
  try {
    TargetGame currentTargetGame = ref.read(targetGameProvider);
    ref.read(targetGameProvider.notifier).state = TargetGame.none;
    ref.read(targetGameProvider.notifier).state = currentTargetGame;
  } catch (e) {}
}

Future<List<ModGroupData>> refreshModData(Directory managedDir) async {
  final validGroupFolders = await getGroupFolders(managedDir.path);

  List<ModGroupData> results = await Future.wait(
    validGroupFolders.map((group) async {
      List<ModData> modsInGroup = await getModsOnGroup(group.$1, true);
      return ModGroupData(
        groupDir: group.$1,
        groupIcon: getModOrGroupIcon(group.$1),
        groupName: await getGroupName(group.$1),
        modsInGroup: modsInGroup,
        realIndex: group.$2,
        previousSelectedModOnGroup: await getSelectedModInGroup(
          group.$1,
          modsInGroup.length,
        ),
      );
    }),
  );
  return results;
}

//////////////////////////

Future<List<(Directory, int)>> getGroupFolders(
  String modsPath, {
  bool shouldThrowOnError = false,
}) async {
  final directory = Directory(modsPath);
  final List<(Directory, int)> matchingFolders = [];

  try {
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          final match = RegExp(
            r'^group_([1-9]|[1-9][0-9]|[1-4][0-9]{2}|500)$',
            caseSensitive: true,
          ).firstMatch(folderName);

          if (match != null) {
            final index = int.parse(match.group(1)!);
            matchingFolders.add((entity, index));
          }
        }
      }

      matchingFolders.sort((a, b) => a.$2.compareTo(b.$2));
    }
  } catch (e) {
    if (shouldThrowOnError) {
      throw Exception("Error");
    } else {
      print('Error reading directory: $e');
    }
  }

  return matchingFolders;
}

Future<int?> addGroup(WidgetRef ref, String managedPath) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();
  for (int i = 1; i <= 500; i++) {
    String folderName = 'group_$i';
    Directory folder = Directory('$managedPath/$folderName');

    if (!await folder.exists()) {
      await folder.create();
      await getGroupName(folder);
      _addGroupToRiverpod(ref, folder, i - 1);
      if (watchedPath != null) {
        DynamicDirectoryWatcher.watch(watchedPath);
      }
      return i;
    }
  }
  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
  return null;
}

void _addGroupToRiverpod(WidgetRef ref, Directory groupDir, int index) {
  final currentList = ref.read(modGroupDataProvider);
  final newGroup = ModGroupData(
    groupDir: groupDir,
    groupIcon: getModOrGroupIcon(groupDir),
    groupName: p.basename(groupDir.path),
    modsInGroup: [
      ModData(
        modDir: Directory("None"),
        modIcon: null,
        modName: "None".tr(),
        realIndex: 0,
      ),
    ],
    realIndex: index + 1,
    previousSelectedModOnGroup: 0,
  );

  // Add the new group at the specified index
  final updatedList = [
    ...currentList.sublist(0, index), // All elements before the index
    newGroup, // The new group to add
    ...currentList.sublist(index), // All elements after the index
  ];

  // Write it back
  ref.read(modGroupDataProvider.notifier).state = updatedList;
}

Future<String> getGroupName(Directory groupDir) async {
  try {
    final fileGroupName = File(p.join(groupDir.path, 'groupname'));

    if (await fileGroupName.exists()) {
      return await fileGroupName.readAsString();
    } else {
      final folderName = p.basename(groupDir.path);
      String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
      DynamicDirectoryWatcher.stop();
      await fileGroupName.writeAsString(folderName);
      if (watchedPath != null) {
        DynamicDirectoryWatcher.watch(watchedPath);
      }
      return folderName;
    }
  } catch (e) {
    final folderName = p.basename(groupDir.path);
    return folderName;
  }
}

Future<int> getSelectedModInGroup(
  Directory groupDir,
  int modsInGroupLength,
) async {
  try {
    final fileSelectedIndex = File(p.join(groupDir.path, 'selectedindex'));

    if (await fileSelectedIndex.exists()) {
      int? result = int.tryParse(await fileSelectedIndex.readAsString());
      if (result != null) {
        if (_hasIndex(result, modsInGroupLength)) {
          return result;
        } else {
          return 0;
        }
      } else {
        return 0;
      }
    } else {
      String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
      DynamicDirectoryWatcher.stop();
      await fileSelectedIndex.writeAsString("0");
      if (watchedPath != null) {
        DynamicDirectoryWatcher.watch(watchedPath);
      }
      return 0;
    }
  } catch (e) {
    return 0;
  }
}

Future<int> getSelectedGroupIndex(String managedPath, int groupLength) async {
  try {
    final fileSelectedIndex = File(p.join(managedPath, 'selectedindex'));

    if (await fileSelectedIndex.exists()) {
      int? result = int.tryParse(await fileSelectedIndex.readAsString());
      if (result != null) {
        if (_hasIndex(result, groupLength)) {
          return result;
        } else {
          return 0;
        }
      } else {
        return 0;
      }
    } else {
      String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
      DynamicDirectoryWatcher.stop();
      await fileSelectedIndex.writeAsString("0");
      if (watchedPath != null) {
        DynamicDirectoryWatcher.watch(watchedPath);
      }
      return 0;
    }
  } catch (e) {
    return 0;
  }
}

Future<void> setSelectedGroupIndex(int index, String managedPath) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();

  try {
    final fileSelectedIndex = File(p.join(managedPath, 'selectedindex'));
    await fileSelectedIndex.writeAsString(index.toString());
  } catch (e) {}

  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
}

Future<void> setGroupNameOnDisk(Directory groupDir, String groupName) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();
  try {
    final fileGroupName = File(p.join(groupDir.path, 'groupname'));

    await fileGroupName.writeAsString(groupName);
  } catch (e) {}
  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
}

Future<void> setModNameOnDisk(Directory modDir, String modName) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();
  try {
    final fileGroupName = File(p.join(modDir.path, 'modname'));

    await fileGroupName.writeAsString(modName);
  } catch (e) {}
  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
}

Image? getModOrGroupIcon(Directory groupDir) {
  final file = File(p.join(groupDir.path, "icon.png"));

  if (file.existsSync()) {
    try {
      return Image.file(
        file,
        cacheWidth: 156 * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            size: 35,
            Icons.image_outlined,
            color: const Color.fromARGB(127, 255, 255, 255),
          );
        },
      );
    } catch (e) {
      // fallback in case FileImage fails
      return null;
    }
  } else {
    return null;
  }
}

Future<void> setGroupOrModIcon(
  WidgetRef ref,
  Directory groupDir,
  Image? oldImage, {
  bool fromClipboard = false,
  bool isGroup = true,
  Directory? modDir,
}) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();
  oldImage?.image.evict();
  if (fromClipboard == false) {
    bool windowWasPinned = ref.read(windowIsPinnedProvider);
    ref.read(windowIsPinnedProvider.notifier).state = true;
    final pickResult = await FilePicker.platform.pickFiles(
      lockParentWindow: true,
      dialogTitle: "Select an image file".tr(),
      type: FileType.image,
    );
    if (pickResult != null) {
      if (isGroup) {
        Image imgResult = Image.file(
          File(pickResult.files[0].path!),
          cacheWidth: 108 * 2,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) => Icon(
                size: 35,
                Icons.image_outlined,
                color: const Color.fromARGB(127, 255, 255, 255),
              ),
        );
        _updateGroupIconProvider(ref, groupDir, imgResult);
        try {
          File sourceFile = File(pickResult.files[0].path!);
          String targetDest = p.join(groupDir.path, "icon.png");
          await sourceFile.copy(targetDest);
        } catch (e) {}
      } else if (modDir != null) {
        Image imgResult = Image.file(
          File(pickResult.files[0].path!),
          cacheWidth: 108 * 2,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) => Icon(
                size: 35,
                Icons.image_outlined,
                color: const Color.fromARGB(127, 255, 255, 255),
              ),
        );
        _updateModIconProvider(ref, groupDir, modDir, imgResult);
        try {
          File sourceFile = File(pickResult.files[0].path!);
          String targetDest = p.join(modDir.path, "icon.png");
          await sourceFile.copy(targetDest);
        } catch (e) {}
      }
    }
    ref.read(windowIsPinnedProvider.notifier).state = windowWasPinned;
  } else {
    try {
      final imgBytes = await Pasteboard.image;
      if (imgBytes != null) {
        if (isGroup) {
          Image img = Image.memory(
            imgBytes,
            cacheWidth: 108 * 2,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Icon(
                  size: 35,
                  Icons.image_outlined,
                  color: const Color.fromARGB(127, 255, 255, 255),
                ),
          );
          _updateGroupIconProvider(ref, groupDir, img);
          await File(
            p.join(groupDir.path, "icon.png"),
          ).writeAsBytes(imgBytes.toList());
        } else if (modDir != null) {
          Image img = Image.memory(
            imgBytes,
            cacheWidth: 108 * 2,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Icon(
                  size: 35,
                  Icons.image_outlined,
                  color: const Color.fromARGB(127, 255, 255, 255),
                ),
          );
          _updateModIconProvider(ref, groupDir, modDir, img);
          await File(
            p.join(modDir.path, "icon.png"),
          ).writeAsBytes(imgBytes.toList());
        }
      }
    } catch (e) {}
  }

  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
}

Future<void> unsetGroupOrModIcon(
  WidgetRef ref,
  Directory groupDir,
  Image? oldImage, {
  Directory? modDir,
}) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();
  oldImage?.image.evict();
  if (modDir == null) {
    Image imgResult = Image.file(
      File(''),
      cacheWidth: 108 * 2,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) => Icon(
            size: 35,
            Icons.image_outlined,
            color: const Color.fromARGB(127, 255, 255, 255),
          ),
    );
    _updateGroupIconProvider(ref, groupDir, imgResult);
    try {
      File sourceFile = File(p.join(groupDir.path, "icon.png"));
      await sourceFile.delete();
    } catch (e) {}
  } else {
    Image imgResult = Image.file(
      File(''),
      cacheWidth: 108 * 2,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) => Icon(
            size: 35,
            Icons.image_outlined,
            color: const Color.fromARGB(127, 255, 255, 255),
          ),
    );
    _updateModIconProvider(ref, groupDir, modDir, imgResult);
    try {
      File sourceFile = File(p.join(modDir.path, "icon.png"));
      await sourceFile.delete();
    } catch (e) {}
  }

  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
}

void _updateGroupIconProvider(
  WidgetRef ref,
  Directory groupDir,
  Image newIcon,
) {
  final currentGroups = ref.read(modGroupDataProvider);

  final updatedGroups =
      currentGroups.map((group) {
        if (group.groupDir.path == groupDir.path) {
          return ModGroupData(
            groupDir: group.groupDir,
            groupIcon: newIcon,
            groupName: group.groupName,
            modsInGroup: group.modsInGroup,
            realIndex: group.realIndex,
            previousSelectedModOnGroup: group.previousSelectedModOnGroup,
          );
        }
        return group;
      }).toList();

  ref.read(modGroupDataProvider.notifier).state = updatedGroups;
}

void _updateModIconProvider(
  WidgetRef ref,
  Directory groupDir,
  Directory modDir,
  Image newIcon,
) {
  final currentGroups = ref.read(modGroupDataProvider);

  final updatedGroups =
      currentGroups.map((group) {
        if (group.groupDir.path == groupDir.path) {
          final updatedMods =
              group.modsInGroup.map((mod) {
                if (mod.modDir.path == modDir.path) {
                  return ModData(
                    modDir: mod.modDir,
                    modIcon: newIcon,
                    modName: mod.modName,
                    realIndex: mod.realIndex,
                  );
                }
                return mod;
              }).toList();

          return ModGroupData(
            groupDir: group.groupDir,
            groupIcon: group.groupIcon,
            groupName: group.groupName,
            modsInGroup: updatedMods,
            realIndex: group.realIndex,
            previousSelectedModOnGroup: group.previousSelectedModOnGroup,
          );
        }
        return group;
      }).toList();

  ref.read(modGroupDataProvider.notifier).state = updatedGroups;
}

//////////////////////////////

Future<List<ModData>> getModsOnGroup(Directory groupDir, bool limited) async {
  try {
    final List<Directory> modDirs = [];

    final contents = await groupDir.list().toList();

    for (var entity in contents) {
      if (entity is Directory) {
        modDirs.add(entity);
      }
    }

    // Limit to only 500 mod directories
    List<Directory> limitedModDirs;

    if (limited) {
      limitedModDirs = modDirs.take(500).toList();
    } else {
      limitedModDirs = modDirs;
    }

    final List<ModData> modDatas = await Future.wait(
      limitedModDirs.asMap().entries.map((entry) async {
        final int index = entry.key;
        final modDir = entry.value;
        return ModData(
          modDir: modDir,
          modIcon: getModOrGroupIcon(modDir),
          modName: await getModName(modDir),
          realIndex: index + 1, //0 will be none
        );
      }).toList(),
    );

    modDatas.insert(
      0,
      ModData(
        modDir: Directory("None"),
        modIcon: null,
        modName: "None".tr(),
        realIndex: 0,
      ),
    );

    return modDatas;
  } catch (e) {
    print('Error reading directory: $e');
    return [];
  }
}

Future<String> getModName(Directory modDir) async {
  try {
    final fileGroupName = File(p.join(modDir.path, 'modname'));

    if (await fileGroupName.exists()) {
      return await fileGroupName.readAsString();
    } else {
      final folderName = p.basename(modDir.path);
      await fileGroupName.writeAsString(folderName);

      return folderName;
    }
  } catch (e) {
    final folderName = p.basename(modDir.path);
    return folderName;
  }
}

Future<void> setSelectedModIndex(
  WidgetRef ref,
  int index,
  Directory groupDir,
) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();
  final currentGroups = ref.read(modGroupDataProvider);

  final updatedGroups =
      currentGroups.map((group) {
        if (group.groupDir.path == groupDir.path) {
          return ModGroupData(
            groupDir: group.groupDir,
            groupIcon: group.groupIcon,
            groupName: group.groupName,
            modsInGroup: group.modsInGroup,
            realIndex: group.realIndex,
            previousSelectedModOnGroup: index,
          );
        }
        return group;
      }).toList();

  ref.read(modGroupDataProvider.notifier).state = updatedGroups;

  try {
    final fileSelectedIndex = File(p.join(groupDir.path, 'selectedindex'));
    await fileSelectedIndex.writeAsString(index.toString());
  } catch (e) {}
  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
}

/////////////////////////////////////////////////////////////////////////////

Future<List<TextSpan>> revertManagedMod(List<Directory> modDirs) async {
  List<TextSpan> operationLogs = [];
  bool containsError = false;

  for (Directory folder in modDirs) {
    List<String> iniFilesBackup = await _findIniFilesManagedBackupRecursive(
      folder.path,
    );
    for (final backupFilePath in iniFilesBackup) {
      final originalFilePath = '${p.withoutExtension(backupFilePath)}.ini';
      final backupFile = File(backupFilePath);
      final originalFile = File(originalFilePath);

      try {
        if (await backupFile.exists()) {
          await backupFile.copy(originalFile.path);
          await backupFile.delete();
        }
      } catch (e) {
        containsError = true;
        operationLogs.add(
          TextSpan(
            text:
                '${'Error reverting'.tr(args: [p.basename(folder.path)])}.\n${ConstantVar.defaultErrorInfo}\n\n',
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
          ),
        );
      }
    }

    if (iniFilesBackup.isEmpty) {
      operationLogs.add(
        TextSpan(
          text: 'No backup found'.tr(args: [p.basename(folder.path)]),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    } else {
      operationLogs.add(
        TextSpan(
          text: 'Backup found'.tr(args: [p.basename(folder.path)]),
          style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
        ),
      );
    }
  }

  operationLogs.add(
    containsError
        ? TextSpan(
          text: 'Mods reverted. But there are some errors.'.tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        )
        : TextSpan(
          text: 'Mods reverted!'.tr(),
          style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
        ),
  );
  return operationLogs;
}

//public method called from main()
Future<List<TextSpan>> updateModData(
  String modsPath,
  Function setBoolIfNeedAutoReload,
) async {
  List<TextSpan> operationLogs = [];
  setBoolIfNeedAutoReload(true);
  bool needReloadManual = false;
  final managedPath = p.join(modsPath, ConstantVar.managedFolderName);
  try {
    //Try to rename old managed folder if managed folder not exist yet
    if (!await Directory(managedPath).exists()) {
      await _tryRenameOldManagedFolder(modsPath);
    }
    //if still not exist, create managed folder
    if (!await Directory(managedPath).exists()) {
      await Directory(managedPath).create();
    }

    //if background keypress not exist, ask user to reload manually
    if (!await File(
      p.join(managedPath, ConstantVar.backgroundKeypressFileName),
    ).exists()) {
      needReloadManual = true;
    }

    _createBackgroundKeypressIni(managedPath, operationLogs);
    _createManagerGroupIni(managedPath, operationLogs);

    final groupFullPathsAndIndexes = await getGroupFolders(
      managedPath,
      shouldThrowOnError: true,
    );

    await Future.wait([
      for (final (groupDir, groupIndex) in groupFullPathsAndIndexes)
        () async {
          await _deleteGroupIniFiles(groupDir.path, operationLogs);
          await _createGroupIni(groupDir.path, groupIndex, operationLogs);

          final modFullPaths = await getModsOnGroup(groupDir, false);

          await Future.wait([
            for (var j = 0; j < modFullPaths.length; j++)
              if (j != 0)
                _manageMod(
                  modFullPaths[j].modDir.path,
                  'group_$groupIndex',
                  j,
                  groupIndex,
                  operationLogs,
                ),
          ]);
        }(),
    ]);
    operationLogs.add(
      operationLogs.isEmpty
          ? TextSpan(
            text: 'Mods successfully managed!'.tr(),
            style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
          )
          : TextSpan(
            text:
                'Mods managed but with some errors. Read error information above and try again.'
                    .tr(),
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 189, 170, 0),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
    );

    if (needReloadManual) {
      setBoolIfNeedAutoReload(false);
      operationLogs.add(
        TextSpan(
          text: "Please do manual reload with F10".tr(),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }
  } catch (e) {
    operationLogs.add(
      TextSpan(
        text: "${'Unexpected error!'.tr()} ${ConstantVar.defaultErrorInfo}",
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }

  return operationLogs;
}

Future<void> _tryRenameOldManagedFolder(String modsPath) async {
  final oldPath = p.join(modsPath, ConstantVar.oldManagedFolderName);
  final anotherOldPath = p.join(
    modsPath,
    ConstantVar.anotherOldManagedFolderName,
  );

  final newPath = p.join(modsPath, ConstantVar.managedFolderName);
  final oldDir = Directory(oldPath);
  final anotherOldDir = Directory(anotherOldPath);

  if (await oldDir.exists()) {
    await oldDir.rename(newPath);
  } else if (await anotherOldDir.exists()) {
    await anotherOldDir.rename(newPath);
  }
}

Future<void> _createBackgroundKeypressIni(
  String managedPath,
  List<TextSpan> operationLogs,
) async {
  // Step 1: Load the .txt template from assets
  final template = await rootBundle.loadString(
    'assets/template_txt/listen_keypress_even_on_background.txt',
  );

  // Step 2: Create the .ini file
  final filePath = p.join(managedPath, ConstantVar.backgroundKeypressFileName);
  final iniFile = File(filePath);

  // Step 2: Write content into the .ini file
  try {
    await iniFile.writeAsString(template);
  } catch (e) {
    operationLogs.add(
      TextSpan(
        text:
            "${'Error cannot create'.tr(args: [ConstantVar.backgroundKeypressFileName])}.\n${ConstantVar.defaultErrorInfo}\n\n",
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

Future<void> _createManagerGroupIni(
  String managedPath,
  List<TextSpan> operationLogs,
) async {
  // Step 1: Load the .txt template from assets
  final template = await rootBundle.loadString(
    'assets/template_txt/template_manager_group.txt',
  );

  // Step 2: Create the .ini file
  final filePath = p.join(managedPath, ConstantVar.managerGroupFileName);
  final iniFile = File(filePath);

  // Step 2: Write content into the .ini file
  try {
    await iniFile.writeAsString(template);
  } catch (e) {
    operationLogs.add(
      TextSpan(
        text:
            "${'Error cannot create'.tr(args: [ConstantVar.managerGroupFileName])}.\n${ConstantVar.defaultErrorInfo}\n\n",
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

Future<void> _deleteGroupIniFiles(
  String folderPath,
  List<TextSpan> operationLogs,
) async {
  final dir = Directory(folderPath);
  final regex = RegExp(r'^group_(?:[1-9]|[1-9][0-9]|[1-4][0-9]{2}|500)\.ini$');

  if (await dir.exists()) {
    await for (final entity in dir.list()) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        if (regex.hasMatch(fileName)) {
          try {
            await entity.delete();
          } catch (e) {
            operationLogs.add(
              TextSpan(
                text:
                    '${'Error cannot delete previous unused group config'.tr(args: [fileName])}.\n${ConstantVar.defaultErrorInfo}\n\n',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            );
          }
        }
      }
    }
  }
}

Future<void> _createGroupIni(
  String groupFullPath,
  int groupIndex,
  List<TextSpan> operationLogs,
) async {
  // Step 1: Load the .txt template from assets
  final template = await rootBundle.loadString(
    'assets/template_txt/template_group.txt',
  );

  // Step 2: Replace placeholders
  final modifiedTemplate = template
      .replaceAll("{x}", "$groupIndex")
      .replaceAll("{group_x}", p.basename(groupFullPath));

  // Step 3: Create the .ini file
  final filePath = p.join(groupFullPath, 'group_$groupIndex.ini');
  final iniFile = File(filePath);

  // Step 4: Write content into the .ini file
  try {
    await iniFile.writeAsString(modifiedTemplate);
  } catch (e) {
    operationLogs.add(
      TextSpan(
        text:
            "${'Error cannot create'.tr(args: ['group_$groupIndex.ini'])}.\n${ConstantVar.defaultErrorInfo}\n\n",
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

Future<void> _manageMod(
  String modFolder,
  String groupFolderName,
  int modIndex,
  int groupIndex,
  List<TextSpan> operationLogs,
) async {
  try {
    // Find all INI files recursively
    final iniFiles = await findIniFilesRecursiveExcludeDisabled(modFolder);

    // Create a list of Future objects for each INI file's backup and modification
    final futures = <Future>[];

    for (final iniFile in iniFiles) {
      // Create backup path
      final backupFile = p.setExtension(
        iniFile,
        '.${ConstantVar.managedBackupExtension}',
      );

      // Create a Future for each backup and modification
      futures.add(() async {
        // Create backup if it doesn't exist
        if (!await File(backupFile).exists()) {
          await File(iniFile).copy(backupFile);
        }

        // Modify the INI file
        await _modifyIniFile(
          iniFile,
          groupFolderName,
          modIndex,
          groupIndex,
          operationLogs,
        );
      }());
    }

    // Wait for all the tasks to complete concurrently
    await Future.wait(futures);
  } catch (e) {
    operationLogs.add(
      TextSpan(
        text:
            '${'Error in managing mod!'.tr()} ${ConstantVar.defaultErrorInfo}\n\n',
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

Future<void> _modifyIniFile(
  String iniFilePath,
  String groupFolderName,
  int modIndex,
  int groupIndex,
  List<TextSpan> operationLogs,
) async {
  try {
    // Open the INI file and read it asynchronously
    final file = File(iniFilePath);
    final lines = await file.readAsLines();

    // Parse the INI file sections
    var parsedIni = await _parseIniSections(lines);

    // Modify the INI file sections based on the given modIndex and groupIndex
    _checkAndModifySections(parsedIni, modIndex, groupIndex);

    //Force fix only, these broken mods annoying. Might still broken or behaves abnormally, its only purpose is to make broken mods don't interfere other mods.
    //PLEASE CHECK YOUR MODS BEFORE POSTING IT! TURN OFF 'MUTE WARNINGS'
    bool forcedFix = forceFixIniSections(parsedIni);

    //v2.6.1 problem
    cleanVariableBugFromPreviousVersion(parsedIni);
    cleanCommentedEndifFromPreviousVersion(parsedIni);

    if (forcedFix) {
      operationLogs.add(
        TextSpan(
          text: 'Mod forced to be fixed & might not working properly'.tr(
            args: [iniFilePath],
          ),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      );
    }

    // Write the modified content back to the INI file
    await file.writeAsString(_getLiteralIni(parsedIni));
  } catch (e) {
    operationLogs.add(
      TextSpan(
        text:
            '${'Error! Cannot modify .ini file'.tr(args: [iniFilePath])}.\n${ConstantVar.defaultErrorInfo}\n\n',
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

class IniSection {
  String name;
  List<String> lines;

  IniSection(this.name, this.lines);
}

Future<List<IniSection>> _parseIniSections(List<String> allLines) async {
  final List<IniSection> sections = [];
  IniSection currentSection = IniSection('__global__', []);
  sections.add(currentSection);

  for (var rawLine in allLines) {
    String line = rawLine.trim();
    if (line.isEmpty) continue; // skip empty lines ONLY

    if (line.startsWith('[')) {
      // New section
      String sectionName =
          line.endsWith(']')
              ? line.substring(1, line.length - 1).trim()
              : line.substring(1, line.length).trim();
      currentSection = IniSection(sectionName, []);
      sections.add(currentSection);
    } else {
      currentSection.lines.add(
        rawLine,
      ); // keep original line (with comments, etc.)
    }
  }

  // Always add a "Constants" section if needed
  bool constantsSectionIsPresent = sections.any(
    (section) => section.name.toLowerCase() == "constants",
  );

  if (!constantsSectionIsPresent) {
    sections.add(IniSection('Constants', []));
  }

  for (var section in sections) {
    if (section.name.toLowerCase().startsWith('texture')) {
      bool matchPriorityIsPresent = false;
      for (var line in section.lines) {
        if (line.trim().toLowerCase().startsWith('match_priority')) {
          matchPriorityIsPresent = true;
          break;
        }
      }

      if (!matchPriorityIsPresent) {
        section.lines.add('match_priority = 0');
      }
    }
  }

  return sections;
}

//On v2.6.1 it tried to fix missing variables on ini files,
//but instead of writing the variable (global $myvar = 1),
//it's checking the variable instead (global $myvar == 1), which does nothing and cause another error on ini files
void cleanVariableBugFromPreviousVersion(List<IniSection> sections) {
  for (var section in sections) {
    if (section.name.toLowerCase().trim() == "constants") {
      bool nrmmMarkFound = false;
      for (int i = 0; i < section.lines.length; i++) {
        var line = section.lines[i];
        if (line.contains('NRMM')) {
          nrmmMarkFound = true;
        }
        if (nrmmMarkFound) {
          section.lines[i] = line.replaceAll('==', '=');
        }
      }
    }
  }
}

//On v2.6.1 it tried to fix too much endif on ini files,
//but then there are mods that don't use 'if' from beginning of conditional statement and only using 'elif' WTF,
//then this tool accidentally remove endif needed for if $managed_slot_id ;-;
//AND EVEN WITH TOO MANY ENDIF 3dmigoto don't care, because it just ignore wrong/errored lines
void cleanCommentedEndifFromPreviousVersion(List<IniSection> sections) {
  for (var section in sections) {
    if (_isExcludedSection(section.name) || _isKeySection(section.name)) {
      continue;
    }
    bool nrmmMarkFound = false;
    for (int i = 0; i < section.lines.length; i++) {
      var line = section.lines[i];
      if (line.contains('Force remove line by NRMM')) {
        nrmmMarkFound = true;
        section.lines[i] = '';
      } else {
        if (nrmmMarkFound) {
          if (line.trim() == ';endif') {
            section.lines[i] = section.lines[i].replaceAll(';', '');
          }
        }
        nrmmMarkFound = false;
      }
    }
  }
}

bool forceFixIniSections(List<IniSection> sections) {
  bool forcedFix = false;

  //fix syntax error on if elif else if statement
  //replace elseif to be else if
  //replace else or elif or else if to be 'if' because it wasn't even started with 'if'
  //use = instead of ==, use =< and => instead of <= and >=, use =! instead of !=
  for (var section in sections) {
    if (_isExcludedSection(section.name) || _isKeySection(section.name)) {
      continue;
    }

    //replace elseif to be else if
    for (int i = 0; i < section.lines.length; i++) {
      var line = section.lines[i];
      if (line.toLowerCase().trim().startsWith('elseif ')) {
        String modifiedLine = line.replaceFirst('elseif', 'else if');
        if (modifiedLine != line) {
          section.lines[i] =
              ';Force fix syntax by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n;$line\n$modifiedLine';
          forcedFix = true;
        }
      }
    }

    //Replace else if and elif to be if, in-case if statement was not opened
    bool ifStatementWasOpened = false;
    for (int i = 0; i < section.lines.length; i++) {
      var line = section.lines[i];
      if (line.toLowerCase().trim().startsWith('if ') &&
          !line.toLowerCase().trim().contains(r'$\modmanageragl')) {
        ifStatementWasOpened = true;
      }

      if (line.toLowerCase().trim().startsWith('else if ')) {
        if (!ifStatementWasOpened) {
          String modifiedLine = line.replaceFirst('else if', 'if');
          section.lines[i] =
              ';Force fix syntax by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n;$line\n$modifiedLine';
          forcedFix = true;
          ifStatementWasOpened = true;
        }
      }

      if (line.toLowerCase().trim().startsWith('elif ')) {
        if (!ifStatementWasOpened) {
          String modifiedLine = line.replaceFirst('elif', 'if');
          section.lines[i] =
              ';Force fix syntax by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n;$line\n$modifiedLine';
          forcedFix = true;
          ifStatementWasOpened = true;
        }
      }
    }

    //Fix 'if' to be 'elif' or just give endif here

    //Example:
    //if something == 0
    //DoSomething0
    //if something == 1
    //DoSomething1
    //endif

    //To Be:
    //if something == 0
    //DoSomething0
    //elif something == 1
    //DoSomething1
    //endif

    //NEVERMIND IT'S REALLY DIFFICULT TO HANDLE SOMETHING LIKE THAT

    //Replace =! with !=
    for (int i = 0; i < section.lines.length; i++) {
      var line = section.lines[i];
      if (line.toLowerCase().trim().startsWith('if ') ||
          line.toLowerCase().trim().startsWith('elif ') ||
          line.toLowerCase().trim().startsWith('else if ')) {
        String modifiedLine = line.replaceAll('=!', '!=');
        if (modifiedLine != line) {
          section.lines[i] =
              ';Force fix syntax by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n;$line\n$modifiedLine';
          forcedFix = true;
        }
      }
    }

    //Replace => with >=
    for (int i = 0; i < section.lines.length; i++) {
      var line = section.lines[i];
      if (line.toLowerCase().trim().startsWith('if ') ||
          line.toLowerCase().trim().startsWith('elif ') ||
          line.toLowerCase().trim().startsWith('else if ')) {
        String modifiedLine = line.replaceAll('=>', '>=');
        if (modifiedLine != line) {
          section.lines[i] =
              ';Force fix syntax by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n;$line\n$modifiedLine';
          forcedFix = true;
        }
      }
    }

    //Replace =< with <=
    for (int i = 0; i < section.lines.length; i++) {
      var line = section.lines[i];
      if (line.toLowerCase().trim().startsWith('if ') ||
          line.toLowerCase().trim().startsWith('elif ') ||
          line.toLowerCase().trim().startsWith('else if ')) {
        String modifiedLine = line.replaceAll('=<', '<=');
        if (modifiedLine != line) {
          section.lines[i] =
              ';Force fix syntax by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n;$line\n$modifiedLine';
          forcedFix = true;
        }
      }
    }

    //Replace = with ==
    for (int i = 0; i < section.lines.length; i++) {
      var line = section.lines[i];
      if (line.toLowerCase().trim().startsWith('if ') ||
          line.toLowerCase().trim().startsWith('elif ') ||
          line.toLowerCase().trim().startsWith('else if ')) {
        final regex = RegExp(r'(?<![=!<>])=(?![=])');
        String modifiedLine = line.replaceAllMapped(regex, (m) => '==');
        if (modifiedLine != line) {
          section.lines[i] =
              ';Force fix syntax by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n;$line\n$modifiedLine';
          forcedFix = true;
        }
      }
    }
  }

  //add missing variable on Constants
  List<String> variablesFound = [];
  List<String> variablesShouldBeAdded = [];

  for (var section in sections) {
    if (section.name.toLowerCase().trim() == "constants") {
      for (var line in section.lines) {
        if (line.trim().startsWith(';')) {
          continue;
        }
        final regex = RegExp(r'(?<!\\)(\$[a-zA-Z_][a-zA-Z0-9_]*)');

        final matches = regex.allMatches(line);
        final results = matches.map((m) => m.group(1)!).toList();
        for (var result in results) {
          variablesFound.add(result.toLowerCase());
        }
      }
    }
  }

  for (var section in sections) {
    if (_isExcludedSection(section.name)) {
      continue;
    }
    List<String> localVariablesFound = [];

    for (var line in section.lines) {
      if (line.trim().startsWith(';')) {
        continue;
      }
      final regex = RegExp(
        r'local\s+(?<!\\)(\$[a-zA-Z_][a-zA-Z0-9_]*)',
        caseSensitive: false,
      );

      final matches = regex.allMatches(line);
      final results = matches.map((m) => m.group(1)!.toLowerCase()).toList();

      for (var result in results) {
        localVariablesFound.add(result);
      }
    }

    for (var line in section.lines) {
      if (line.trim().startsWith(';')) {
        continue;
      }
      final regex = RegExp(r'(?<!\\)(\$[a-zA-Z_][a-zA-Z0-9_]*)');

      final matches = regex.allMatches(line);
      final results = matches.map((m) => m.group(1)!).toList();
      for (var result in results) {
        if (!variablesFound.contains(result.toLowerCase())) {
          variablesFound.add(result.toLowerCase());
          if (!variablesShouldBeAdded.contains(result.toLowerCase())) {
            if (!localVariablesFound.contains(result.toLowerCase())) {
              variablesShouldBeAdded.add(result.toLowerCase());
            }
          }
        }
      }
    }
  }

  if (variablesShouldBeAdded.isNotEmpty) {
    List<String> lines = [];
    lines.add(
      ';Force add line by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.',
    );
    for (var variable in variablesShouldBeAdded) {
      lines.add('global $variable = 1');
    }
    sections.add(IniSection('Constants', lines));
    forcedFix = true;
  }

  //Fix missing variable that was used in [Key]
  //and was already added on [Constants] by NRMM
  //but always disabled (value 0) in [Present]
  //and never being enabled (value 1) in [TextureOverride]
  for (var section in sections) {
    //Only for [Key] section
    if (_isKeySection(section.name)) {
      for (var line in section.lines) {
        if (line.toLowerCase().trim().startsWith('condition')) {
          final regex = RegExp(r'(?<!\\)(\$[a-zA-Z_][a-zA-Z0-9_]*)');

          final matches = regex.allMatches(line);
          final results = matches.map((m) => m.group(1)!).toList();
          for (var result in results) {
            bool wasUsedInPresent = false;
            bool wasAddedByNRMM = false;

            //Check if it was used in Present and always disabled (value 0)
            for (var section in sections) {
              if (section.name.toLowerCase() == "present") {
                for (var line in section.lines) {
                  if (line.trim().toLowerCase().replaceAll(' ', '') ==
                      'post${result.toLowerCase()}=0') {
                    wasUsedInPresent = true;
                    break;
                  }
                }
              }
            }

            //Check if the variable was added by NRMM in Constants
            for (var section in sections) {
              if (section.name.toLowerCase() == "constants") {
                bool nrmmMarkFound = false;
                for (var line in section.lines) {
                  if (line.contains('NRMM')) {
                    nrmmMarkFound = true;
                    break;
                  }
                }

                //If constants section is not by NRMM, continue to next iteration or skip current iteration
                if (!nrmmMarkFound) {
                  continue;
                }

                //Check if the variable was found in Constants section and was added by NRMM
                for (var line in section.lines) {
                  // == because on older version of NRMM it was wrongly written like that,
                  // and be fixed on newer version of NRMM, but the fixing process is later
                  // after this forceFix function
                  if (line.trim().toLowerCase().replaceAll(' ', '') ==
                          'global${result.toLowerCase()}=1' ||
                      line.trim().toLowerCase().replaceAll(' ', '') ==
                          'global${result.toLowerCase()}==1') {
                    wasAddedByNRMM = true;
                    break;
                  }
                }
              }
            }

            //If the variable was used in Present and was added by NRMM, check if it was already specified on TextureOverride
            if (wasAddedByNRMM && wasUsedInPresent) {
              for (var section in sections) {
                if (section.name.toLowerCase().startsWith('textureoverride')) {
                  bool varAlreadyWritten = false;
                  //Check on every lines if it's already written
                  for (var line in section.lines) {
                    if (line.trim().startsWith(';')) {
                      continue;
                    }
                    if (line
                        .trim()
                        .toLowerCase()
                        .replaceAll(' ', '')
                        .contains("${result.toLowerCase()}=1")) {
                      varAlreadyWritten = true;
                      break;
                    }
                  }
                  if (varAlreadyWritten == false) {
                    section.lines.add(
                      ';Force add line by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\n$result = 1',
                    );
                    forcedFix = true;
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  //add missing endif
  for (var section in sections) {
    if (_isExcludedSection(section.name) || _isKeySection(section.name)) {
      continue;
    }
    int totalIfFound = 0;
    int totalEndifFound = 0;
    int totalEndifShouldBeAdded = 0;
    for (var line in section.lines) {
      if (line.toLowerCase().trim().startsWith('if ')) {
        totalIfFound = totalIfFound + 1;
      }
      if (line.toLowerCase().trim() == 'endif') {
        totalEndifFound = totalEndifFound + 1;
      }
    }
    totalEndifShouldBeAdded = totalIfFound - totalEndifFound;
    for (var i = 0; i < totalEndifShouldBeAdded; i++) {
      section.lines.add(
        ';Force add line by NRMM, tell mod creator to fix their broken mod. Mod creator, not mod manager creator.\nendif',
      );
      forcedFix = true;
    }
  }

  return forcedFix;
}

void _checkAndModifySections(
  List<IniSection> sections,
  int modIndex,
  int groupIndex,
) {
  final managedPattern = RegExp(
    r'(\\modmanageragl\\group_)([1-9]|[1-9][0-9]|[1-4][0-9]{2}|500)(\\active_slot)',
  );
  bool managedIdVarAdded = false;

  for (var section in sections) {
    final name = section.name;
    final lines = section.lines;
    bool found = false;
    int? keyConditionIndex;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Modify group line
      if (managedPattern.hasMatch(line) &&
          !line.trim().startsWith(';') &&
          !_isExcludedSection(name)) {
        lines[i] = line.replaceAllMapped(managedPattern, (match) {
          return '${match.group(1)}$groupIndex${match.group(3)}';
        });

        if (!_isKeySection(name)) {
          final movedLine = lines.removeAt(i);
          lines.insert(0, movedLine);
        }
        found = true;
      }

      // Detect existing condition in key section
      if (_isKeySection(name) &&
          line.trim().toLowerCase().startsWith('condition')) {
        keyConditionIndex = i;
      }
    }

    // If no managed line was found, insert
    if (!found && name != "__global__" && !_isExcludedSection(name)) {
      if (_isKeySection(name)) {
        if (keyConditionIndex != null) {
          lines[keyConditionIndex] =
              "${lines[keyConditionIndex]} && \$managed_slot_id == \$\\modmanageragl\\group_$groupIndex\\active_slot";
        } else {
          lines.insert(
            0,
            'condition = \$managed_slot_id == \$\\modmanageragl\\group_$groupIndex\\active_slot',
          );
        }
      } else {
        lines.insert(
          0,
          r'if $managed_slot_id == $\modmanageragl\group_' +
              groupIndex.toString() +
              r'\active_slot',
        );
        lines.add('endif');
      }
    }

    // Special handling for "Constants" section
    if (name.toLowerCase() == "constants") {
      bool managedVarFound = false;
      List<int> indexesWhereManagedVarFound = [];

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().toLowerCase().startsWith(
          'global \$managed_slot_id',
        )) {
          indexesWhereManagedVarFound.add(i);
          if (managedIdVarAdded) {
            lines.removeAt(i);
          } else {
            lines[i] = 'global \$managed_slot_id = $modIndex';
            managedVarFound = true;
          }
        }
      }

      for (var i = 0; i < indexesWhereManagedVarFound.length; i++) {
        if (i == 0) continue;
        lines.removeAt(indexesWhereManagedVarFound[i]);
      }

      if (!managedVarFound && !managedIdVarAdded) {
        lines.insert(0, 'global \$managed_slot_id = $modIndex');
      }

      managedIdVarAdded = true;
    }
  }
}

bool _isExcludedSection(String section) {
  // Ensure section is not empty or null to avoid errors
  if (section.isEmpty) {
    return true;
  }

  final lowerSection = section.toLowerCase();

  if (lowerSection == "constants" || lowerSection.startsWith("resource")) {
    return true;
  }

  if (lowerSection.startsWith("shader")) {
    return lowerSection.endsWith(".insertdeclarations") ||
        lowerSection.endsWith(".pattern") ||
        lowerSection.endsWith(".replace");
  }

  return false;
}

bool _isKeySection(String sectionName) {
  final lowerSectionName = sectionName.toLowerCase();
  return lowerSectionName.startsWith("key");
}

String _getLiteralIni(List<IniSection> sections) {
  final StringBuffer result = StringBuffer();

  for (var section in sections) {
    if (section.name != '__global__') {
      result.writeln('[${section.name}]');
    }
    for (var line in section.lines) {
      result.writeln(line);
    }
    result.writeln(); // Blank line between sections
  }

  return result.toString();
}

// ignore: unused_element
Future<List<String>> _findIniFilesRecursive(String mainFolder) async {
  final directory = Directory(mainFolder);
  if (!await directory.exists()) return [];

  return await directory
      .list(recursive: true)
      .where((file) => file is File && file.path.endsWith('.ini'))
      .where((file) => !file.path.toLowerCase().endsWith('desktop.ini'))
      .map((file) => file.path)
      .toList();
}

Future<List<String>> findIniFilesRecursiveExcludeDisabled(
  String mainFolder,
) async {
  final directory = Directory(mainFolder);
  if (!await directory.exists()) return [];

  return await directory
      .list(recursive: true)
      .where((file) => file is File)
      .map((file) => file.path)
      .where((path) => path.toLowerCase().endsWith('.ini'))
      .where((path) => !path.toLowerCase().endsWith('desktop.ini'))
      .where((path) => !p.basename(path).toLowerCase().startsWith('disabled'))
      .toList();
}

// ignore: unused_element
Future<List<String>> _findIniFilesManagedBackupRecursive(
  String mainFolder,
) async {
  final directory = Directory(mainFolder);
  if (!await directory.exists()) return [];

  return await directory
      .list(recursive: true)
      .where((file) => file is File)
      .map((file) => file.path)
      .where(
        (path) => path.toLowerCase().endsWith(
          '.${ConstantVar.managedBackupExtension}',
        ),
      )
      .toList();
}

String getCurrentModsPath(TargetGame targetGame) {
  switch (targetGame) {
    case TargetGame.Wuthering_Waves:
      return SharedPrefUtils().getWuwaModsPath();
    case TargetGame.Genshin_Impact:
      return SharedPrefUtils().getGenshinModsPath();
    case TargetGame.Honkai_Star_Rail:
      return SharedPrefUtils().getHsrModsPath();
    case TargetGame.Zenless_Zone_Zero:
      return SharedPrefUtils().getZzzModsPath();
    default:
      return '';
  }
}

class CopyModDialog extends ConsumerStatefulWidget {
  final List<Directory> modDirs;
  final String modsPath;
  final String targetGroupPath;
  const CopyModDialog({
    super.key,
    required this.modDirs,
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
    for (var folder in widget.modDirs) {
      Directory? disabledFolder = await renameSourceFolderToBeDisabledPrefix(
        folder,
      );
      if (disabledFolder != null) {
        String destFolderName = removeAllDisabledPrefixes(
          p.basename(disabledFolder.path),
        );
        String destDirPath = p.join(widget.targetGroupPath, destFolderName);
        destDirPath = await checkForDuplicateFolderName(destDirPath);
        try {
          await copyDirectory(disabledFolder, Directory(destDirPath));
          operationLogs.add(
            TextSpan(
              text: 'Folder copied'.tr(args: [p.basename(folder.path)]),
              style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
            ),
          );
        } catch (e) {
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
      } catch (e) {
        return null;
      }
    }
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
    } catch (e) {
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
    ref.read(alertDialogShownProvider.notifier).state = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => UpdateModDialog(modsPath: widget.modsPath),
    );
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
                    triggerRefresh(ref);
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

    try {
      if (!await Directory(widget.modsPath).exists()) {
        setState(() {
          _showClose = true;
          contents = [
            TextSpan(
              text: "Mods path doesn't exist".tr(),
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ];
        });
      } else if (widget.modsPath.toLowerCase().endsWith('mods') ||
          widget.modsPath.toLowerCase().endsWith('mods\\')) {
        setState(() {
          contents = [
            TextSpan(
              text: "Modifying mods...".tr(),
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ];
        });
        final operationResults = await updateModData(widget.modsPath, (
          needReload,
        ) {
          setState(() {
            _needReload = needReload;
          });
        });
        setState(() {
          _showClose = true;
          contents = operationResults;
        });
        _scrollToBottom();
        final groupFolders = await getGroupFolders(
          p.join(widget.modsPath, ConstantVar.managedFolderName),
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
    } catch (e) {
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
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(alertDialogShownProvider.notifier).state =
                            false;
                        simulateKeyF10();
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
    } catch (e) {
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

    triggerRefresh(ref);
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
      ref.read(alertDialogShownProvider.notifier).state = true;
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) => UpdateModDialog(modsPath: modsPath),
      );
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
                    'Update Mod Data'.tr(),
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
    );
  }
}

Future<void> openFileExplorerToSpecifiedPath(String path) async {
  if (Platform.isWindows) {
    if (await Directory(path).exists()) {
      try {
        Process.run('explorer', [path]);
      } catch (e) {}
    }
  }
}

Future<bool> completeDisableMod(Directory modDir) async {
  try {
    String renamedPath = p.join(
      p.dirname(modDir.path),
      'DISABLED${p.basename(modDir.path)}',
    );
    await modDir.rename(renamedPath);
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> enableMod(Directory modDir) async {
  try {
    String renamedPath = p.join(
      p.dirname(modDir.path),
      p
          .basename(modDir.path)
          .replaceFirst(RegExp(r'^DISABLED', caseSensitive: false), ''),
    );
    await modDir.rename(renamedPath);
    return true;
  } catch (e) {
    return false;
  }
}
