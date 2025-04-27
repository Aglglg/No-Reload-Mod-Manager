import 'dart:io';

class ModGroupData {
  Directory groupDir;
  String groupName;
  List<ModData> modsInGroup;

  ModGroupData(this.groupDir, this.groupName, this.modsInGroup);
}

class ModData {
  Directory modDir;
  String modName;

  ModData(this.modDir, this.modName);
}
