import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';

class ModGroupData {
  final Directory groupDir;
  final Image? groupIcon;
  final String groupName;
  final List<ModData> modsInGroup;
  final int realIndex;
  final int previousSelectedModOnGroup;

  ModGroupData({
    required this.groupDir,
    required this.groupIcon,
    required this.groupName,
    required this.modsInGroup,
    required this.realIndex,
    required this.previousSelectedModOnGroup,
  });
}

class ModData {
  final Directory modDir;
  final Image? modIcon;
  final String modName;
  final int realIndex;
  final bool isOldAutoFixed;
  final bool isSyntaxErrorRemoved;
  final bool isUnoptimized;
  final bool isNamespaced;

  ModData({
    required this.modDir,
    required this.modIcon,
    required this.modName,
    required this.realIndex,
    required this.isOldAutoFixed,
    required this.isSyntaxErrorRemoved,
    required this.isUnoptimized,
    required this.isNamespaced,
  });
}

class PresetData {
  final String presetName;
  final String presetDesc;
  final Map<int, int> groupAndModPairs;

  PresetData({
    required this.presetName,
    required this.presetDesc,
    required this.groupAndModPairs,
  });
}

class TroubleshootData {
  String time;
  TargetGame targetGame;

  ///////////////
  //VISUAL GLITCH
  ///////////////

  //XXMI DLL Version
  String xxmiDllVersion;
  String latestXxmiDll;

  //Mods outside managed groups folder that cause conflict
  //Mods with manager if-endif
  List<String> unmanagedModWithManagerIfPaths;
  //Mods with conflicting hashes, only if there's command list line in that hash override section
  List<String> unmanagedModWithConflictingHashPaths;

  //Mods in different group that have hash conflicts, only if there's commmand list line in that hash override section
  //path, path
  List<(String, String)> acrossGroupConflictPaths;

  //Mods referencing non existent texture
  //Path, texture path
  List<(String, List<String>)> modReferencingNullTexturesKvp;

  //Mod libraries inside managed folder
  List<String> managedLibPaths;

  //Shader dump and shader fixes
  //Paths for shader dump setting
  List<String> shaderDumpConfigPaths;
  //Paths for shader fixes files
  List<String> shaderFixesPaths;

  //Exclude recursive setting, only in d3dx.ini file
  bool missingExcludeDisabled;
  bool missingExcludeDesktop;

  /////////////
  //PERFORMANCE
  /////////////

  //Mods that do checktextureoverride on shaderregex/all shaders
  List<String> modAllShadersTextureOverridePaths;

  //Debug logging config
  List<String> debugLoggingConfigPaths;

  //Shader cache setting
  List<String> shaderCacheConfigPaths;

  ///////
  //OTHER
  ///////

  //Config that say check_foreground_window = 1, except d3dx.ini
  List<String> backgroundKeypressConfigPaths;

  //Too long paths that cannot be handled with c++ MAX_PATH
  List<String> tooLongPaths;

  //D3dx user ini contains invalid line because can't save non English Char
  //only if starts with Mods, if not that means it is custom namespace
  bool d3dxUserFileFound;
  List<String> foldersThatContainsNonEnglishChar;

  TroubleshootData({
    required this.targetGame,
    required this.time,
    //Visual Glitch
    required this.xxmiDllVersion,
    required this.latestXxmiDll,
    required this.unmanagedModWithManagerIfPaths,
    required this.unmanagedModWithConflictingHashPaths,
    required this.acrossGroupConflictPaths,
    required this.modReferencingNullTexturesKvp,
    required this.managedLibPaths,
    required this.shaderDumpConfigPaths,
    required this.shaderFixesPaths,
    required this.missingExcludeDisabled,
    required this.missingExcludeDesktop,
    //Performance Problem
    required this.modAllShadersTextureOverridePaths,
    required this.debugLoggingConfigPaths,
    required this.shaderCacheConfigPaths,
    //Other Problem
    required this.backgroundKeypressConfigPaths,
    required this.tooLongPaths,
    required this.d3dxUserFileFound,
    required this.foldersThatContainsNonEnglishChar,
  });
}
