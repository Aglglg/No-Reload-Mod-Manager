import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';
import 'package:path/path.dart' as p;

abstract mixin class ModSearcherListener {
  void onSearched(int groupIndex, int? modIndex);
  // Keep track of all listeners
  static final List<ModSearcherListener> _listeners = [];

  // Add a listener
  static void addListener(ModSearcherListener listener) {
    _listeners.add(listener);
  }

  // Remove a listener
  static void removeListener(ModSearcherListener listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners
  static void notifyListeners(int groupIndex, int? modIndex) {
    for (final listener in _listeners) {
      listener.onSearched(groupIndex, modIndex);
    }
  }
}

void goToSearchResult(WidgetRef ref, String query) {
  List<(String, int, int?)> names = [];

  bool isGroupOnly = ref.read(searchBarMode) == 1;
  bool isModOnly = ref.read(searchBarMode) == 2;
  bool isModOnGroupOnly = ref.read(searchBarMode) == 3;

  List<ModGroupData> modGroupDatas = ref.read(modGroupDataProvider);
  if (!isModOnGroupOnly) {
    for (var i = 0; i < modGroupDatas.length; i++) {
      if (!isModOnly) {
        names.add((modGroupDatas[i].groupName.trim(), i, null));
        names.add((p.basename(modGroupDatas[i].groupDir.path).trim(), i, null));
      }

      if (!isGroupOnly) {
        List<ModData> modDatas = modGroupDatas[i].modsInGroup;
        for (var j = 0; j < modDatas.length; j++) {
          names.add((modDatas[j].modName.trim(), i, j));
          names.add((p.basename(modDatas[j].modDir.path).trim(), i, j));
        }
      }
    }
  } else {
    int currentGroupIndex = ref.read(currentGroupIndexProvider);
    List<ModData> modDatas =
        ref.read(modGroupDataProvider)[currentGroupIndex].modsInGroup;
    for (var i = 0; i < modDatas.length; i++) {
      names.add((modDatas[i].modName.trim(), currentGroupIndex, i));
      names.add((
        p.basename(modDatas[i].modDir.path).trim(),
        currentGroupIndex,
        i,
      ));
    }
  }

  (String, int, int?)? bestMatch = getBestMatch(query, names);

  if (bestMatch != null) {
    ModSearcherListener.notifyListeners(bestMatch.$2, bestMatch.$3);
  }
}

(String, int, int?)? getBestMatch(
  String query,
  List<(String, int, int?)> items,
) {
  query = query.toLowerCase();

  // Rank items
  List<MapEntry<(String, int, int?), int>> ranked =
      items
          .map((item) {
            final lowerItem = item.$1.toLowerCase();
            int score;

            if (lowerItem == query) {
              score = 3; // Exact match
            } else if (lowerItem.startsWith(query)) {
              score = 2; // Starts with
            } else if (lowerItem.contains(query)) {
              score = 1; // Contains
            } else {
              score = 0; // No match
            }

            return MapEntry(item, score);
          })
          .where((entry) => entry.value > 0)
          .toList();

  // Sort by score descending
  ranked.sort((a, b) => b.value.compareTo(a.value));

  return ranked.isNotEmpty ? ranked.first.key : null;
}
