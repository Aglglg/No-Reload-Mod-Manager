import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/custom_group_folder_icon.dart';
import 'package:no_reload_mod_manager/utils/get_cloud_data.dart';
import 'package:no_reload_mod_manager/utils/managedfolder_watcher.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';
import 'package:path/path.dart' as p;

Map<String, String> _iconDataWuwa = {};
Map<String, String> _iconDataGenshin = {};
Map<String, String> _iconDataHsr = {};
Map<String, String> _iconDataZzz = {};
Map<String, String> _iconDataEndfield = {};

DateTime? _lastIconDataWuwa;
DateTime? _lastIconDataGenshin;
DateTime? _lastIconDataHsr;
DateTime? _lastIconDataZzz;
DateTime? _lastIconDataEndfield;

bool _shouldFetch(Map<String, String> currentData, DateTime? lastFetchTime) {
  if (currentData.isEmpty) return true;
  if (lastFetchTime == null) return true;

  return DateTime.now().difference(lastFetchTime).inMinutes >= 5;
}

Future<Map<String, String>> fetchGroupIconData(TargetGame targetGame) async {
  try {
    http.Response response;
    switch (targetGame) {
      case TargetGame.Wuthering_Waves:
        if (!_shouldFetch(_iconDataWuwa, _lastIconDataWuwa)) {
          return _iconDataWuwa;
        }

        response = await httpClient.client.get(
          Uri.parse(ConstantVar.urlJsonAutoIconWuwa),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> raw = json.decode(response.body);
          _iconDataWuwa = raw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          _lastIconDataWuwa = DateTime.now();
        }
        return _iconDataWuwa;

      case TargetGame.Genshin_Impact:
        if (!_shouldFetch(_iconDataGenshin, _lastIconDataGenshin)) {
          return _iconDataGenshin;
        }

        response = await httpClient.client.get(
          Uri.parse(ConstantVar.urlJsonAutoIconGenshin),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> raw = json.decode(response.body);
          _iconDataGenshin = raw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          _lastIconDataGenshin = DateTime.now();
        }
        return _iconDataGenshin;

      case TargetGame.Honkai_Star_Rail:
        if (!_shouldFetch(_iconDataHsr, _lastIconDataHsr)) {
          return _iconDataHsr;
        }

        response = await httpClient.client.get(
          Uri.parse(ConstantVar.urlJsonAutoIconHsr),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> raw = json.decode(response.body);
          _iconDataHsr = raw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          _lastIconDataHsr = DateTime.now();
        }
        return _iconDataHsr;

      case TargetGame.Zenless_Zone_Zero:
        if (!_shouldFetch(_iconDataZzz, _lastIconDataZzz)) {
          return _iconDataZzz;
        }

        response = await httpClient.client.get(
          Uri.parse(ConstantVar.urlJsonAutoIconZzz),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> raw = json.decode(response.body);
          _iconDataZzz = raw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          _lastIconDataZzz = DateTime.now();
        }
        return _iconDataZzz;

      case TargetGame.Arknights_Endfield:
        if (!_shouldFetch(_iconDataEndfield, _lastIconDataEndfield)) {
          return _iconDataEndfield;
        }

        response = await httpClient.client.get(
          Uri.parse(ConstantVar.urlJsonAutoIconEndfield),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> raw = json.decode(response.body);
          _iconDataEndfield = raw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          _lastIconDataEndfield = DateTime.now();
        }
        return _iconDataEndfield;

      default:
        return {};
    }
  } catch (_) {
    return {};
  }
}

const int maxIniFiles = 10;

Future<bool> tryGetIcon(String rootPath, TargetGame targetGame) async {
  final iconData = await fetchGroupIconData(targetGame);

  final List<String> iniFilePaths = [];
  final modPaths = await getModsOnGroup(rootPath, true, limit: 10);
  for (var mod in modPaths) {
    final ini = await findIniFilesRecursiveExcludeDisabled(mod.modPath);
    iniFilePaths.addAll(ini);
    if (iniFilePaths.length >= maxIniFiles) break;
  }

  final cancelToken = _CancelToken();

  final results = await Future.wait(
    iniFilePaths.map(
      (path) => _searchAndDownload(path, iconData, rootPath, cancelToken),
    ),
  );

  cancelToken.cancel();

  final success = results.contains(true);
  return success;
}

Future<bool> _searchAndDownload(
  String filePath,
  Map<String, String> iconData,
  String rootPath,
  _CancelToken cancelToken,
) async {
  if (cancelToken.isCancelled) return false;

  try {
    final file = File(filePath);

    final content = await file.readAsString(encoding: utf8);

    if (cancelToken.isCancelled) return false;

    final url = _extractMatchingUrl(content, iconData);

    if (url == null) return false;
    if (cancelToken.isCancelled) return false;

    //only one worker ever fires a download
    if (!cancelToken.tryCancel()) return false;

    final response = await httpClient.client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 1));

    if (response.statusCode != 200) {
      cancelToken
          .release(); //Let another worker attempt to download if previously failed
      return false;
    }

    //Signal cancellation before doing disk I/O so other workers stop
    cancelToken.cancel();

    String? watchedPath = DynamicDirectoryWatcher.watcher?.path;
    DynamicDirectoryWatcher.stop();

    final savePath = p.join(rootPath, 'icon.png');
    await File(savePath).writeAsBytes(response.bodyBytes, flush: true);

    if (watchedPath != null) {
      DynamicDirectoryWatcher.watch(watchedPath);
    }

    if (SharedPrefUtils().isAutoGenerateFolderIcon()) {
      await setFolderIcon(p.dirname(savePath), savePath);
    }

    return true;
  } on TimeoutException {
    cancelToken.release();
    return false;
  } catch (_) {
    cancelToken.release();
    return false;
  }
}

/// Extracts the hash value from lines like hash = xxxx
String? _extractMatchingUrl(String content, Map<String, String> iconData) {
  for (final match in _hashLineRegex.allMatches(content)) {
    final hash = match.group(1)!.trim();
    final url = iconData[hash]; // O(1) lookup
    if (url != null) return url;
  }
  return null;
}

final _hashLineRegex = RegExp(r'^hash\s*=\s*(.+)$', multiLine: true);

class _CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  bool tryCancel() {
    if (_cancelled) return false;
    _cancelled = true;
    return true;
  }

  //Release the lock if the download failed, so another worker can try
  void release() {
    _cancelled = false;
  }
}
