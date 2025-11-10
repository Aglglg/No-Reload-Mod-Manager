import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_group_folder_icon.dart';
import 'package:no_reload_mod_manager/utils/force_read_as_utf8.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:no_reload_mod_manager/utils/stack_collection.dart';
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
  } catch (_) {}
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

Future<List<String>> checkForRabbitFxCount(Directory modsDir) async {
  List<String> rabbitFxPath = [];

  try {
    final iniFiles = await findIniFilesRecursiveExcludeDisabled(modsDir.path);
    for (var file in iniFiles) {
      if (p.basename(file).toLowerCase() == "rabbitfx.ini") {
        rabbitFxPath.add(file);
      }
    }
  } catch (_) {}

  return rabbitFxPath;
}

Future<bool> coreOrfixFound(Directory modsDir) async {
  bool coreOrfixFound = false;

  //Check for ORFix.ini file within Core folder
  String coreFolderPath = p.join(p.dirname(modsDir.path), "Core");
  try {
    final iniFiles = await findIniFilesRecursiveExcludeDisabled(coreFolderPath);
    for (var file in iniFiles) {
      if (p.basename(file).toLowerCase() == "orfix.ini") {
        coreOrfixFound = true;
      }
    }
  } catch (_) {}

  return coreOrfixFound;
}

Future<List<String>> checkForOrfixCount(Directory modsDir) async {
  List<String> orfixPath = [];

  try {
    final iniFiles = await findIniFilesRecursiveExcludeDisabled(modsDir.path);
    for (var file in iniFiles) {
      if (p.basename(file).toLowerCase() == "orfix.ini") {
        orfixPath.add(file);
      }
    }
  } catch (_) {}

  return orfixPath;
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
  } catch (_) {
    if (shouldThrowOnError) {
      throw Exception("Error");
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
        isForced: false,
        isIncludingRabbitFx: false,
        isUnoptimized: false,
        isNamespaced: false,
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
      return await forceReadAsStringUtf8(fileGroupName);
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
  } catch (_) {
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
      int? result = int.tryParse(
        await forceReadAsStringUtf8(fileSelectedIndex),
      );
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
  } catch (_) {
    return 0;
  }
}

Future<int> getSelectedGroupIndex(String managedPath, int groupLength) async {
  try {
    final fileSelectedIndex = File(p.join(managedPath, 'selectedindex'));

    if (await fileSelectedIndex.exists()) {
      int? result = int.tryParse(
        await forceReadAsStringUtf8(fileSelectedIndex),
      );
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
  } catch (_) {
    return 0;
  }
}

Future<void> setSelectedGroupIndex(int index, String managedPath) async {
  String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
  DynamicDirectoryWatcher.stop();

  try {
    final fileSelectedIndex = File(p.join(managedPath, 'selectedindex'));
    await fileSelectedIndex.writeAsString(index.toString());
  } catch (_) {}

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
  } catch (_) {}
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
  } catch (_) {}
  if (watchedPath != null) {
    DynamicDirectoryWatcher.watch(watchedPath);
  }
}

Image? getModOrGroupIcon(Directory dir) {
  final file = File(p.join(dir.path, "icon.png"));

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
    } catch (_) {
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

          //Set folder icon in Explorer
          if (SharedPrefUtils().isAutoGenerateFolderIcon()) {
            setFolderIcon(groupDir.path, targetDest);
          }
        } catch (_) {}
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
        } catch (_) {}
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

          //Set folder icon in Explorer
          if (SharedPrefUtils().isAutoGenerateFolderIcon()) {
            setFolderIcon(groupDir.path, p.join(groupDir.path, "icon.png"));
          }
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
    } catch (_) {}
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

      //Unset folder icon in Explorer
      if (SharedPrefUtils().isAutoGenerateFolderIcon()) {
        unsetFolderIcon(groupDir.path);
      }
    } catch (_) {}
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
    } catch (_) {}
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
                    isForced: mod.isForced,
                    isIncludingRabbitFx: mod.isIncludingRabbitFx,
                    isUnoptimized: mod.isUnoptimized,
                    isNamespaced: mod.isNamespaced,
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
          isForced: await checkModWasMarkedAsForced(modDir),
          isIncludingRabbitFx: await checkModContainsRabbitFx(modDir),
          isUnoptimized: await checkModWasMarkedAsUnoptimized(modDir),
          isNamespaced: await checkModWasMarkedAsNamespaced(modDir),
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
        isForced: false,
        isIncludingRabbitFx: false,
        isUnoptimized: false,
        isNamespaced: false,
      ),
    );

    return modDatas;
  } catch (_) {
    return [];
  }
}

