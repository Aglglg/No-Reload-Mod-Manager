import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// Windows API constant
const int KEYEVENTF_KEYUP = 0x0002;

/// Simulates a key-down event for a given virtual key code.
void simulateKeyDown(int virtualKeyCode) {
  final input = calloc<INPUT>();
  input.ref.type = INPUT_KEYBOARD;
  input.ref.ki
    ..wVk = virtualKeyCode
    ..wScan = 0
    ..dwFlags = 0
    ..time = 0
    ..dwExtraInfo = GetMessageExtraInfo();

  SendInput(1, input, sizeOf<INPUT>());
  calloc.free(input);
}

/// Simulates a key-up event for a given virtual key code.
void simulateKeyUp(int virtualKeyCode) {
  final input = calloc<INPUT>();
  input.ref.type = INPUT_KEYBOARD;
  input.ref.ki
    ..wVk = virtualKeyCode
    ..wScan = 0
    ..dwFlags = KEYEVENTF_KEYUP
    ..time = 0
    ..dwExtraInfo = GetMessageExtraInfo();

  SendInput(1, input, sizeOf<INPUT>());
  calloc.free(input);
}
