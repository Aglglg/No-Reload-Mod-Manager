class ModGroupData {
  final String groupPath;
  final String? iconPath;
  final String groupName;
  final List<ModData> modsInGroup;
  final int realIndex;
  final int previousSelectedModOnGroup;

  ModGroupData({
    required this.groupPath,
    required this.iconPath,
    required this.groupName,
    required this.modsInGroup,
    required this.realIndex,
    required this.previousSelectedModOnGroup,
  });
}

class ModData {
  final String modPath;
  final String? iconPath;
  final String modName;
  final int realIndex;
  final bool isOldAutoFixed;
  final bool isSyntaxErrorRemoved;
  final bool isUnoptimized;
  final bool isNamespaced;
  final bool isDisabled;

  ModData({
    required this.modPath,
    required this.iconPath,
    required this.modName,
    required this.realIndex,
    required this.isOldAutoFixed,
    required this.isSyntaxErrorRemoved,
    required this.isUnoptimized,
    required this.isNamespaced,
    required this.isDisabled,
  });
}