Future<bool> checkModWasMarkedAsForced(Directory modDir) async {
  try {
    final fileForcedName = File(p.join(modDir.path, 'modforced'));
    if (await fileForcedName.exists()) {
      return true;
    } else {
      return false;
    }
  } catch (_) {
    return false;
  }
}

Future<bool> checkModWasMarkedAsUnoptimized(Directory modDir) async {
  try {
    final fileForcedName = File(p.join(modDir.path, 'modunoptimized'));
    if (await fileForcedName.exists()) {
      return true;
    } else {
      return false;
    }
  } catch (_) {
    return false;
  }
}

Future<bool> checkModWasMarkedAsNamespaced(Directory modDir) async {
  try {
    final fileForcedName = File(p.join(modDir.path, 'modnamespaced'));
    if (await fileForcedName.exists()) {
      return true;
    } else {
      return false;
    }
  } catch (_) {
    return false;
  }
}

Future<bool> checkModContainsRabbitFx(Directory modDir) async {
  try {
    final iniFiles = await findIniFilesRecursiveExcludeDisabled(modDir.path);
    for (var file in iniFiles) {
      if (p.basename(file).toLowerCase() == "rabbitfx.ini") {
        return true;
      }
    }
  } catch (_) {}
  return false;
}

Future<String> getModName(Directory modDir) async {
  try {
    final fileGroupName = File(p.join(modDir.path, 'modname'));

    if (await fileGroupName.exists()) {
      return await forceReadAsStringUtf8(fileGroupName);
    } else {
      final folderName = p.basename(modDir.path);
      await fileGroupName.writeAsString(folderName);

      return folderName;
    }
  } catch (_) {
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
  } catch (_) {}
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
      } catch (_) {
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

//public method called from button
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
              if (j != 0 &&
                  !p
                      .basename(modFullPaths[j].modDir.path)
                      .toLowerCase()
                      .startsWith('disabled'))
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
  } catch (_) {
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
    SharedPrefUtils().useCustomXXMILib()
        ? 'assets/template_txt/listen_keypress_manager.txt'
        : 'assets/template_txt/listen_keypress_even_on_background.txt',
  );

  // Step 2: Create the .ini file
  final filePath = p.join(managedPath, ConstantVar.backgroundKeypressFileName);
  final iniFile = File(filePath);

  // Step 2: Write content into the .ini file
  try {
    await iniFile.writeAsString(template);
  } catch (_) {
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
  } catch (_) {
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
          } catch (_) {
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
  } catch (_) {
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

    Map<String, List<String>> variablesWithinModNamespace =
        {}; //used for force fix function

    for (var iniFile in iniFiles) {
      await getNamespacedVar(iniFile, variablesWithinModNamespace);
    }

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
          variablesWithinModNamespace,
        );
      }());
    }

    // Wait for all the tasks to complete concurrently
    await Future.wait(futures);

    await cleanDuplicatedVarManagedSlotIdInNamespacedMod(iniFiles);

    await tryMarkAsForcedToBeManaged(modFolder, iniFiles);
    await tryMarkAsUnoptimized(modFolder, iniFiles);
    await tryMarkAsNamespaced(modFolder, iniFiles);
  } catch (_) {
    operationLogs.add(
      TextSpan(
        text:
            '${'Error in managing mod!'.tr()} ${ConstantVar.defaultErrorInfo}\n\n',
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

Future<void> cleanDuplicatedVarManagedSlotIdInNamespacedMod(
  List<String> iniFiles,
) async {
  List<String> namespaceThatHaveSlotId = [];

  for (var iniFilePath in iniFiles) {
    bool fileWasModified = false;
    try {
      //read ini files as lines
      final file = File(iniFilePath);
      final lines = await forceReadAsLinesUtf8(file);
      //parse it per section
      final parsedIni = await _parseIniSections(lines);

      String? namespaceLowerCase;

      for (var i = 0; i < parsedIni.length; i++) {
        if (parsedIni[i].name == "__global__") {
          for (var line in parsedIni[i].lines) {
            //check for namespace definition
            if (line
                .trim()
                .toLowerCase()
                .replaceAll(' ', '')
                .startsWith("namespace=")) {
              final parts = line.split('=');
              if (parts.length >= 2) {
                final afterEquals = parts.sublist(1).join('=').trim();
                namespaceLowerCase = afterEquals.trim().toLowerCase();
                break;
              }
            }
          }
        }

        if (namespaceLowerCase != null &&
            parsedIni[i].name.trim().toLowerCase() == "constants") {
          parsedIni[i].lines.removeWhere((line) {
            final normalized = line.trim().toLowerCase().replaceAll(' ', '');
            final isManagedSlot = normalized.startsWith(
              "global\$managed_slot_id",
            );

            if (isManagedSlot) {
              // if we already encountered this namespace before, delete it
              if (namespaceThatHaveSlotId.contains(namespaceLowerCase)) {
                fileWasModified = true;
                return true; // remove this line
              }
              // first occurrence, keep it but record the namespace
              namespaceThatHaveSlotId.add(namespaceLowerCase!);
            }

            return false; // keep this line
          });
        }
      }

      // Write the modified content back to the INI file
      if (fileWasModified) {
        String modifiedIni = _getLiteralIni(parsedIni);
        await safeWriteIni(file, modifiedIni);
      }
    } catch (_) {}
  }
}

Future<void> _modifyIniFile(
  String iniFilePath,
  String groupFolderName,
  int modIndex,
  int groupIndex,
  List<TextSpan> operationLogs,
  Map<String, List<String>> variablesWithinModNamespace,
) async {
  try {
    // Open the INI file and read it asynchronously
    final file = File(iniFilePath);
    final lines = await forceReadAsLinesUtf8(file);

    // Give nrmm mark
    bool hasNRMM = lines.any(
      (line) => line.toLowerCase().contains("@aglgl on discord"),
    );
    if (!hasNRMM) {
      lines.insert(
        0,
        "; Mod managed with No Reload Mod Manager (NRMM) by Agulag, for any problems, just contact/tag @aglgl on Discord.\n; Source of No Reload Mod Manager https://gamebanana.com/mods/582623\n",
      );
    }

    //Rewrite old/previous info
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith(';')) {
        lines[i] = lines[i].replaceFirst(
          'tell mod creator to fix their broken mod. Mod creator, not mod manager creator.',
          'to prevent overlapped mods.',
        );
      }
    }

    // Parse the INI file sections
    var parsedIni = await _parseIniSections(lines);

    // Modify the INI file sections based on the given modIndex and groupIndex
    _checkAndModifySections(parsedIni, modIndex, groupIndex);

    bool forcedFix = forceFixIniSections(
      parsedIni,
      variablesWithinModNamespace,
    );

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

    //move endif for mod manager to bottom, make sure any lines is inside if-endif mod manager scope
    _moveEndifToCorrectPlace(parsedIni);

    // Write the modified content back to the INI file
    String modifiedIni = _getLiteralIni(parsedIni);
    await safeWriteIni(file, modifiedIni);
  } catch (_) {
    operationLogs.add(
      TextSpan(
        text:
            '${'Error! Cannot modify .ini file'.tr(args: [iniFilePath])}.\n${ConstantVar.defaultErrorInfo}\n\n',
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

Future<File?> safeWriteIni(
  File file,
  String content, {
  bool immediatelyRename = true,
}) async {
  final tempFile = File('${file.path}.tmp');

  //Write to temp file first
  try {
    await tempFile.writeAsString(content, flush: true);
  } catch (_) {
    rethrow;
  }

  //stop here if no need rename, return the temp file
  //currently, only used for change namespace, where if only 1 file cannot be modified, cancel every other files modification too.
  if (!immediatelyRename) {
    return tempFile;
  }

  //Replace original with temp
  try {
    await tempFile.rename(file.path);
  } catch (_) {
    //Don't forget to delete tmp if fail rename
    try {
      await tempFile.delete();
    } catch (_) {}
    rethrow;
  }

  return null;
}

Future<bool> containsNrmmMark(List<String> paths) async {
  for (final path in paths) {
    final file = File(path);

    if (!file.existsSync()) continue;

    final lines = file
        .openRead()
        .transform(SystemEncoding().decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        if (line.contains('by NRMM,')) {
          return true;
        }
      }
    } catch (_) {
      // Skip unreadable files
      continue;
    }
  }
  return false;
}

Future<void> tryMarkAsForcedToBeManaged(
  String modPath,
  List<String> iniFiles,
) async {
  bool found = await containsNrmmMark(iniFiles);

  if (found) {
    try {
      final fileMarkForced = File(p.join(modPath, 'modforced'));

      await fileMarkForced.writeAsString('');
    } catch (_) {}
  } else {
    try {
      final fileMarkForced = File(p.join(modPath, 'modforced'));

      await fileMarkForced.delete();
    } catch (_) {}
  }
}

Future<bool> containsCheckTextureOverride(List<IniSection> parsedIni) async {
  for (var section in parsedIni) {
    if (section.name.toLowerCase().startsWith('shaderregex')) {
      for (var line in section.lines) {
        if (line.trim().startsWith(';')) continue;
        if (line.toLowerCase().contains('checktextureoverride')) {
          return true;
        } else if (line.toLowerCase().replaceAll(' ', '').startsWith('run=')) {
          final match = RegExp(
            r'^\s*run\s*=\s*(\S+)\s*$',
            caseSensitive: false,
          ).firstMatch(line);

          if (match != null) {
            final command = match.group(1); // "CommandListSomething"

            //if CommandList or something found
            if (command != null) {
              //loop again on parsedini sections
              for (var section in parsedIni) {
                //if looping and found section name that is the same as commandlist earlier
                if (section.name.toLowerCase() == command.toLowerCase()) {
                  //loop on every lines on this section
                  for (var line in section.lines) {
                    if (line.trim().startsWith(';')) continue;
                    if (line.toLowerCase().contains('checktextureoverride')) {
                      return true;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  return false;
}

Future<bool> containsNamespace(List<String> iniLines) async {
  for (var line in iniLines) {
    final String trimmedLine = line.trim();
    // only line that's not comment
    if (!trimmedLine.startsWith(';')) {
      //if line starts with [, stop this line loop, namespace won't be located any further down
      if (trimmedLine.startsWith('[')) break;
      //in case found the namespace, not case sensitive, ignore spaces temporarily, check if starts with 'namespaces='
      if (trimmedLine
          .toLowerCase()
          .replaceAll(' ', '')
          .startsWith('namespace=')) {
        //return immediately
        return true;
      }
    }
  }

  return false;
}

Future<void> tryMarkAsUnoptimized(String modPath, List<String> iniFiles) async {
  bool found = false;

  for (var iniFilePath in iniFiles) {
    final file = File(iniFilePath);
    final lines = await forceReadAsLinesUtf8(file);

    var parsedIni = await _parseIniSections(lines);

    found = await containsCheckTextureOverride(parsedIni);
    if (found) break;
  }

  if (found) {
    try {
      final fileMarkUnoptimized = File(p.join(modPath, 'modunoptimized'));

      await fileMarkUnoptimized.writeAsString('');
    } catch (_) {}
  } else {
    try {
      final fileMarkUnoptimized = File(p.join(modPath, 'modunoptimized'));

      await fileMarkUnoptimized.delete();
    } catch (_) {}
  }
}

Future<void> tryMarkAsNamespaced(String modPath, List<String> iniFiles) async {
  bool found = false;

  for (var iniFilePath in iniFiles) {
    final file = File(iniFilePath);
    final lines = await forceReadAsLinesUtf8(file);
    found = await containsNamespace(lines);
    if (found) break;
  }

  if (found) {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modnamespaced'));

      await fileMarkNamespaced.writeAsString('');
    } catch (_) {}
  } else {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modnamespaced'));

      await fileMarkNamespaced.delete();
    } catch (_) {}
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
        //find the "bottom content" position:
        //skip any trailing blank lines or comments
        int insertIndex = section.lines.length; //default: end
        for (int j = section.lines.length - 1; j >= 0; j--) {
          final trimmed = section.lines[j].trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith(';')) {
            insertIndex = j + 1;
            break;
          }
        }

        //insert 'endif' right before trailing comments/blanks
        section.lines.insert(insertIndex, 'match_priority = 0');
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

bool forceFixIniSections(
  List<IniSection> sections,
  Map<String, List<String>> variablesWithinModNamespace,
) {
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
              ';Force fix syntax by NRMM, to prevent overlapped mods.\n;$line\n$modifiedLine';
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
              ';Force fix syntax by NRMM, to prevent overlapped mods.\n;$line\n$modifiedLine';
          forcedFix = true;
          ifStatementWasOpened = true;
        }
      }

      if (line.toLowerCase().trim().startsWith('elif ')) {
        if (!ifStatementWasOpened) {
          String modifiedLine = line.replaceFirst('elif', 'if');
          section.lines[i] =
              ';Force fix syntax by NRMM, to prevent overlapped mods.\n;$line\n$modifiedLine';
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
              ';Force fix syntax by NRMM, to prevent overlapped mods.\n;$line\n$modifiedLine';
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
              ';Force fix syntax by NRMM, to prevent overlapped mods.\n;$line\n$modifiedLine';
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
              ';Force fix syntax by NRMM, to prevent overlapped mods.\n;$line\n$modifiedLine';
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
              ';Force fix syntax by NRMM, to prevent overlapped mods.\n;$line\n$modifiedLine';
          forcedFix = true;
        }
      }
    }
  }

  //add missing variable on Constants
  List<String> variablesFound = [];
  List<String> variablesShouldBeAdded = [];
  String? namespaceLowerCase;

  //First, check for namespace & var definition on constants
  for (var section in sections) {
    if (section.name == "__global__") {
      for (var line in section.lines) {
        //check for namespace definition
        if (line
            .trim()
            .toLowerCase()
            .replaceAll(' ', '')
            .startsWith("namespace=")) {
          final parts = line.split('=');
          if (parts.length >= 2) {
            final afterEquals = parts.sublist(1).join('=').trim();
            namespaceLowerCase = afterEquals.trim().toLowerCase();
            break;
          }
        }
      }
    }

    //check in constant section for already defined vars
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
    //
  }

  //second, check for var that's used on other sections/commandlist sections
  for (var section in sections) {
    if (_isExcludedSection(section.name)) {
      continue;
    }

    //look for var that's defined locally "local ..."
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
    //

    for (var line in section.lines) {
      if (line.trim().startsWith(';')) {
        continue;
      }
      final regex = RegExp(r'(?<!\\)(\$[a-zA-Z_][a-zA-Z0-9_]*)');

      final matches = regex.allMatches(line);
      final results = matches.map((m) => m.group(1)!).toList();
      for (var result in results) {
        //add it as usual, if namespace wasn't defined inside this ini file
        // also check inside namespaced var if any
        List<String>? namespacedVarFound =
            variablesWithinModNamespace[namespaceLowerCase];
        namespacedVarFound ?? (namespacedVarFound = []);

        if (!variablesFound.contains(result.toLowerCase()) &&
            !namespacedVarFound.contains(result.toLowerCase())) {
          //
          if (namespaceLowerCase == null) {
            //add variablesFound as usual if no namespace
            variablesFound.add(result.toLowerCase());
          } else {
            //add to previously passed param/arg if have namespace
            variablesWithinModNamespace[namespaceLowerCase] = [
              ...?variablesWithinModNamespace[namespaceLowerCase],
              result.toLowerCase(),
            ];
          }
          //
          if (!variablesShouldBeAdded.contains(result.toLowerCase()) &&
              !localVariablesFound.contains(result.toLowerCase())) {
            variablesShouldBeAdded.add(result.toLowerCase());
          }
        }
      }
    }
  }

  //third, write undefined vars that were used
  if (variablesShouldBeAdded.isNotEmpty) {
    List<String> lines = [];
    lines.add(';Force add line by NRMM, to prevent overlapped mods.');
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
                    if (line.trim().startsWith(';') &&
                        !line.trim().contains('\n')) {
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
                      ';Force add line by NRMM, to prevent overlapped mods.\n$result = 1',
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

  //look for accidental "elif/else if/else" from "mod manager's if"
  //example:
  //if $managed_slot_id == $\modmanageragl\active_slot
  //something
  //if $anyvar == 1
  //something
  //endif <-- this one must not be written
  //elif $anyvar == 0 <-- this one become elif for 'mod manager if' line because wrong syntax was written in the mod
  for (var section in sections) {
    if (_isExcludedSection(section.name) || _isKeySection(section.name)) {
      continue;
    }
    final lines = section.lines;
    StackCollection<String> ifStatementStack = StackCollection<String>();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().toLowerCase().startsWith('if ')) {
        ifStatementStack.push(line);
        continue;
      }

      if (line.trim().toLowerCase().startsWith('elif ') ||
          line.trim().toLowerCase().startsWith('else if ') ||
          line.trim().toLowerCase() == 'else') {
        String? popIfStatement = ifStatementStack.peek;
        if (popIfStatement != null) {
          if (popIfStatement.toLowerCase().trim().startsWith('if ') &&
              popIfStatement.toLowerCase().trim().contains(
                r'$\modmanageragl',
              )) {
            lines[i] =
                ';Force fix syntax by NRMM, to prevent overlapped mods. Please fix the "if-elif-else-endif" statement manually.\n;$line';
            forcedFix = true;
            continue;
          }
        }
      }

      if (line.trim().toLowerCase() == "endif") {
        ifStatementStack.pop();
        continue;
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
      //find the "bottom content" position:
      //skip any trailing blank lines or comments
      int insertIndex = section.lines.length; //default: end
      for (int j = section.lines.length - 1; j >= 0; j--) {
        final trimmed = section.lines[j].trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith(';')) {
          insertIndex = j + 1;
          break;
        }
      }

      //insert 'endif' right before trailing comments/blanks
      section.lines.insert(
        insertIndex,
        ';Force add line by NRMM, to prevent overlapped mods.\nendif',
      );
      forcedFix = true;
    }
  }

  return forcedFix;
}

Future<void> getNamespacedVar(
  String iniFilePath,
  Map<String, List<String>> variablesWithinModNamespace,
) async {
  try {
    // Open the INI file and read it asynchronously
    final file = File(iniFilePath);
    final lines = await forceReadAsLinesUtf8(file);

    // Parse the INI file sections
    var parsedIni = await _parseIniSections(lines);

    String? namespaceLowerCase;

    //check for namespace & var definition on constants
    for (var section in parsedIni) {
      if (section.name == "__global__") {
        for (var line in section.lines) {
          //check for namespace definition
          if (line
              .trim()
              .toLowerCase()
              .replaceAll(' ', '')
              .startsWith("namespace=")) {
            final parts = line.split('=');
            if (parts.length >= 2) {
              final afterEquals = parts.sublist(1).join('=').trim();
              namespaceLowerCase = afterEquals.trim().toLowerCase();
              break;
            }
          }
        }
      }

      //check in constant section for already defined vars
      if (section.name.toLowerCase().trim() == "constants") {
        for (var line in section.lines) {
          if (line.trim().startsWith(';')) {
            continue;
          }
          final regex = RegExp(r'(?<!\\)(\$[a-zA-Z_][a-zA-Z0-9_]*)');

          final matches = regex.allMatches(line);
          final results = matches.map((m) => m.group(1)!).toList();
          for (var result in results) {
            if (namespaceLowerCase != null) {
              //add to variable passed from previous caller
              variablesWithinModNamespace[namespaceLowerCase] = [
                ...?variablesWithinModNamespace[namespaceLowerCase],
                result.toLowerCase(),
              ];
            }
          }
        }
      }
      //
    }
  } catch (_) {}
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
          //put if statement of mod manager to top line of the section

          final movedLine = lines.removeAt(i);
          lines.insert(0, movedLine);

          //the endif for this mod manager if statement will also be fixed later after forcefix function.
          //make sure the corresponding endif is on bottom
          //on this _moveEndifToCorrectPlace() function
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

        //find the "bottom content" position:
        //skip any trailing blank lines or comments
        int insertIndex = lines.length; //default: end
        for (int j = lines.length - 1; j >= 0; j--) {
          final trimmed = lines[j].trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith(';')) {
            insertIndex = j + 1;
            break;
          }
        }

        //insert 'endif' right before trailing comments/blanks
        lines.insert(insertIndex, 'endif');
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

//Move endif for mod manager if to bottom
void _moveEndifToCorrectPlace(List<IniSection> sections) {
  //will only detect line that starts with 'if ' as valid conditional statement
  //if somehow if statement using invalid condition like 'if $\undeclared_namespace\undeclared_var', this function is useless
  //to properly parse the condition, it needs to check for all ini files, from the root, which is d3dx.ini, look for include and exclude keyword
  //which is currently not implemented

  for (var section in sections) {
    if (_isExcludedSection(section.name) || _isKeySection(section.name)) {
      continue;
    }

    final lines = section.lines;
    StackCollection<String> ifStatementStack = StackCollection<String>();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      //if 'if ' line, push it to the stack
      if (line.trim().toLowerCase().startsWith('if ')) {
        ifStatementStack.push(line);
      }
      //if 'endif' line, try to pop the stack for the matching 'if ' line
      else if (line.trim().toLowerCase() == 'endif') {
        String? popIfStatement = ifStatementStack.pop();

        //if the popped result is not null, means there's still a 'if ' line for this 'endif' line
        //if null means this endif is errored, not used, leave it
        if (popIfStatement != null) {
          //check whether the 'if ' line is 'if ' line from mod manager, if yes, that means this 'endif' line is correspond to that mod manager if statement
          if (popIfStatement.toLowerCase().trim().startsWith('if ') &&
              popIfStatement.toLowerCase().trim().contains(
                r'$\modmanageragl',
              )) {
            //move this endif line to bottom of the section
            //but not bottom in this list, bottom before any blank lines/comments

            //remove it first
            lines.removeAt(i);

            //match priority line or force fix mark that was previous added by mod manager, and make some things look ugly because blindly placed at the bottom
            bool previousLineIsMatchPriority = false;
            bool previousLineIsForceAddEndifMark = false;
            if (lines[i - 1].trim() == "match_priority = 0") {
              lines.removeAt(i - 1);
              previousLineIsMatchPriority = true;
            } else if (lines[i - 1].trim() ==
                ";Force add line by NRMM, to prevent overlapped mods.") {
              lines.removeAt(i - 1);

              previousLineIsForceAddEndifMark = true;
            }

            //find the "bottom content" position:
            //skip any trailing blank lines or comments
            int insertIndex = lines.length; //default: end
            for (int j = lines.length - 1; j >= 0; j--) {
              final trimmed = lines[j].trim();
              if (trimmed.isNotEmpty && !trimmed.startsWith(';')) {
                insertIndex = j + 1;
                break;
              }
            }

            //insert 'endif' right before trailing comments/blanks
            lines.insert(insertIndex, 'endif');

            if (previousLineIsMatchPriority) {
              //still using insertIndex, previous added 'endif' will auto shift to next index
              lines.insert(insertIndex, 'match_priority = 0');
            } else if (previousLineIsForceAddEndifMark) {
              //still using insertIndex, previous added 'endif' will auto shift to next index
              lines.insert(
                insertIndex,
                ';Force add line by NRMM, to prevent overlapped mods.',
              );
            }

            //break this lines loop, already found the endif
            break;
          }
        }
      }
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

    bool lineWasEmpty = false;

    for (var line in section.lines) {
      result.writeln(line);
      lineWasEmpty = line.trim().isEmpty;
    }

    if (!lineWasEmpty) {
      result
          .writeln(); // Blank line between sections, if previous line is not empty or blank line
    }
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

Future<void> openFileExplorerToSpecifiedPath(String path) async {
  if (Platform.isWindows) {
    if (await Directory(path).exists()) {
      try {
        Process.run('explorer', [path]);
      } catch (_) {}
    }
  }
}

Future<bool> completeDisableMod(Directory modDir) async {
  if (p.basename(modDir.path).toLowerCase().startsWith('disabled')) {
    return false;
  }
  try {
    String renamedPath = p.join(
      p.dirname(modDir.path),
      'DISABLED${p.basename(modDir.path)}',
    );
    await modDir.rename(renamedPath);
    return true;
  } catch (_) {
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
  } catch (_) {
    return false;
  }
}
