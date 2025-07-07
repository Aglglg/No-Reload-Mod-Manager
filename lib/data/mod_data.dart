import 'dart:io';

import 'package:flutter/widgets.dart';

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
  final bool isForced;
  final bool isIncludingRabbitFx;
  final bool isUnoptimized;

  ModData({
    required this.modDir,
    required this.modIcon,
    required this.modName,
    required this.realIndex,
    required this.isForced,
    required this.isIncludingRabbitFx,
    required this.isUnoptimized,
  });
}
