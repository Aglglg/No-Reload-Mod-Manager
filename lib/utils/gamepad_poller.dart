import 'dart:async';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:win32_gamepad/win32_gamepad.dart';

class GamepadPoller {
  final _pollingInterval = Duration(milliseconds: 100);
  Timer? _pollingTimer;
  bool _wasComboPressed = false;

  void register(HotkeyGamepad hotkeyGamepad, void Function() onComboPressed) {
    if (hotkeyGamepad == HotkeyGamepad.none) {
      unregister();
      return;
    }
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      bool comboCurrentlyPressed = false;
      final gamepad = Gamepad(0);
      if (gamepad.state.isConnected) {
        final leftThumbPressed = gamepad.state.leftThumb;
        final aPressed = gamepad.state.buttonA;
        final bPressed = gamepad.state.buttonB;
        final rbPressed = gamepad.state.rightShoulder;

        switch (hotkeyGamepad) {
          case HotkeyGamepad.lsA:
            comboCurrentlyPressed = leftThumbPressed && aPressed;
            break;
          case HotkeyGamepad.lsB:
            comboCurrentlyPressed = leftThumbPressed && bPressed;
            break;
          case HotkeyGamepad.lsRb:
            comboCurrentlyPressed = leftThumbPressed && rbPressed;
            break;
          default:
            break;
        }

        if (comboCurrentlyPressed && !_wasComboPressed) {
          onComboPressed(); // Trigger action only once
        }
      }

      _wasComboPressed = comboCurrentlyPressed;
    });
  }

  void unregister() {
    _pollingTimer?.cancel();
  }
}
