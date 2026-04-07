import 'dart:io';

import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:path/path.dart' as p;

enum ModsPathStatus {
  // Fully invalid
  invalidNotExist,
  invalidNotModsFolder,
  invalidMissingD3dx,
  invalidMissingDll,

  // Valid for Casual Style
  validCasualWithoutKeypress,
  validCasual,

  // for No-Reload
  invalidNoReloadWithoutManagedFolder,
  invalidNoReloadWithoutPrerequisiteFiles,
  invalidNoReloadOutdated,

  valid,
}

extension ModsPathStatusExtension on ModsPathStatus {
  bool get isFullyInvalid => [
    ModsPathStatus.invalidNotExist,
    ModsPathStatus.invalidNotModsFolder,
    ModsPathStatus.invalidMissingD3dx,
    ModsPathStatus.invalidMissingDll,
  ].contains(this);
}

class ModsPathValidator {
  static Future<ModsPathStatus> validate(
    String modsPath,
    bool isCasualStyle,
  ) async {
    modsPath = sanitizePath(modsPath);

    // Folder doesn't exist
    if (!await Directory(modsPath).exists()) {
      return ModsPathStatus.invalidNotExist;
    }

    // Folder name must be "mods"
    if (p.basename(modsPath).toLowerCase() != 'mods') {
      return ModsPathStatus.invalidNotModsFolder;
    }

    // d3dx.ini and d3d11.dll must exist in parent directory
    final parent = p.dirname(modsPath);
    if (!await File(p.join(parent, 'd3dx.ini')).exists()) {
      return ModsPathStatus.invalidMissingD3dx;
    }
    if (!await File(p.join(parent, 'd3d11.dll')).exists()) {
      return ModsPathStatus.invalidMissingDll;
    }

    // Check managed folder exists
    final managedPath = p.join(modsPath, ConstantVar.managedFolderName);
    final hasManagedFolder = await Directory(managedPath).exists();

    late final bool hasManagerIni;
    late final bool hasIncluder;
    late final bool hasKeypress;

    if (hasManagedFolder) {
      hasManagerIni =
          await File(
            p.join(managedPath, ConstantVar.managerGroupFileName),
          ).exists();
      hasIncluder =
          await File(
            p.join(managedPath, ConstantVar.nrmmIncluderFileName),
          ).exists();
      hasKeypress =
          await File(
            p.join(managedPath, ConstantVar.nrmmKeypressFileName),
          ).exists();
    } else {
      hasManagerIni = false;
      hasIncluder = false;
      hasKeypress = false;
    }

    if (isCasualStyle) {
      return (hasKeypress && hasIncluder)
          ? ModsPathStatus.validCasual
          : ModsPathStatus.validCasualWithoutKeypress;
    } else {
      if (!hasManagedFolder) {
        return ModsPathStatus.invalidNoReloadWithoutManagedFolder;
      }
      if (hasManagerIni && hasIncluder && hasKeypress) {
        // Check revision
        final firstLine = await _readFirstLine(
          p.join(managedPath, ConstantVar.managerGroupFileName),
        );
        if (firstLine?.trim() != ";revision_4") {
          return ModsPathStatus.invalidNoReloadOutdated;
        }

        return ModsPathStatus.valid;
      }

      return ModsPathStatus.invalidNoReloadWithoutPrerequisiteFiles;
    }
  }

  static Future<String?> _readFirstLine(String filePath) async {
    try {
      final file = File(filePath);
      final lines = await file.readAsLines();
      return lines.isNotEmpty ? lines.first : null;
    } catch (_) {
      return null;
    }
  }

  static String sanitizePath(String path) {
    // Strip surrounding quotes
    path = path.trim();
    if ((path.startsWith('"') && path.endsWith('"')) ||
        (path.startsWith("'") && path.endsWith("'"))) {
      path = path.substring(1, path.length - 1).trim();
    }

    // Remove invalid path characters (except path separators and colon for drive)
    path = path.replaceAll(RegExp(r'[<>"|?*]'), '');

    // Normalize path separators to platform standard
    path = path.replaceAll('/', p.separator);

    // Remove trailing separator
    if (path.length > 3 && path.endsWith(p.separator)) {
      path = path.substring(0, path.length - 1);
    }

    // Resolve to absolute path if relative
    if (!p.isAbsolute(path)) {
      path = p.absolute(path);
    }

    return path;
  }
}
