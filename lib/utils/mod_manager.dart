import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:path/path.dart' as p;

Future<List<ModGroupData>> refreshModData(Directory managedDir) async {
  List<Directory> validGroupFolders = await getGroupFolders(managedDir);

  List<ModGroupData> results = await Future.wait(
    validGroupFolders.map((groupDir) async {
      return ModGroupData(
        groupDir,
        await getGroupName(groupDir),
        await getModsOnGroup(groupDir),
      );
    }),
  );

  return results;
}

//////////////////////////

Future<List<Directory>> getGroupFolders(Directory directory) async {
  final List<Directory> matchingFolders = [];

  try {
    // List all contents of the directory (non-recursive)
    final contents = await directory.list().toList();

    for (var entity in contents) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);
        final match = RegExp(
          r'^group_([1-9]|[1-3][0-9]|4[0-8])$',
          caseSensitive: true,
        ).firstMatch(folderName);

        if (match != null) {
          matchingFolders.add(entity);
        }
      }
    }

    return matchingFolders;
  } catch (e) {
    print('Error reading directory: $e');
    return [];
  }
}

Future<String> getGroupName(Directory groupDir) async {
  try {
    final fileGroupName = File(p.join(groupDir.path, 'groupname'));

    if (await fileGroupName.exists()) {
      return await fileGroupName.readAsString();
    } else {
      final folderName = p.basename(groupDir.path);
      await fileGroupName.writeAsString(folderName);

      return folderName;
    }
  } catch (e) {
    final folderName = p.basename(groupDir.path);
    return folderName;
  }
}

Future<void> setGroupName(Directory groupDir, String groupName) async {
  try {
    final fileGroupName = File(p.join(groupDir.path, 'groupname'));

    await fileGroupName.writeAsString(groupName);
  } catch (e) {}
}

//////////////////////////////

Future<List<ModData>> getModsOnGroup(Directory groupDir) async {
  try {
    final List<Directory> modDirs = [];

    // List all contents of the directory (non-recursive)
    final contents = await groupDir.list().toList();

    for (var entity in contents) {
      if (entity is Directory) {
        modDirs.add(entity);
      }
    }

    final List<ModData> modDatas = await Future.wait(
      modDirs.map((modDir) async {
        return ModData(modDir, await getModName(modDir));
      }).toList(),
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
                'Error reverting ${p.basename(folder.path)}.\n${ConstantVar.defaultErrorInfo}\n\n',
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
          ),
        );
      }
    }

    if (iniFilesBackup.isEmpty) {
      operationLogs.add(
        TextSpan(
          text: 'No backup found on ${p.basename(folder.path)}.\nSkipped.\n\n',
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
          text: 'Backup found on ${p.basename(folder.path)}.\n\n',
          style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
        ),
      );
    }
  }

  operationLogs.add(
    containsError
        ? TextSpan(
          text: 'Mods reverted. But there are some errors.',
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 189, 170, 0),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        )
        : TextSpan(
          text: 'Mods reverted!',
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

    final groupFullPathsAndIndexes = await _getGroupFolders(managedPath);

    await Future.wait([
      for (final (groupFullPath, groupIndex) in groupFullPathsAndIndexes)
        () async {
          await _deleteGroupIniFiles(groupFullPath, operationLogs);
          await _createGroupIni(groupFullPath, groupIndex, operationLogs);

          final modFullPaths = await _getModFoldersOnSpecifiedGroup(
            groupFullPath,
          );

          await Future.wait([
            for (var j = 0; j < modFullPaths.length; j++)
              _manageMod(
                modFullPaths[j],
                'group_$groupIndex',
                j + 1,
                groupIndex,
                operationLogs,
              ),
          ]);
        }(),
    ]);
    operationLogs.add(
      operationLogs.isEmpty
          ? TextSpan(
            text: 'Mods successfully managed!',
            style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
          )
          : TextSpan(
            text:
                'Mods managed but with some errors.\nRead error information above and try again.',
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
          text: "\nPlease do manual reload with F10",
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
        text: "Unexpected error! ${ConstantVar.defaultErrorInfo}",
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
            "Error! Cannot create ${ConstantVar.backgroundKeypressFileName}.\n${ConstantVar.defaultErrorInfoAdmin}\n\n",
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
            "Error! Cannot create ${ConstantVar.managerGroupFileName}.\n${ConstantVar.defaultErrorInfoAdmin}\n\n",
        style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
      ),
    );
  }
}

Future<List<(String, int)>> _getGroupFolders(String modsPath) async {
  final List<(String, int)> groupFullPathsAndIndexes = [];
  final directory = Directory(modsPath);

  if (await directory.exists()) {
    await for (final entity in directory.list()) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);
        final match = RegExp(
          r'^group_([1-9]|[1-3][0-9]|4[0-8])$',
          caseSensitive: true,
        ).firstMatch(folderName);

        if (match != null) {
          final groupIndex = int.parse(match.group(1)!);
          final groupFullPath = entity.path;
          groupFullPathsAndIndexes.add((groupFullPath, groupIndex));
        }
      }
    }
  }

  return groupFullPathsAndIndexes;
}

Future<List<String>> _getModFoldersOnSpecifiedGroup(
  String groupFullPath,
) async {
  final List<String> modFullPaths = [];
  final directory = Directory(groupFullPath);

  if (await directory.exists()) {
    await for (final entity in directory.list()) {
      if (entity is Directory) {
        modFullPaths.add(entity.path);
      }
    }
  }

  return modFullPaths;
}

Future<void> _deleteGroupIniFiles(
  String folderPath,
  List<TextSpan> operationLogs,
) async {
  final dir = Directory(folderPath);
  final regex = RegExp(r'^group_(?:[1-9]|[1-3][0-9]|4[0-8])\.ini$');

  if (await dir.exists()) {
    await for (final entity in dir.list()) {
      if (entity is File) {
        final fileName = entity.uri.pathSegments.last;
        if (regex.hasMatch(fileName)) {
          try {
            await entity.delete();
          } catch (e) {
            operationLogs.add(
              TextSpan(
                text:
                    'Error! Cannot delete previous unused group config $fileName.\n${ConstantVar.defaultErrorInfo}\n\n',
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
            "Error! Cannot create group_$groupIndex.ini.\n${ConstantVar.defaultErrorInfo}\n\n",
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
    final iniFiles = await _findIniFilesRecursiveExcludeDisabled(modFolder);

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
        text: 'Error in managing mod! ${ConstantVar.defaultErrorInfo}\n\n',
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

    // Write the modified content back to the INI file
    await file.writeAsString(_getLiteralIni(parsedIni));
  } catch (e) {
    operationLogs.add(
      TextSpan(
        text:
            'Error! Cannot modify .ini file $iniFilePath.\n${ConstantVar.defaultErrorInfo}\n\n',
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

    if (line.startsWith('[') && line.endsWith(']')) {
      // New section
      String sectionName = line.substring(1, line.length - 1).trim();
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
        if (line.toLowerCase().startsWith('match_priority')) {
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

void _checkAndModifySections(
  List<IniSection> sections,
  int modIndex,
  int groupIndex,
) {
  final managedPattern = RegExp(
    r'(\\modmanageragl\\group_)([1-9]|[1-3][0-9]|4[0-8])(\\active_slot)',
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

  if (lowerSection == "constants" ||
      lowerSection.startsWith("resource") ||
      lowerSection.startsWith("key")) {
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

Future<List<String>> _findIniFilesRecursiveExcludeDisabled(
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
