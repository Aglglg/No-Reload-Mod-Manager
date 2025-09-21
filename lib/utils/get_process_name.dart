import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

String getForegroundWindowProcessName() {
  // Get the foreground window handle
  final hWnd = GetForegroundWindow();
  if (hWnd == 0) return '';

  // Get the process ID
  final processId = malloc<Uint32>();
  final threadId = GetWindowThreadProcessId(hWnd, processId);

  if (threadId == 0) {
    malloc.free(processId);
    return '';
  }

  // Open the process
  final hProcess = OpenProcess(
    PROCESS_QUERY_LIMITED_INFORMATION,
    FALSE,
    processId.value,
  );

  if (hProcess == 0) {
    malloc.free(processId);
    return '';
  }

  try {
    // Get the process name
    final path = wsalloc(MAX_PATH);
    final size = malloc<Uint32>()..value = MAX_PATH;

    final success = QueryFullProcessImageName(hProcess, 0, path, size);

    if (success != 0) {
      final pathString = path.toDartString();
      // Extract just the executable name from the full path
      final executableName = pathString.split('\\').last;
      return executableName;
    }
    return '';
  } finally {
    CloseHandle(hProcess);
    malloc.free(processId);
  }
}
