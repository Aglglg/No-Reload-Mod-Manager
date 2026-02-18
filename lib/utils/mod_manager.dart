import 'dart:io';
import 'dart:isolate';
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
import 'package:no_reload_mod_manager/utils/ini_handler_bridge.dart';
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

//////////////////////////

Future<List<(Directory, int)>> getGroupFolders(
  String modsPath, {
  bool shouldThrowOnError = false,
}) async {
  final directory = Directory(modsPath);
  final List<(Directory, int)> matchingFolders = [];
  final regexp = RegExp(
    r'^group_([1-9]|[1-9][0-9]|[1-4][0-9]{2}|500)$',
    caseSensitive: true,
  );

  try {
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          final match = regexp.firstMatch(folderName);

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
        isOldAutoFixed: false,
        isSyntaxErrorRemoved: false,
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
                    isOldAutoFixed: mod.isOldAutoFixed,
                    isSyntaxErrorRemoved: mod.isSyntaxErrorRemoved,
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
          isOldAutoFixed: await checkModWasMarkedAsOldAutoFixed(modDir),
          isSyntaxErrorRemoved: await checkModSyntaxErrorRemoved(modDir),
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
        isOldAutoFixed: false,
        isSyntaxErrorRemoved: false,
        isUnoptimized: false,
        isNamespaced: false,
      ),
    );

    return modDatas;
  } catch (_) {
    return [];
  }
}

