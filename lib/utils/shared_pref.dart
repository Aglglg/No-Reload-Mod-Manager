import 'dart:io';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefUtils {
  static final SharedPrefUtils _instance = SharedPrefUtils._internal();
  factory SharedPrefUtils() => _instance;

  SharedPreferences? _prefs;

  SharedPrefUtils._internal();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> setHotkeyKeyboard(HotkeyKeyboard value) async {
    await _prefs?.setString(keyHotkeyKeyboard, value.name);
  }

  Future<void> setHotkeyGamepad(HotkeyGamepad value) async {
    await _prefs?.setString(keyHotkeyGamepad, value.name);
  }

  HotkeyKeyboard getHotkeyKeyboard() {
    String? result = _prefs?.getString(keyHotkeyKeyboard);
    if (result == null) {
      return HotkeyKeyboard.altW;
    } else {
      switch (result) {
        case "altW":
          return HotkeyKeyboard.altW;
        case "altS":
          return HotkeyKeyboard.altS;
        case "altA":
          return HotkeyKeyboard.altA;
        case "altD":
          return HotkeyKeyboard.altD;
        default:
          return HotkeyKeyboard.altW;
      }
    }
  }

  HotkeyGamepad getHotkeyGamepad() {
    String? result = _prefs?.getString(keyHotkeyGamepad);
    if (result == null) {
      return HotkeyGamepad.none;
    } else {
      switch (result) {
        case "none":
          return HotkeyGamepad.none;
        case "lsB":
          return HotkeyGamepad.lsB;
        case "lsA":
          return HotkeyGamepad.lsA;
        case "lsRb":
          return HotkeyGamepad.lsRb;
        default:
          return HotkeyGamepad.none;
      }
    }
  }

  Future<void> setWuwaTargetProcess(String targetProcess) async {
    await _prefs?.setString(keyTargetProcessWuwa, targetProcess);
  }

  Future<void> setGenshinTargetProcess(String targetProcess) async {
    await _prefs?.setString(keyTargetProcessGenshin, targetProcess);
  }

  Future<void> setHsrTargetProcess(String targetProcess) async {
    await _prefs?.setString(keyTargetProcessHsr, targetProcess);
  }

  Future<void> setZzzTargetProcess(String targetProcess) async {
    await _prefs?.setString(keyTargetProcessZzz, targetProcess);
  }

  Future<void> setWuwaModsPath(String path) async {
    await _prefs?.setString(keyModsPathWuwa, path);
  }

  Future<void> setGenshinModsPath(String path) async {
    await _prefs?.setString(keyModsPathGenshin, path);
  }

  Future<void> setHsrModsPath(String path) async {
    await _prefs?.setString(keyModsPathHsr, path);
  }

  Future<void> setZzzModsPath(String path) async {
    await _prefs?.setString(keyModsPathZzz, path);
  }

  String getWuwaTargetProcess() {
    String? result = _prefs?.getString(keyTargetProcessWuwa);
    if (result == null || result.isEmpty) {
      result = defaultTargetProcessWuwa;
    }

    return result;
  }

  String getGenshinTargetProcess() {
    String? result = _prefs?.getString(keyTargetProcessGenshin);
    if (result == null || result.isEmpty) {
      result = defaultTargetProcessGenshin;
    }

    return result;
  }

  String getHsrTargetProcess() {
    String? result = _prefs?.getString(keyTargetProcessHsr);
    if (result == null || result.isEmpty) {
      result = defaultTargetProcessHsr;
    }

    return result;
  }

  String getZzzTargetProcess() {
    String? result = _prefs?.getString(keyTargetProcessZzz);
    if (result == null || result.isEmpty) {
      result = defaultTargetProcessZzz;
    }

    return result;
  }

  String getWuwaModsPath() {
    String? result = _prefs?.getString(keyModsPathWuwa);
    String defaultPath = p.join(
      getUserProfilePath(),
      r'AppData\Roaming\XXMI Launcher\WWMI\Mods',
    );
    if (result == null) {
      if (Directory(defaultPath).existsSync()) {
        result = defaultPath;
      } else {
        result = '';
      }
    }

    return result;
  }

  String getGenshinModsPath() {
    String? result = _prefs?.getString(keyModsPathGenshin);
    String defaultPath = p.join(
      getUserProfilePath(),
      r'AppData\Roaming\XXMI Launcher\GIMI\Mods',
    );
    if (result == null) {
      if (Directory(defaultPath).existsSync()) {
        result = defaultPath;
      } else {
        result = '';
      }
    }

    return result;
  }

  String getHsrModsPath() {
    String? result = _prefs?.getString(keyModsPathHsr);
    String defaultPath = p.join(
      getUserProfilePath(),
      r'AppData\Roaming\XXMI Launcher\SRMI\Mods',
    );
    if (result == null) {
      if (Directory(defaultPath).existsSync()) {
        result = defaultPath;
      } else {
        result = '';
      }
    }

    return result;
  }

  String getZzzModsPath() {
    String? result = _prefs?.getString(keyModsPathZzz);
    String defaultPath = p.join(
      getUserProfilePath(),
      r'AppData\Roaming\XXMI Launcher\ZZMI\Mods',
    );
    if (result == null) {
      if (Directory(defaultPath).existsSync()) {
        result = defaultPath;
      } else {
        result = '';
      }
    }

    return result;
  }

  static const String keyTargetProcessWuwa = 'targetProcessWuwa';
  static const String keyTargetProcessGenshin = 'targetProcessGenshin';
  static const String keyTargetProcessHsr = 'targetProcessHsr';
  static const String keyTargetProcessZzz = 'targetProcessZzz';

  static const String keyModsPathWuwa = 'modsPathWuwa';
  static const String keyModsPathGenshin = 'modsPathGenshin';
  static const String keyModsPathHsr = 'modsPathHsr';
  static const String keyModsPathZzz = 'modsPathZzz';

  static const String defaultTargetProcessWuwa = 'Client-Win64-Shipping.exe';
  static const String defaultTargetProcessGenshin = 'GenshinImpact.exe';
  static const String defaultTargetProcessHsr = 'StarRail.exe';
  static const String defaultTargetProcessZzz = 'ZenlessZoneZero.exe';

  static const String defaultModsPathWuwa = 'Client-Win64-Shipping.exe';
  static const String defaultModsPathGenshin = 'GenshinImpact.exe';
  static const String defaultModsPathHsr = 'StarRail.exe';
  static const String defaultModsPathZzz = 'ZenlessZoneZero.exe';

  static const String keyHotkeyKeyboard = "hotkeyKeyboard";
  static const String keyHotkeyGamepad = "hotkeyGamepad";

  String getUserProfilePath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return userProfile;
      }
    }
    return '';
  }

  // Remove key
  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  // Clear all
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
