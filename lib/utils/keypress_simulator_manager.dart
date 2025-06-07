import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulate.dart';
import 'package:win32/win32.dart';

void simulateKeyF10() {
  _simulateKeypressOnly(VK_F10);
}

Future<void> simulateKeySelectMod(int realGroupIndex, int realModIndex) async {
  simulateKeyDown(VK_CLEAR);
  await _simulateSelectGroupMod(VK_SPACE, realModIndex, realGroupIndex);
  await _simulateSelectGroupMod(VK_RETURN, realModIndex, realGroupIndex);
  simulateKeyUp(VK_CLEAR);
}

Future<void> _simulateSelectGroupMod(int key, int x, int y) async {
  (int x, int y)? initialCursorPos = getCursorInitialPos();
  SetCursorPos(x, y);

  lockCursor();

  simulateKeyDown(key);

  await Future.delayed(Duration(milliseconds: 50));

  simulateKeyUp(key);
  unlockCursor();

  if (initialCursorPos != null) {
    SetCursorPos(initialCursorPos.$1, initialCursorPos.$2);
  }
}

Future<void> _simulateKeypressOnly(int key) async {
  simulateKeyDown(key);

  await Future.delayed(Duration(milliseconds: 50));

  simulateKeyUp(key);
}

void lockCursor() {
  final point = calloc<POINT>();
  GetCursorPos(point);

  final rect = calloc<RECT>();
  rect.ref.left = point.ref.x;
  rect.ref.top = point.ref.y;
  rect.ref.right = point.ref.x + 1; // 1 pixel wide
  rect.ref.bottom = point.ref.y + 1; // 1 pixel tall

  ClipCursor(rect); // Lock cursor in that tiny rectangle

  calloc.free(point);
  calloc.free(rect);
}

void unlockCursor() {
  ClipCursor(nullptr); // Unlock the cursor
}

(int x, int y)? getCursorInitialPos() {
  final point = calloc<POINT>();

  final result = GetCursorPos(point);

  if (result != 0) {
    final x = point.ref.x;
    final y = point.ref.y;
    calloc.free(point);
    return (x, y);
  } else {
    calloc.free(point);
    return null;
  }
}
