import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/utils/mod_manager.dart';
import 'package:watcher/watcher.dart';

class DynamicDirectoryWatcher {
  static StreamSubscription<WatchEvent>? _subscription;
  static DirectoryWatcher? watcher;
  static WidgetRef? prevRef;
  static Timer? _debounceTimer;

  static void watch(String path, {WidgetRef? ref}) {
    if (watcher?.path == path) return;

    stop();

    if (ref != null) {
      prevRef = ref;
    }

    watcher = DirectoryWatcher(path);
    _subscription = watcher?.events.listen((event) {
      // Reset debounce timer on every event
      _debounceTimer?.cancel();
      _debounceTimer = Timer(Duration(milliseconds: 1000), () {
        print('Debounced refresh triggered');
        if (ref != null) {
          triggerRefresh(ref);
        } else if (prevRef != null) {
          triggerRefresh(prevRef!);
        }
      });
    });

    print('Started watching: $path');
  }

  static void stop() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _subscription = null;
    watcher = null;
    print('Stopped watching');
  }
}
