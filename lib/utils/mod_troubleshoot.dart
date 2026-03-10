import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/force_read_as_utf8.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:path/path.dart' as p;

Future<TroubleshootData> fullScanMods(
  String modsPath,
  TargetGame targetGame,
) async {
  //naive approach, perhaps it's slow

  final troubleshootData = TroubleshootData(
    targetGame: targetGame,
    time: "",
    xxmiDllVersion: "unknown",
    latestXxmiDll: "unknown",
    unmanagedModWithManagerIfPaths: [],
    unmanagedModWithConflictingHashPaths: [],
    acrossGroupConflictPaths: [],
    modReferencingNullTexturesKvp: [],
    managedLibPaths: [],
    shaderDumpConfigPaths: [],
    shaderFixesPaths: [],
    missingExcludeDisabled: false,
    missingExcludeDesktop: false,
    modAllShadersTextureOverridePaths: [],
    debugLoggingConfigPaths: [],
    shaderCacheConfigPaths: [],
    backgroundKeypressConfigPaths: [],
    tooLongPaths: [],
    d3dxUserFileFound: false,
    foldersThatContainsNonEnglishChar: [],
  );

  final now = DateTime.now();
  final timeFormatted =
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
      "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

  troubleshootData.time = timeFormatted;

  //CHECK XXMI DLL VERSION
  try {
    final xxmiVersionsSha256 = await _getXxmiVersionsData();
    final comparedXxmi = await _compareXxmiVersion(
      p.join(p.dirname(modsPath), "d3d11.dll"),
      xxmiVersionsSha256,
    );
    troubleshootData.xxmiDllVersion = comparedXxmi.$1;
    troubleshootData.latestXxmiDll = comparedXxmi.$2;
  } catch (_) {}

  //CHECK MODS OUTSIDE MANAGED GROUP
  final List<String> managedModFolderPaths = [];
  final List<String> allModIniPaths =
      await findIniFilesRecursiveExcludeDisabled(modsPath);
  final List<String> unmanagedModIniPaths = [];

  final groupFullPathsAndIndexes = await getGroupFolders(
    p.join(modsPath, ConstantVar.managedFolderName),
  );

  for (final (groupDir, _) in groupFullPathsAndIndexes) {
    final normalizedDir = Directory(p.normalize(groupDir.path));

    final mods = await getModsOnGroup(normalizedDir, false);

    for (var mod in mods) {
      if (mod.modDir.path != "None") {
        managedModFolderPaths.add(mod.modDir.path);
      }
    }
  }

  bool isInside(String filePath, String folderPath) {
    final relative = p.relative(filePath, from: folderPath);
    return !relative.startsWith('..') && !p.isAbsolute(relative);
  }

  for (final iniPath in allModIniPaths) {
    final normalizedIni = p.normalize(iniPath);

    final insideManaged = managedModFolderPaths.any(
      (folder) => isInside(normalizedIni, folder),
    );

    if (!insideManaged) {
      unmanagedModIniPaths.add(normalizedIni);
    }
  }

  // Look for conflict in ini file that is outside managed group folder
  for (var path in unmanagedModIniPaths) {
    try {
      final rawLines = await forceReadAsLinesUtf8(File(path));
      //get only section, mod manager "if" line, hash line, and command list line (not really accurate but should be sufficient)
      final filteredLines = rawLines.where((rawLine) {
        final trimmedLineLowercase = rawLine.trim().toLowerCase();
        final noSpaces = trimmedLineLowercase.replaceAll(' ', '');

        return noSpaces.contains(
              r"if$managed_slot_id==$\modmanageragl\group_",
            ) ||
            trimmedLineLowercase.startsWith("[") ||
            noSpaces.startsWith('hash=') ||
            _commandListLines.any(
              (cmd) => trimmedLineLowercase.startsWith(cmd),
            );
      });

      //Fill unamanaged mod that contains hold manager if-endif line
      if (filteredLines.any(
        (e) => e
            .trim()
            .toLowerCase()
            .replaceAll(' ', '')
            .contains(r"if$managed_slot_id==$\modmanageragl\group_"),
      )) {
        if (!troubleshootData.unmanagedModWithManagerIfPaths.contains(path)) {
          troubleshootData.unmanagedModWithManagerIfPaths.add(path);
        }
      }

      //Fill unmanaged mod that have same hash as mod in group folder
      if (filteredLines.any(
        (e) => e.trim().toLowerCase().replaceAll(' ', '').startsWith("hash="),
      )) {
        if (!troubleshootData.unmanagedModWithConflictingHashPaths.contains(
          path,
        )) {
          troubleshootData.unmanagedModWithConflictingHashPaths.add(path);
        }
      }
    } catch (_) {}
  }

  for (var path in troubleshootData.unmanagedModWithConflictingHashPaths) {
    //TODO: get hashes in managed group first
    print(path);
  }

  final pathScans = await scanPaths(modsPath);
  for (var pathScan in pathScans.overLimit) {
    print(p.relative(pathScan, from: p.dirname(modsPath)));
  }

  return troubleshootData;
}

