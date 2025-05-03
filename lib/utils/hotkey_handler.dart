import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';

void hotkeyKeyboardChanged(
  HotkeyKeyboard? prevHotkey,
  HotkeyKeyboard currentHotkey,
  Future<void> Function() onHotkeyTrigerred,
) {
  registerHotkeyKeyboard(currentHotkey, onHotkeyTrigerred);
  if (prevHotkey != null) {
    unregisterHotkeyKeyboard(prevHotkey);
  }
}

Future<void> registerHotkeyKeyboard(
  HotkeyKeyboard hotkey,
  Future<void> Function() onHotkeyTrigerred,
) async {
  switch (hotkey) {
    case HotkeyKeyboard.altW:
      await hotKeyManager.register(
        _hotKeyAltW,
        keyDownHandler: (hotKey) {
          onHotkeyTrigerred();
        },
      );
      break;
    case HotkeyKeyboard.altS:
      await hotKeyManager.register(
        _hotKeyAltS,
        keyDownHandler: (hotKey) {
          onHotkeyTrigerred();
        },
      );
      break;
    case HotkeyKeyboard.altA:
      await hotKeyManager.register(
        _hotKeyAltA,
        keyDownHandler: (hotKey) {
          onHotkeyTrigerred();
        },
      );
      break;
    case HotkeyKeyboard.altD:
      await hotKeyManager.register(
        _hotKeyAltD,
        keyDownHandler: (hotKey) {
          onHotkeyTrigerred();
        },
      );
      break;
  }
}

Future<void> unregisterHotkeyKeyboard(HotkeyKeyboard hotkey) async {
  HotKey hotkeyToBeUnregistered = _hotKeyAltW;
  switch (hotkey) {
    case HotkeyKeyboard.altW:
      hotkeyToBeUnregistered = _hotKeyAltW;
      break;
    case HotkeyKeyboard.altS:
      hotkeyToBeUnregistered = _hotKeyAltS;
      break;
    case HotkeyKeyboard.altA:
      hotkeyToBeUnregistered = _hotKeyAltA;
      break;
    case HotkeyKeyboard.altD:
      hotkeyToBeUnregistered = _hotKeyAltD;
      break;
  }
  await hotKeyManager.unregister(hotkeyToBeUnregistered);
}

final HotKey _hotKeyAltW = HotKey(
  key: PhysicalKeyboardKey.keyW,
  modifiers: [HotKeyModifier.alt],
  scope: HotKeyScope.system,
);
final HotKey _hotKeyAltS = HotKey(
  key: PhysicalKeyboardKey.keyS,
  modifiers: [HotKeyModifier.alt],
  scope: HotKeyScope.system,
);
final HotKey _hotKeyAltA = HotKey(
  key: PhysicalKeyboardKey.keyA,
  modifiers: [HotKeyModifier.alt],
  scope: HotKeyScope.system,
);
final HotKey _hotKeyAltD = HotKey(
  key: PhysicalKeyboardKey.keyD,
  modifiers: [HotKeyModifier.alt],
  scope: HotKeyScope.system,
);
