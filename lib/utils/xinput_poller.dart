import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:win32/win32.dart';

class XInputComboDetector {
  final _pollingInterval = Duration(milliseconds: 100);
  Timer? _pollingTimer;
  bool _wasComboPressed = false;

  void register(HotkeyGamepad hotkeyGamepad, void Function() onComboPressed) {
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      final xinputState = calloc<XINPUT_STATE>();
      bool comboCurrentlyPressed = false;

      for (int controller = 0; controller < XUSER_MAX_COUNT; controller++) {
        if (XInputGetState(controller, xinputState) == ERROR_SUCCESS) {
          final gamepad = xinputState.ref.Gamepad;

          final leftThumbPressed =
              (gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) != 0;
          final aPressed = (gamepad.wButtons & XINPUT_GAMEPAD_A) != 0;
          final bPressed = (gamepad.wButtons & XINPUT_GAMEPAD_B) != 0;
          final rbPressed =
              (gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_SHOULDER) != 0;

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
            case HotkeyGamepad.none:
              comboCurrentlyPressed = false;
              unregister();
              break;
          }

          if (comboCurrentlyPressed && !_wasComboPressed) {
            onComboPressed(); // Trigger action only once
          }
        }
      }

      _wasComboPressed = comboCurrentlyPressed;
      calloc.free(xinputState);
    });
  }

  void unregister() {
    _pollingTimer?.cancel();
  }
}