// Future<Map<String, String>> _getXxmiVersionsData() async {
//   final response = await http.get(
//     Uri.parse(ConstantVar.urlJsonUpdatedKnownModdingLib),
//   );

//   if (response.statusCode == 200) {
//     final Map<String, dynamic> raw = json.decode(response.body);
//     return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
//   } else {
//     throw Exception();
//   }
// }

Future<Map<String, String>> _getXxmiVersionsData() async {
  final Map<String, dynamic> raw = json.decode(
    await forceReadAsStringUtf8(
      File(
        r"D:\GitHub\test-auto\assets\cloud_data\xxmi_version_data\xxmi_version_data.json",
      ),
    ),
  );
  return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
}

Future<(String, String)> _compareXxmiVersion(
  String dllPath,
  Map<String, String> versionData,
) async {
  String version = "unknown";
  String latest = "unknown";

  final file = File(dllPath);

  String? findKeyByValue(Map<String, String> map, String value) {
    for (final entry in map.entries) {
      if (entry.value == value) return entry.key;
    }
    return null;
  }

  if (await file.exists()) {
    try {
      final digest = await sha256.bind(file.openRead()).first;
      final dllVersion = findKeyByValue(versionData, digest.toString());
      if (dllVersion != null) {
        version = dllVersion;
      }
      if (versionData.isNotEmpty) {
        latest = versionData.keys.last;
      }
    } catch (_) {}
  }

  return (version, latest);
}

//used with .startsWith()
List<String> _commandListLines = [
  "pre ",
  "post ",

  //general commands
  "checktextureoverride",
  "run",
  "preset",
  "exclude_preset",
  "handling",
  "reset_per_frame_limits",
  "clear",
  "analyse_options",
  "dump",
  "special",
  "store",

  //general commands > draw commands
  "draw",
  "drawauto",
  "drawindexed",
  "drawindexedinstanced",
  "drawinstanced",
  "dispatch",
  "drawindexedinstancedindirect",
  "drawinstancedindirect",
  "dispatchindirect",

  //ini params, skip

  //var assignment, skip

  //resource copy directive
  "vs-cb",
  "hs-cb",
  "ds-cb",
  "gs-cb",
  "ps-cb",
  "cs-cb",

  "vs-t",
  "hs-t",
  "ds-t",
  "gs-t",
  "ps-t",
  "cs-t",

  "o0",
  "o1",
  "o2",
  "o3",
  "o4",
  "o5",
  "o6",
  "o7",
  "o8",
  "o9",

  "od",

  "ps-u",
  "cs-u",

  "vb0",
  "vb1",
  "vb2",
  "vb3",
  "vb4",
  "vb5",
  "vb6",
  "vb7",
  "vb8",
  "vb9",

  "ib",

  "so0",
  "so1",
  "so2",
  "so3",
  "so4",
  "so5",
  "so6",
  "so7",
  "so8",
  "so9",

  "resource",

  "this",

  //flow control, not needed
];

//PATH LENGTH CHECK
class PathScanResult {
  final List<String> withinLimit;
  final List<String> overLimit;

  PathScanResult(this.withinLimit, this.overLimit);
}

Future<PathScanResult> scanPaths(String rootPath) async {
  final within = <String>[];
  final over = <String>[];

  final root = Directory(rootPath);
  if (!await root.exists()) {
    return PathScanResult(within, over);
  }

  await for (final entity in root.list(recursive: true, followLinks: false)) {
    final fullPath = entity.path;
    if (fullPath.length > 258) {
      over.add(fullPath);
    } else {
      within.add(fullPath);
    }
  }

  return PathScanResult(within, over);
}