Future<bool> checkModWasMarkedAsOldAutoFixed(Directory modDir) async {
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

Future<bool> checkModSyntaxErrorRemoved(Directory modDir) async {
  try {
    final fileForcedName = File(p.join(modDir.path, 'modsyntaxerrorremoved'));
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
  String targetGame,
  Map<String, String> knownModdingLibraries,
) async {
  List<TextSpan> operationLogs = [];
  setBoolIfNeedAutoReload(true);
  bool needReloadManual = false;

  final basePath = p.dirname(modsPath);
  final d3dxIni = p.join(basePath, "d3dx.ini");

  ErroredLinesReport errorReport;

  Ref<bool> errorShouldTryAgain = Ref(false);

  try {
    //Prepare _MANAGED_ folder first, make sure it's there or old managed folder to be new _MANAGED_ folder
    //And also create some ini files from template
    final (String, bool) preparing = await _prepareManagedFolder(
      modsPath,
      operationLogs,
      errorShouldTryAgain,
      targetGame,
    );

    final managedPath = preparing.$1;
    needReloadManual = preparing.$2;

    //Get all mods for each group directly and once
    final groupFullPathsAndIndexes = await getGroupFolders(
      managedPath,
      shouldThrowOnError: true,
    );

    final Map<(Directory, int), List<ModData>> groupAndModsPair = {};

    for (final (groupDir, groupIndex) in groupFullPathsAndIndexes) {
      final normalizedDir = Directory(p.normalize(groupDir.path));
      final key = (normalizedDir, groupIndex);

      final mods = await getModsOnGroup(normalizedDir, false);

      groupAndModsPair[key] = mods;
    }

    //Fix duplicated namespaces first, if any
    await _autoModifyDuplicateNamespaceInManagedMod(
      groupAndModsPair,
      managedPath,
    );

    //Get errored lines from xxmi ini handler
    errorReport = await Isolate.run(() {
      return getErroredLines(d3dxIni, basePath, knownModdingLibraries);
    });

    //Show duplicate known libs, libDisplayName <> files of the lib
    for (var entry in errorReport.duplicateLibs.entries) {
      final libName = entry.key;
      final filePaths = entry.value
          .map((e) {
            return p.relative(e, from: p.dirname(basePath));
          })
          .toList()
          .join('\n');

      operationLogs.add(
        TextSpan(
          text: "Duplicate modding library".tr(args: [libName, filePaths]),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontSize: 14,
          ),
        ),
      );
      operationLogs.add(
        TextSpan(
          text: "Keep only one copy of modding library".tr(args: [libName]),
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    //Show non existent lib, libDisplayName <> first mod that use it
    for (var entry in errorReport.nonExistentLibs.entries) {
      final libName = entry.key;
      final filePath = entry.value;

      if (!p.isWithin(managedPath, filePath)) continue;

      final (groupName, modName, relativePath) = await _resolveGroupAndModName(
        filePath,
        managedPath,
      );

      operationLogs.add(
        TextSpan(
          text: "Missing modding library".tr(
            args: [
              libName,
              groupName != null && modName != null
                  ? "$groupName - $modName"
                  : p.relative(filePath, from: managedPath),
            ],
          ),
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontSize: 14,
          ),
        ),
      );
    }

    //Fix any crash line that's not in _MANAGED_ folder, if any
    await _fixNonManagedModsCrashLine(errorReport, managedPath);

    await Future.wait([
      for (final entry in groupAndModsPair.entries)
        () async {
          final (groupDir, groupIndex) = entry.key;
          final modDatas = entry.value;

          await _deleteGroupIniFiles(
            groupDir.path,
            operationLogs,
            errorShouldTryAgain,
          );
          await _createGroupIni(
            groupDir.path,
            groupIndex,
            operationLogs,
            errorShouldTryAgain,
          );

          // for (var mod in modDatas) {
          //   if (mod.modIcon == null) {
          //     await _tryAutoGetModIcon(mod.modDir);
          //   }
          // }

          await Future.wait([
            for (var j = 0; j < modDatas.length; j++)
              if (j != 0 &&
                  !p
                      .basename(modDatas[j].modDir.path)
                      .toLowerCase()
                      .startsWith('disabled'))
                _manageMod(
                  modDatas[j].modDir.path,
                  'group_$groupIndex',
                  j,
                  groupIndex,
                  operationLogs,
                  errorReport,
                  errorShouldTryAgain,
                ),
          ]);
        }(),
    ]);

    operationLogs.add(
      !errorShouldTryAgain.value
          ? TextSpan(
            text: 'Mods successfully managed!'.tr(),
            style: GoogleFonts.poppins(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
  } on NamespaceRewriteException catch (e) {
    operationLogs.clear();
    operationLogs.add(
      TextSpan(
        text:
            "${'Duplicate namespace that cannot be automatically fixed'.tr(args: [e.groupName.toString(), e.modName])}${ConstantVar.defaultErrorInfo}",
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  } on IniHandlerException catch (_) {
    operationLogs.clear();
    operationLogs.add(
      TextSpan(
        text:
            'Failed to call function to detect errored lines, if issue persist please contact NRMM creator.'
                .tr(),
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  } catch (_) {
    operationLogs.clear();
    operationLogs.add(
      TextSpan(
        text: "${'Unexpected error!'.tr()} ${ConstantVar.defaultErrorInfo}",
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }

  return operationLogs;
}

Future<(String? groupName, String? modName, String relativePath)>
_resolveGroupAndModName(String iniPath, String managedPath) async {
  Directory? current = File(iniPath).parent;

  Directory? modRoot;
  Directory? groupRoot;

  while (current != null && p.isWithin(managedPath, current.path)) {
    final modNameFile = File(p.join(current.path, 'modname'));
    if (modRoot == null && await modNameFile.exists()) {
      modRoot = current;
    }

    final groupNameFile = File(p.join(current.path, 'groupname'));
    if (modRoot != null && await groupNameFile.exists()) {
      groupRoot = current;
      break;
    }

    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }

  String? modName;
  String? groupName;

  if (modRoot != null) {
    try {
      modName = await File(
        p.join(modRoot.path, 'modname'),
      ).readAsString().then((s) => s.trim());
    } catch (_) {}
  }

  if (groupRoot != null) {
    try {
      groupName = await File(
        p.join(groupRoot.path, 'groupname'),
      ).readAsString().then((s) => s.trim());
    } catch (_) {}
  }

  final relativePath =
      modRoot != null
          ? p.relative(iniPath, from: modRoot.path)
          : p.relative(iniPath, from: managedPath);

  return (groupName, modName, relativePath);
}

Future<void> _fixNonManagedModsCrashLine(
  ErroredLinesReport errorReport,
  String managedPath,
) async {
  for (var entry in errorReport.crashLines.entries) {
    final filePath = entry.key;
    final erroredLines = entry.value;
    if (!p.isWithin(managedPath, filePath)) {
      try {
        final lines = await forceReadAsLinesUtf8(File(filePath));

        for (var erroredLine in erroredLines) {
          final idx = erroredLine.lineIndex;
          if (idx < 0 || idx >= lines.length) continue;

          if (lines[idx].trim().toLowerCase() ==
                  erroredLine.trimmedLine.toLowerCase() &&
              !lines[idx].trim().startsWith(";-;")) {
            lines[idx] = ";-;${lines[idx].trim()}";
          }
        }
        await safeWriteIni(File(filePath), lines.join('\n'));
      } catch (_) {}
    }
  }
}

Future<(String, bool)> _prepareManagedFolder(
  String modsPath,
  List<TextSpan> operationLogs,
  Ref<bool> errorShouldTryAgain,
  String targetGame,
) async {
  final managedPath = p.join(modsPath, ConstantVar.managedFolderName);
  bool needReloadManual = false;

  //Try to rename old managed folder if managed folder not exist yet (V1 Legacy)
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

  await _createBackgroundKeypressIni(
    managedPath,
    operationLogs,
    errorShouldTryAgain,
    targetGame,
  );
  await _createManagerGroupIni(managedPath, operationLogs, errorShouldTryAgain);

  return (managedPath, needReloadManual);
}

Future<String> getNamespace(File iniFile) async {
  String namespace = '';
  List<String> lines = [];

  try {
    lines = await forceReadAsLinesUtf8(iniFile);
  } catch (_) {}

  for (var i = 0; i < lines.length; i++) {
    final String trimmedLine = lines[i].trim();
    // only line that's not comment
    if (!trimmedLine.startsWith(';')) {
      //if line starts with [, stop this line loop, namespace won't be located any further down
      if (trimmedLine.startsWith('[')) break;
      //in case found the namespace, not case sensitive, ignore spaces temporarily, check if starts with 'namespaces='
      if (trimmedLine
          .toLowerCase()
          .replaceAll(' ', '')
          .startsWith('namespace=')) {
        //
        namespace = trimmedLine.substring(trimmedLine.indexOf('=') + 1).trim();

        break; //do not look for other lines, already found
      }
    }
  }
  return namespace;
}

Future<bool> replaceNamespace(
  String originalNamespace,
  String modifiedNamespace,
  List<String> iniFilesPath,
) async {
  List<File> backupFiles = [];
  List<File> tmpModifiedFiles = [];

  //#1, CREATE BACKUP
  for (var path in iniFilesPath) {
    try {
      //do not use copy directly because it'll transfer file permission and attribute too
      //and sometimes cause cannot delete .baknamespace file
      backupFiles.add(await _copyIniContentOnlyNamespace(path));
    } catch (_) {
      //in case failed, delete all previous created bak backup and return
      await _deleteTemporaryFiles(backupFiles);
      return false;
    }
  }

  //2#, CREATE TMP FILE
  for (final path in iniFilesPath) {
    final file = File(path);
    if (!await file.exists()) continue;

    try {
      final lines = await forceReadAsLinesUtf8(file);

      final newLines = _generateModifiedLinesNamespace(
        lines,
        originalNamespace,
        modifiedNamespace,
      );
      //if new lines is changed/modified
      if (newLines.$1) {
        //2#, CREATE TMP FILE
        try {
          final tempFile = await safeWriteIni(
            file,
            newLines.$2.join('\n'),
            immediatelyRename: false,
          );

          //If success, add to list tmp file
          if (tempFile != null) {
            tmpModifiedFiles.add(tempFile);
          }
        } catch (_) {
          //if failed to write tmp file, abort everything and delete. return false
          await _deleteTemporaryFiles(backupFiles);
          await _deleteTemporaryFiles(tmpModifiedFiles);
          return false;
        }
      }
    } catch (_) {
      //if failed to read ini file, abort everything and delete. return false
      await _deleteTemporaryFiles(backupFiles);
      await _deleteTemporaryFiles(tmpModifiedFiles);
      return false;
    }
  }

  //#3, Try rename TMP to ini file
  for (var tmpFile in tmpModifiedFiles) {
    try {
      String tmpFilename = p.basename(tmpFile.path);
      String iniFilename = tmpFilename.replaceFirst(
        ".tmp",
        "",
        tmpFilename.length - ".tmp".length,
      );
      String iniFilePath = p.join(p.dirname(tmpFile.path), iniFilename);
      await tmpFile.rename(iniFilePath);
    } catch (_) {
      await _revertToBakFilesNamespace(backupFiles);
      await _deleteTemporaryFiles(backupFiles);
      await _deleteTemporaryFiles(tmpModifiedFiles);
      return false;
    }
  }
  //Return true success if reached here, DON'T forget to delete bakFiles
  await _deleteTemporaryFiles(backupFiles);
  return true;
}

(bool, List<String>) _generateModifiedLinesNamespace(
  List<String> lines,
  String originalNamespace,
  String modifiedNamespace,
) {
  //add \namespace\, because usually namespace accessed like this, to prevent modifying other words that's the same as the namespace, but not actually referencing the namespace
  final regex = RegExp(
    RegExp.escape("\\$originalNamespace\\"),
    caseSensitive: false,
  );

  bool changed = false;
  final newLines =
      lines.map((line) {
        // skip comment
        if (line.trim().startsWith(';')) return line;

        // if starts with "namespace=", replace it manually, do not use regex, because regex, added '\' at beginning and end
        if (line
            .trim()
            .toLowerCase()
            .replaceAll(' ', '')
            .startsWith('namespace=')) {
          String namespace =
              line.trim().substring(line.trim().indexOf('=') + 1).trim();
          //only replace this namespace line, only if it's the same as original namespace, ofc
          if (namespace.toLowerCase() == originalNamespace.toLowerCase()) {
            changed = true;
            return "namespace = $modifiedNamespace";
          } else {
            return line;
          }
        }

        // Replace other, use regex like \originalNamespace\ to minimize wrong target replace
        if (regex.hasMatch(line)) {
          changed = true;
          return line.replaceAll(regex, "\\$modifiedNamespace\\");
        }

        //return original line if not modified
        return line;
      }).toList();

  return (changed, newLines);
}

Future<void> _revertToBakFilesNamespace(List<File> bakFiles) async {
  for (var bakFile in bakFiles) {
    try {
      String bakFilename = p.basename(bakFile.path);
      String iniFilename = bakFilename.replaceFirst(
        ".baknamespace",
        "",
        bakFilename.length - ".baknamespace".length,
      );
      String iniFilePath = p.join(p.dirname(bakFile.path), iniFilename);
      await bakFile.rename(iniFilePath);
    } catch (_) {}
  }
}

Future<void> _deleteTemporaryFiles(List<File> files) async {
  for (var file in files) {
    try {
      await file.delete();
    } catch (_) {}
  }
}

Future<File> _copyIniContentOnlyNamespace(String iniPath) async {
  try {
    String content = await forceReadAsStringUtf8(File(iniPath));
    return await File("$iniPath.baknamespace").writeAsString(content);
  } catch (_) {
    rethrow;
  }
}

class NamespaceRewriteException implements Exception {
  final String groupName;
  final String modName;

  const NamespaceRewriteException({
    required this.groupName,
    required this.modName,
  });

  @override
  String toString() {
    return 'NamespaceRewriteException: '
        'group=$groupName, '
        'mod="$modName"';
  }
}

Future<void> _autoModifyDuplicateNamespaceInManagedMod(
  Map<(Directory, int), List<ModData>> groupAndModsPair,
  String managedPath,
) async {
  final namespacesInManaged = <String>{};

  for (final entry in groupAndModsPair.entries) {
    final namespacesInGroup = <String>{};
    final mods = entry.value;
    final key = entry.key;

    for (final mod in mods) {
      final iniFiles = await findIniFilesRecursiveExcludeDisabled(
        mod.modDir.path,
      );

      // Scan namespaces in this mod
      final namespacesInMod = <String>{};

      for (final path in iniFiles) {
        final ns = await getNamespace(File(path));
        if (ns.isNotEmpty) {
          namespacesInMod.add(ns.toLowerCase());
        }
      }

      // Plan namespace changes
      final plannedChanges = <String, String>{};
      final futureNamespaces = {...namespacesInMod};

      for (final namespace in namespacesInMod) {
        if ((namespacesInGroup.contains(namespace) ||
                namespacesInManaged.contains(namespace)) &&
            //if it's namespace from known modding lib, let xxmi ini handler handle it later
            !ConstantVar.knownModdingLibraries.keys.contains(namespace)) {
          final newNamespace = _getNewNamespace(
            namespace,
            futureNamespaces,
            namespacesInGroup,
            namespacesInManaged,
          );

          plannedChanges[namespace] = newNamespace;
          futureNamespaces
            ..remove(namespace)
            ..add(newNamespace);
        }
      }

      // Apply changes
      for (final entry in plannedChanges.entries) {
        final ok = await replaceNamespace(entry.key, entry.value, iniFiles);

        if (!ok) {
          await _markAsNamespaced(mod.modDir.path, true);
          final (groupName, _, _) = await _resolveGroupAndModName(
            iniFiles[0],
            managedPath,
          );
          throw NamespaceRewriteException(
            groupName: groupName ?? "Group_${key.$2}",
            modName: mod.modName,
          );
        }
      }

      // Commit mod namespaces into group state
      namespacesInGroup.addAll(futureNamespaces);

      await _markAsNamespaced(mod.modDir.path, futureNamespaces.isNotEmpty);
    }

    // Commit group namespaces into global state
    namespacesInManaged.addAll(namespacesInGroup);
  }
}

String _getNewNamespace(
  String base,
  Set<String> namespacesInMod,
  Set<String> namespacesInGroup,
  Set<String> namespacesInManaged,
) {
  final occupied = <String>{
    ...namespacesInMod,
    ...namespacesInGroup,
    ...namespacesInManaged,
  };

  if (!occupied.contains(base)) {
    return base;
  }

  var suffix = 1;
  while (true) {
    final candidate = '${base}_$suffix';
    if (!occupied.contains(candidate)) {
      return candidate;
    }
    suffix++;
  }
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
  Ref<bool> errorShouldTryAgain,
  String targetGame,
) async {
  // Load the .txt template from assets
  final template = await rootBundle.loadString(
    SharedPrefUtils().useCustomXXMILib()
        ? 'assets/template_txt/listen_keypress_manager.txt'
        : 'assets/template_txt/listen_keypress_even_on_background.txt',
  );

  // Create the .ini file
  final filePath = p.join(managedPath, ConstantVar.backgroundKeypressFileName);
  final iniFile = File(filePath);

  // Write content into the .ini file
  try {
    await iniFile.writeAsString(template.replaceAll("{game}", targetGame));
  } catch (_) {
    errorShouldTryAgain.value = true;
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
  Ref<bool> errorShouldTryAgain,
) async {
  // Load the .txt template from assets
  final template = await rootBundle.loadString(
    'assets/template_txt/template_manager_group.txt',
  );

  // Create the .ini file
  final filePath = p.join(managedPath, ConstantVar.managerGroupFileName);
  final iniFile = File(filePath);

  // Write content into the .ini file
  try {
    await iniFile.writeAsString(template);
  } catch (_) {
    errorShouldTryAgain.value = true;
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
  Ref<bool> errorShouldTryAgain,
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
            errorShouldTryAgain.value = true;

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
  Ref<bool> errorShouldTryAgain,
) async {
  //Load the .txt template from assets
  final template = await rootBundle.loadString(
    'assets/template_txt/template_group.txt',
  );

  // Replace placeholders
  final modifiedTemplate = template
      .replaceAll("{x}", "$groupIndex")
      .replaceAll("{group_x}", p.basename(groupFullPath));

  // Create the .ini file
  final filePath = p.join(groupFullPath, 'group_$groupIndex.ini');
  final iniFile = File(filePath);

  // Write content into the .ini file
  try {
    await iniFile.writeAsString(modifiedTemplate);
  } catch (_) {
    errorShouldTryAgain.value = true;
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
  ErroredLinesReport errorReport,
  Ref<bool> errorShouldTryAgain,
) async {
  try {
    // Find all INI files recursively
    final iniFiles = await findIniFilesRecursiveExcludeDisabled(modFolder);
    Ref<bool> oldAutoFix = Ref(false);
    Ref<bool> removedSyntaxError = Ref(false);

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
          errorReport,
          errorShouldTryAgain,
          oldAutoFix,
          removedSyntaxError,
        );
      }());
    }

    // Wait for all the tasks to complete concurrently
    await Future.wait(futures);

    await _markAsOldAutoFix(modFolder, oldAutoFix.value);
    await _markAsRemovedSyntaxError(modFolder, removedSyntaxError.value);
  } catch (_) {
    errorShouldTryAgain.value = true;
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
  ErroredLinesReport errorReport,
  Ref<bool> errorShouldTryAgain,
  Ref<bool> oldAutoFix,
  Ref<bool> removedSyntaxError,
) async {
  try {
    // Open the INI file and read it asynchronously
    final file = File(iniFilePath);
    final lines = await forceReadAsLinesUtf8(file);

    //Modify lines based on error report first before adding or modifying anything
    _modifyLinesBasedOnError(
      lines,
      iniFilePath,
      errorReport,
      removedSyntaxError,
    );

    // Parse the INI file sections
    var parsedIni = await _parseIniSections(lines, oldAutoFix);

    // Modify the INI file sections based on the given modIndex and groupIndex
    _checkAndModifySections(
      parsedIni,
      modIndex,
      groupIndex,
      removedSyntaxError,
    );

    _reorderByIniKeyPriority(parsedIni);

    //Remove manager if line, if inside that block is containing no command list line
    _removeManagerLineWhenUnused(parsedIni);

    _prettyIndentation(parsedIni);

    // Write the modified content back to the INI file
    String modifiedIni = _getLiteralIni(parsedIni);
    await safeWriteIni(file, modifiedIni);
  } catch (_) {
    errorShouldTryAgain.value = true;
    operationLogs.add(
      TextSpan(
        text:
            '${'Error! Cannot modify .ini file'.tr(args: [iniFilePath])}.\n${ConstantVar.defaultErrorInfo}\n\n',
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

void _modifyLinesBasedOnError(
  List<String> lines,
  String path,
  ErroredLinesReport errorReport,
  Ref<bool> removedSyntaxError,
) {
  //Create a Map of index to trimmedLine for quick lookup
  //index, trimmedLine
  final Map<int, String> expectedErrors = {};

  final fileCrashErrors = errorReport.crashLines[p.normalize(path)] ?? [];
  final fileOtherErrors = errorReport.otherError[p.normalize(path)] ?? [];

  for (var e in [...fileCrashErrors, ...fileOtherErrors]) {
    expectedErrors[e.lineIndex] = e.trimmedLine;
  }

  // We need to continue even if expectedErrors is empty to remove old marks.

  //Iterate through every line in the file to sync state
  for (int i = 0; i < lines.length; i++) {
    final currentLine = lines[i];
    final bool isMarked = currentLine.trimLeft().startsWith(';-;');
    final bool shouldBeMarked = expectedErrors.containsKey(i);

    if (shouldBeMarked) {
      //Get the version without the mark to compare content
      String cleanLine =
          isMarked ? currentLine.replaceFirst(';-;', '') : currentLine;

      //Make sure the trimmed content matches the report
      if (cleanLine.trim().toLowerCase() == expectedErrors[i]!.toLowerCase()) {
        //ignore if syntax error is only "endif"
        if (expectedErrors[i]!.toLowerCase() != "endif") {
          removedSyntaxError.value = true;
        }
        //If it's on report, but not marked yet, add mark
        if (!isMarked) {
          lines[i] = ';-;${currentLine.trim()}';
        }
      }
    } else {
      //If a line is marked but NOT in the error report, remove the mark
      if (isMarked) {
        //replaceFirst only takes out the first occurrence of the tag
        lines[i] = currentLine.replaceFirst(';-;', '');
      }
    }
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

Future<void> _markAsOldAutoFix(String modPath, bool mark) async {
  if (mark) {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modforced'));

      if (!await fileMarkNamespaced.exists()) {
        await fileMarkNamespaced.writeAsString('');
      }
    } catch (_) {}
  } else {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modforced'));

      if (await fileMarkNamespaced.exists()) {
        await fileMarkNamespaced.delete();
      }
    } catch (_) {}
  }
}

Future<void> _markAsRemovedSyntaxError(String modPath, bool mark) async {
  if (mark) {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modsyntaxerrorremoved'));

      if (!await fileMarkNamespaced.exists()) {
        await fileMarkNamespaced.writeAsString('');
      }
    } catch (_) {}
  } else {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modsyntaxerrorremoved'));

      if (await fileMarkNamespaced.exists()) {
        await fileMarkNamespaced.delete();
      }
    } catch (_) {}
  }
}

Future<void> _markAsNamespaced(String modPath, bool mark) async {
  if (mark) {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modnamespaced'));

      if (!await fileMarkNamespaced.exists()) {
        await fileMarkNamespaced.writeAsString('');
      }
    } catch (_) {}
  } else {
    try {
      final fileMarkNamespaced = File(p.join(modPath, 'modnamespaced'));

      if (await fileMarkNamespaced.exists()) {
        await fileMarkNamespaced.delete();
      }
    } catch (_) {}
  }
}

class IniSection {
  String name;
  List<String> lines;

  IniSection(this.name, this.lines);
}

//Get last index in section, but not literal last index, because lines can be empty lines or comment lines
int _getLastIndexInSection(List<String> lines) {
  for (int j = lines.length - 1; j >= 0; j--) {
    final line = lines[j];
    final len = line.length;

    int i = 0;
    // Skip leading whitespace without allocating
    while (i < len) {
      final c = line.codeUnitAt(i);
      if (c != 32 && c != 9) break; // space or tab
      i++;
    }

    // Empty line
    if (i >= len) continue;

    // Comment line: starts with ';' BUT NOT ';-;'
    if (line.codeUnitAt(i) == 59) {
      // ';'
      if (i + 2 < len &&
          line.codeUnitAt(i + 1) == 45 && // '-'
          line.codeUnitAt(i + 2) == 59) {
        // ';'
        // ";-;" → treated as content
        return j + 1;
      }
      // Regular comment → skip
      continue;
    }

    // Real content
    return j + 1;
  }

  return lines.length;
}

String getSectionName(String trimmedLine) {
  if (trimmedLine.length == 1) return '';

  final close = trimmedLine.indexOf(']', 1);
  final raw =
      close == -1 ? trimmedLine.substring(1) : trimmedLine.substring(1, close);

  return raw.trim();
}

Future<List<IniSection>> _parseIniSections(
  List<String> allLines,
  Ref<bool> oldAutoFix,
) async {
  final List<IniSection> sections = [];
  IniSection currentSection = IniSection('__preamble__', []);
  sections.add(currentSection);

  for (var rawLine in allLines) {
    String line = rawLine.trim();

    if (line.startsWith('[')) {
      // New section
      String sectionName = getSectionName(line);
      currentSection = IniSection(sectionName, []);
      sections.add(currentSection);
    } else {
      //Add lines to current section
      if (line
          .replaceAll(' ', '')
          .trim()
          .toLowerCase()
          .contains(r"if$managed_slot_id==$\modmanageragl\group_")) {
        //but, do not add manager if line (if$managed_slot_id==$\modmanageragl\group_)
      } else if (_isConstantsSection(currentSection.name) &&
          line
              .toLowerCase()
              .replaceAll(' ', '')
              .contains("\$managed_slot_id=")) {
        //also do not add $managed_slot_id on constants
      } else if (line.startsWith(';Force') && line.contains('by NRMM')) {
        //just add old auto fix mark
        oldAutoFix.value = true;
        currentSection.lines.add(rawLine);
      } else if (currentSection.name == '__preamble__' &&
              line.startsWith(';') &&
              (line.contains('No Reload Mod Manager') ||
                  line.contains('";-;" are errored')) ||
          line.contains("Errored conditional blocks")) {
        //also do not NRMM mark, we'll add it back later
      }
      // keep original line (with comments, etc.)
      else {
        currentSection.lines.add(rawLine);
      }
    }
  }

  // Always add a "Constants" section if needed, for $managed_slot_id var
  bool constantsSectionIsPresent = sections.any(
    (section) => section.name.toLowerCase() == "constants",
  );

  if (!constantsSectionIsPresent) {
    sections.add(IniSection('Constants', []));
  }

  //Its only purpose is to remove warning overlay,
  //Keep in mind that NOT all lines in this section is a commandlist line
  for (var section in sections) {
    //TEXTUREOVERRIDE
    if (section.name.toLowerCase().startsWith('textureoverride')) {
      bool matchKeywordIsPresent = false;
      for (var line in section.lines) {
        if (line.trim().toLowerCase().startsWith('match_priority') ||
            line.trim().toLowerCase().startsWith('match_first_vertex') ||
            line.trim().toLowerCase().startsWith('match_first_index') ||
            line.trim().toLowerCase().startsWith('match_first_instance') ||
            line.trim().toLowerCase().startsWith('match_vertex_count') ||
            line.trim().toLowerCase().startsWith('match_index_count') ||
            line.trim().toLowerCase().startsWith('match_instance_count')) {
          matchKeywordIsPresent = true;
          break;
        }
      }

      if (!matchKeywordIsPresent) {
        //insert right before trailing comments/blanks
        section.lines.insert(
          _getLastIndexInSection(section.lines),
          'match_priority = 0',
        );
      }
    }
    //SHADER OVERRIDE
    else if (section.name.toLowerCase().startsWith('shaderoverride')) {
      bool allowDuplicateKeywordIsPresent = false;
      for (var line in section.lines) {
        if (line.trim().toLowerCase().startsWith('allow_duplicate_hash')) {
          allowDuplicateKeywordIsPresent = true;
          break;
        }
      }

      if (!allowDuplicateKeywordIsPresent) {
        //insert right before trailing comments/blanks
        section.lines.insert(
          _getLastIndexInSection(section.lines),
          'allow_duplicate_hash = true',
        );
      }
    }
  }

  if (sections[0].name == "__preamble__") {
    // Give nrmm mark
    sections[0].lines.insert(
      0,
      "; \";-;\" are errored conditional lines.\n; Errored conditional blocks (if/else/elif/endif) are handled correctly, including namespaced variables.",
    );
  }
  return sections;
}

final List<String> textureOverrideIniKeys = [
  "hash",
  "format",
  "width",
  "height",
  "width_multiply",
  "height_multiply",
  "override_byte_stride",
  "override_vertex_count",
  "uav_byte_stride",
  "iteration",
  "filter_index",
  "expand_region_copy",
  "deny_cpu_read",
  "match_priority",
  "match_type",
  "match_usage",
  "match_bind_flags",
  "match_cpu_access_flags",
  "match_misc_flags",
  "match_byte_width",
  "match_stride",
  "match_mips",
  "match_format",
  "match_width",
  "match_height",
  "match_depth",
  "match_array",
  "match_msaa",
  "match_msaa_quality",
  "match_first_vertex",
  "match_first_index",
  "match_first_instance",
  "match_vertex_count",
  "match_index_count",
  "match_instance_count",
];
final List<String> customShaderIniKeys = [
  "vs",
  "hs",
  "ds",
  "gs",
  "ps",
  "cs",
  "max_executions_per_frame",
  "flags",
  "blend",
  "alpha",
  "mask",
  "blend[0]",
  "blend[1]",
  "blend[2]",
  "blend[3]",
  "blend[4]",
  "blend[5]",
  "blend[6]",
  "blend[7]",
  "alpha[0]",
  "alpha[1]",
  "alpha[2]",
  "alpha[3]",
  "alpha[4]",
  "alpha[5]",
  "alpha[6]",
  "alpha[7]",
  "mask[0]",
  "mask[1]",
  "mask[2]",
  "mask[3]",
  "mask[4]",
  "mask[5]",
  "mask[6]",
  "mask[7]",
  "alpha_to_coverage",
  "sample_mask",
  "blend_factor[0]",
  "blend_factor[1]",
  "blend_factor[2]",
  "blend_factor[3]",
  "blend_state_merge",
  "depth_enable",
  "depth_write_mask",
  "depth_func",
  "stencil_enable",
  "stencil_read_mask",
  "stencil_write_mask",
  "stencil_front",
  "stencil_back",
  "stencil_ref",
  "depth_stencil_state_merge",
  "fill",
  "cull",
  "front",
  "depth_bias",
  "depth_bias_clamp",
  "slope_scaled_depth_bias",
  "depth_clip_enable",
  "scissor_enable",
  "multisample_enable",
  "antialiased_line_enable",
  "rasterizer_state_merge",
  "topology",
  "sampler",
];
final List<String> shaderOverrideIniKeys = [
  "hash",
  "allow_duplicate_hash",
  "depth_filter",
  "partner",
  "model",
  "disable_scissor",
  "filter_index",
];
final List<String> shaderRegexIniKeys = [
  "shader_model",
  "temps",
  "filter_index",
];

bool _isVariableDeclarationLine(
  String rawLine,
  String nextRawLine,
  String nextNextRawLine,
) {
  String normalize(String s) => s.trim().toLowerCase().replaceAll(' ', '');

  final line = normalize(rawLine);
  final nextLine = normalize(nextRawLine);
  final nextNextLine = normalize(nextNextRawLine);

  bool isVarDeclaration(String line) {
    return line.startsWith('global\$') ||
        line.startsWith('globalpersist\$') ||
        line.startsWith('persistglobal\$');
  }

  bool isComment(String line) =>
      line.startsWith(';') && !line.startsWith(';-;');

  //Direct declaration
  if (isVarDeclaration(line)) {
    return true;
  }

  //Empty or comment - next is declaration
  if ((line.isEmpty || isComment(line)) && isVarDeclaration(nextLine)) {
    return true;
  }

  //Empty - comment - declaration
  if (line.isEmpty && isComment(nextLine) && isVarDeclaration(nextNextLine)) {
    return true;
  }

  //Comment - empty - declaration
  if (isComment(line) && nextLine.isEmpty && isVarDeclaration(nextNextLine)) {
    return true;
  }

  return false;
}

/// Called AFTER ini keys REORDERED
void _removeManagerLineWhenUnused(List<IniSection> sections) {
  for (var section in sections) {
    if (_isWhitelistedSection(section.name)) {
      final lines = section.lines;

      List<String> linesAfterIf = [];

      bool foundManagerIfLine = false;
      for (var line in lines) {
        if (line
            .replaceAll(' ', '')
            .trim()
            .toLowerCase()
            .startsWith(r"if$managed_slot_id==$\modmanageragl\group_")) {
          foundManagerIfLine = true;
        }
        if (foundManagerIfLine == true) {
          linesAfterIf.add(line);
        }
      }

      final filteredLines =
          linesAfterIf.where((rawLine) {
            final line = rawLine.trim().toLowerCase();

            if (line.isEmpty) return false;
            if (line.startsWith(';')) return false;

            if (line.startsWith("if ")) return false;
            if (line.startsWith("elif ")) return false;
            if (line.startsWith("else if ")) return false;
            if (line == "else") return false;
            if (line == "endif") return false;

            return true;
          }).toList();

      if (filteredLines.isEmpty) {
        StackCollection<String> ifLines = StackCollection();
        int? indexOfManagerIfLine;
        int? indexOfManagerEndifLine;

        for (var i = 0; i < lines.length; i++) {
          final trimmedLowerCaseLine = lines[i].trim().toLowerCase();

          final bool isIfLine = trimmedLowerCaseLine.startsWith('if ');

          final bool isEndifLine = trimmedLowerCaseLine == "endif";

          if (isIfLine) {
            ifLines.push(trimmedLowerCaseLine);

            if (lines[i]
                .replaceAll(' ', '')
                .trim()
                .toLowerCase()
                .startsWith(r"if$managed_slot_id==$\modmanageragl\group_")) {
              indexOfManagerIfLine = i;
            }
          } else if (isEndifLine) {
            final poppedIf = ifLines.pop();

            if (poppedIf != null &&
                poppedIf
                    .replaceAll(' ', '')
                    .trim()
                    .toLowerCase()
                    .startsWith(
                      r"if$managed_slot_id==$\modmanageragl\group_",
                    )) {
              indexOfManagerEndifLine = i;
            }
          }
        }

        if (indexOfManagerEndifLine != null) {
          lines.removeAt(indexOfManagerEndifLine);
        }
        if (indexOfManagerIfLine != null) {
          lines.removeAt(indexOfManagerIfLine);
        }
      }
    }
  }
}

void _reorderByIniKeyPriority(List<IniSection> sections) {
  for (var section in sections) {
    // Constants section special handling
    if (_isConstantsSection(section.name)) {
      final top = <String>[];
      final rest = <String>[];

      for (int i = 0; i < section.lines.length; i++) {
        final line = section.lines[i];
        final nextLine =
            (i + 1 < section.lines.length) ? section.lines[i + 1] : '';
        final nextNextLine =
            (i + 2 < section.lines.length) ? section.lines[i + 2] : '';

        if (_isVariableDeclarationLine(line, nextLine, nextNextLine)) {
          top.add(line);
        } else {
          rest.add(line);
        }
      }

      section.lines = [...top, ...rest];
      continue;
    }

    //Other command list section
    List<String> priorityKeys = [];

    if (_isTextureOverrideSection(section.name)) {
      priorityKeys = textureOverrideIniKeys;
    } else if (_isCustomShaderSection(section.name)) {
      priorityKeys = customShaderIniKeys;
    } else if (_isShaderOverrideSection(section.name)) {
      priorityKeys = shaderOverrideIniKeys;
    } else if (_isShaderRegexMainSection(section.name)) {
      priorityKeys = shaderRegexIniKeys;
    } else {
      continue;
    }

    final lowerKeys = priorityKeys.map((k) => k.toLowerCase()).toList();
    final lines = section.lines;

    final buckets = List.generate(priorityKeys.length, (_) => <String>[]);
    final rest = <String>[];

    for (final line in lines) {
      final trimmed = line.trimLeft();
      final lower = trimmed.toLowerCase();

      bool matched = false;

      for (int i = 0; i < lowerKeys.length; i++) {
        final key = lowerKeys[i];

        if (!lower.startsWith(key)) continue;

        final restOfLine = lower.substring(key.length);

        // Must be: [whitespace]* '='
        final eqIndex = restOfLine.indexOf('=');
        if (eqIndex == -1) continue;

        if (restOfLine.substring(0, eqIndex).trim().isEmpty) {
          buckets[i].add(line);
          matched = true;
          break;
        }
      }

      if (!matched) {
        rest.add(line);
      }
    }

    section.lines = [for (final bucket in buckets) ...bucket, ...rest];
  }
}

String indent(String trimmedText, int currentIndentation) {
  if (currentIndentation <= 0) return trimmedText;
  return ' ' * currentIndentation + trimmedText;
}

void _prettyIndentation(List<IniSection> sections) {
  for (var section in sections) {
    final lines = section.lines;
    int lastIndexForInsertion = _getLastIndexInSection(section.lines);
    final int spacesPerIndent = 4;
    int currentIndentation = 0;

    for (var i = 0; i < lastIndexForInsertion; i++) {
      final trimmed = lines[i].trim();

      if (trimmed == 'endif') {
        currentIndentation = (currentIndentation - spacesPerIndent).clamp(
          0,
          currentIndentation,
        );
      }

      if (trimmed.startsWith("else if ") ||
          trimmed.startsWith("elif ") ||
          trimmed == "else") {
        lines[i] = indent(
          trimmed,
          (currentIndentation - spacesPerIndent).clamp(0, currentIndentation),
        );
      } else {
        lines[i] = indent(trimmed, currentIndentation);
      }

      if (trimmed.startsWith('if ')) {
        currentIndentation += spacesPerIndent;
      }
    }
  }
}

void _checkAndModifySections(
  List<IniSection> sections,
  int modIndex,
  int groupIndex,
  Ref<bool> removedSyntaxError,
) {
  bool managedSlotIdVarAdded = false;
  for (var section in sections) {
    final name = section.name;
    final lines = section.lines;

    //Whitelisted or commandlist section
    if (_isWhitelistedSection(name)) {
      //Constants section (it's also in whitelisted section)
      if (_isConstantsSection(name) && !managedSlotIdVarAdded) {
        //simply insert $managed_slot_id. Because, at parsing logic, the old $managed_slot_id guaranteed to be removed
        lines.insert(0, 'global \$managed_slot_id = $modIndex');
        managedSlotIdVarAdded = true;
      }

      //simply insert manager if line on index 0. Because, at parsing logic, the old manager if line guaranteed to be removed
      lines.insert(
        0,
        r'if $managed_slot_id == $\modmanageragl\group_' +
            groupIndex.toString() +
            r'\active_slot',
      );

      _fixEndifLineAndTrailingFlowControlLine(section, removedSyntaxError);
    }
    //Key section
    else if (_isKeySection(name)) {
      //look for condition line
      final conditionLineIndex = lines.indexWhere(
        (line) => line
            .trim()
            .toLowerCase()
            .replaceAll(' ', '')
            .startsWith('condition='),
      );

      //if condition line not found, add one
      if (conditionLineIndex == -1) {
        lines.insert(
          0,
          'condition = \$managed_slot_id == \$\\modmanageragl\\group_$groupIndex\\active_slot',
        );
      }
      //if condition line is found, add managed line or modify managed line
      else {
        final conditionLine = lines[conditionLineIndex];

        //if already have managed line, update groupIndex
        if (ConstantVar.managedPattern.hasMatch(conditionLine)) {
          lines[conditionLineIndex] = conditionLine.replaceAllMapped(
            ConstantVar.managedPattern,
            (match) {
              return '${match.group(1)}$groupIndex${match.group(3)}';
            },
          );
        }
        //if not have managed line in condition, add it
        else {
          // Split only once, safe even if RHS is empty
          final parts = conditionLine.split('=');
          final lhs = parts.first.trimRight();
          final rhs = parts.length > 1 ? parts.sublist(1).join('=').trim() : '';

          final managedExpr =
              '\$managed_slot_id == \$\\modmanageragl\\group_$groupIndex\\active_slot';

          if (rhs.isEmpty) {
            // condition =    replace RHS entirely
            lines[conditionLineIndex] = '$lhs = $managedExpr';
          } else {
            // condition = something && managed line
            lines[conditionLineIndex] = '$lhs = $rhs && $managedExpr';
          }
        }
      }
    }
  }
}

///Make sure no "else-elif-else if" for manager if line, because this still could be treated as valid in ini handler
///Make sure "endif" is on bottom
///Modify based on error report can only remove/mark invalid line
///We still need to make sure that the manager if scope is correct here (endif placed on bottom)
void _fixEndifLineAndTrailingFlowControlLine(
  IniSection section,
  Ref<bool> removedSyntaxError,
) {
  int lastIndexForInsertion = _getLastIndexInSection(section.lines);
  int lastContentIndex = lastIndexForInsertion - 1;
  int? indexOfEndifForManagerIf;

  final lines = section.lines;

  StackCollection<String> ifLines = StackCollection();

  //note: "if " and "else if" lines guaranted to have valid expression, error report already handles it
  //it also guaranted to have valid flow control lines
  //but does not guarantee that manager if line scope is covering from top to bottom (endif placed on bottom)
  //also does not guarantee that manager if line does not contain accidental else-elif-else if, if the mod section was previously managed with old version of this mod manager
  //so we fix that here

  for (var i = 0; i < lines.length; i++) {
    final trimmedLowerCaseLine = lines[i].trim().toLowerCase();

    final bool isIfLine =
        trimmedLowerCaseLine.startsWith('if ') &&
        !trimmedLowerCaseLine.startsWith(
          r'if $managed_slot_id == $\modmanageragl\group_',
        );

    final bool isElseOrElifLine =
        trimmedLowerCaseLine.startsWith('else if ') ||
        trimmedLowerCaseLine.startsWith('elif ') ||
        trimmedLowerCaseLine == "else";

    final bool isEndifLine = trimmedLowerCaseLine == "endif";

    //add if line, that's NOT manager if line to stack
    if (isIfLine) {
      ifLines.push(trimmedLowerCaseLine);
    } else if (isElseOrElifLine) {
      final peekIf = ifLines.peek;

      //if the line is "else" or "elif" but no if line, that means this could be accidental else/elif for manager if line
      //remove/comment it out
      //usually happens if mod was managed with old version
      //newly added mod to this version won't have this, handled by error report
      if (peekIf == null) {
        lines[i] = ";-;${lines[i].trim()}";
        removedSyntaxError.value = true;
      }
    }
    //Remove if line from stack if is endif line, close if
    else if (isEndifLine) {
      final poppedIf = ifLines.pop();

      //if poppedIf is null, that means this endif line is missing if line
      //error report should already handled it, but if there's still any,
      //that means this endif line is for manager if line, because we didn't add manager if line to the stack
      if (poppedIf == null) {
        //that means this endif line for manager if line
        if (i == lastContentIndex) {
          indexOfEndifForManagerIf = i;
        }
        //but make sure it's located in the bottom, if not, comment it out
        else {
          lines[i] = ";-;${lines[i].trim()}";
        }
      }
    }
  }

  //if no endif for manager if found, add it
  if (indexOfEndifForManagerIf == null) {
    //but first make sure to check if lastcontentindex is ";-;endif"
    bool lastContentIndexIsCommentedEndif =
        lines[lastContentIndex].trim().startsWith(";-;") &&
        lines[lastContentIndex].replaceFirst(";-;", '').trim().toLowerCase() ==
            "endif";

    if (lastContentIndexIsCommentedEndif) {
      lines[lastContentIndex] = "endif";
    } else {
      lines.insert(lastIndexForInsertion, "endif");
    }
  }
}

bool _isWhitelistedSection(String sectionName) {
  final lower = sectionName.toLowerCase();

  const exact = {
    'present',
    'clearrendertargetview',
    'cleardepthstencilview',
    'clearunorderedaccessviewuint',
    'clearunorderedaccessviewfloat',
    'constants',
  };

  if (exact.contains(lower)) {
    return true;
  }

  const prefixes = [
    'builtincustomshader',
    'customshader',
    'builtincommandlist',
    'commandlist',
    'shaderoverride',
    'textureoverride',
  ];

  for (final p in prefixes) {
    if (lower.startsWith(p)) {
      return true;
    }
  }

  if (lower.startsWith('shaderregex') && !lower.contains('.')) {
    return true;
  }

  return false;
}

bool _isKeySection(String sectionName) {
  final lowerSectionName = sectionName.toLowerCase();
  return lowerSectionName.startsWith("key");
}

bool _isConstantsSection(String sectionName) {
  final lowerSectionName = sectionName.toLowerCase();
  return lowerSectionName == "constants";
}

//Sections that have special keys that's ignored by Command List Parsing
//////////////
bool _isTextureOverrideSection(String sectionName) {
  final lowerSectionName = sectionName.toLowerCase();
  return lowerSectionName.startsWith("textureoverride");
}

bool _isCustomShaderSection(String sectionName) {
  final lowerSectionName = sectionName.toLowerCase();
  return lowerSectionName.startsWith("customshader");
}

bool _isShaderOverrideSection(String sectionName) {
  final lowerSectionName = sectionName.toLowerCase();
  return lowerSectionName.startsWith("shaderoverride");
}

bool _isShaderRegexMainSection(String sectionName) {
  final lowerSectionName = sectionName.toLowerCase();
  return lowerSectionName.startsWith('shaderregex') &&
      !lowerSectionName.contains('.');
}
//////////////

String _getLiteralIni(List<IniSection> sections) {
  final StringBuffer result = StringBuffer();

  for (var section in sections) {
    if (section.name != '__preamble__') {
      result.writeln('[${section.name}]');
    }

    bool needsSeparator = false;

    for (var line in section.lines) {
      result.writeln(line);

      final trimmed = line.trim();

      // Decide whether this line should force a separator after the section
      if (trimmed.isEmpty) {
        needsSeparator = false;
      } else if (trimmed.startsWith(';') && !trimmed.startsWith(';-;')) {
        needsSeparator = false; // pure comment
      } else {
        needsSeparator = true; // real content
      }
    }

    if (needsSeparator) {
      // Blank line between sections only if last line is real content
      result.writeln();
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
      .where((file) => p.basename(file.path).toLowerCase() != "desktop.ini")
      .map((file) => file.path)
      .toList();
}

Future<List<String>> findIniFilesRecursiveExcludeDisabled(
  String mainFolder,
) async {
  final directory = Directory(mainFolder);
  if (!await directory.exists()) return [];

  bool containsDisabledSegment(String path) {
    for (final part in p.split(path)) {
      if (part.toLowerCase().startsWith('disabled')) {
        return true;
      }
    }
    return false;
  }

  return directory
      .list(recursive: true)
      .where((entity) => entity is File)
      .map((entity) => entity.path)
      .where((path) => path.toLowerCase().endsWith('.ini'))
      .where((path) => p.basename(path).toLowerCase() != 'desktop.ini')
      .where(
        (path) => !containsDisabledSegment(p.relative(path, from: mainFolder)),
      )
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
    case TargetGame.Arknights_Endfield:
      return SharedPrefUtils().getEndfieldModsPath();
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

class Ref<T> {
  T value;
  Ref(this.value);
}
