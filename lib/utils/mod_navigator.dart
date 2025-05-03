import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xinput_gamepad/xinput_gamepad.dart';

abstract mixin class ModNavigationListener {
  void onKeyEvent(KeyEvent value, Controller? controller);
  // Keep track of all listeners
  static final List<ModNavigationListener> _listeners = [];

  // Add a listener
  static void addListener(ModNavigationListener listener) {
    _listeners.add(listener);
  }

  // Remove a listener
  static void removeListener(ModNavigationListener listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners
  static Future<void> notifyListeners(
    KeyEvent value,
    Controller? controller,
  ) async {
    if (await windowManager.isFocused() && !isTextInputFocused()) {
      for (final listener in _listeners) {
        listener.onKeyEvent(value, controller);
      }
    }
  }
}

bool isTextInputFocused() {
  final focus = FocusManager.instance.primaryFocus;
  BuildContext? context = focus?.context;
  while (context != null) {
    final widget = context.widget;
    if (widget is EditableText) return true;
    context = context.findAncestorStateOfType<State>()?.context;
  }
  return false;
}
