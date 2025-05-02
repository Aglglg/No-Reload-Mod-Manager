import 'package:flutter/widgets.dart';

abstract mixin class ModNavigationListener {
  void onKeyEvent(KeyEvent value);
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
  static void notifyListeners(KeyEvent value) {
    for (final listener in _listeners) {
      listener.onKeyEvent(value);
    }
  }
}
