import 'dart:io';

import 'package:flutter/widgets.dart';

class ModGroupData {
  final Directory groupDir;
  final ImageProvider? groupIcon;
  final String groupName;
  final List<ModData> modsInGroup;
  final int previousSelectedModOnGroup;

  ModGroupData({
    required this.groupDir,
    required this.groupIcon,
    required this.groupName,
    required this.modsInGroup,
    required this.previousSelectedModOnGroup,
  });
}

class ModData {
  final Directory modDir;
  final ImageProvider? modIcon;
  final String modName;

  ModData({required this.modDir, required this.modIcon, required this.modName});
}
