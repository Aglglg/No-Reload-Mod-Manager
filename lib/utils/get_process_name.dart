import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

String getForegroundWindowProcessName() {
  if (Platform.isWindows) {
    return _getForegroundWindowProcessNameWindows();
  } else if (Platform.isLinux) {
    return _getForegroundWindowProcessNameLinux();
  } else {
    throw Exception("UNSUPPORTED PLATFORM GET FOREGROUND WINDOW");
  }
}

// WINDOWS
// WINDOWS
// WINDOWS

String _getForegroundWindowProcessNameWindows() {
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

// LINUX, X11 only
// LINUX, X11 only
// LINUX, X11 only

final _x11 = DynamicLibrary.open('libX11.so.6');

final _openDisplay = _x11.lookupFunction<
  Pointer<Void> Function(Pointer<Utf8>),
  Pointer<Void> Function(Pointer<Utf8>)
>('XOpenDisplay');

final _getRootWindow = _x11.lookupFunction<
  UnsignedLong Function(Pointer<Void>),
  int Function(Pointer<Void>)
>('XDefaultRootWindow');

final _getAtom = _x11.lookupFunction<
  UnsignedLong Function(Pointer<Void>, Pointer<Utf8>, Int),
  int Function(Pointer<Void>, Pointer<Utf8>, int)
>('XInternAtom');

final _getWindowProperty = _x11.lookupFunction<
  Int Function(
    Pointer<Void>,
    UnsignedLong,
    UnsignedLong,
    Long,
    Long,
    Int,
    UnsignedLong,
    Pointer<UnsignedLong>,
    Pointer<Int>,
    Pointer<UnsignedLong>,
    Pointer<UnsignedLong>,
    Pointer<Pointer<Uint8>>,
  ),
  int Function(
    Pointer<Void>,
    int,
    int,
    int,
    int,
    int,
    int,
    Pointer<UnsignedLong>,
    Pointer<Int>,
    Pointer<UnsignedLong>,
    Pointer<UnsignedLong>,
    Pointer<Pointer<Uint8>>,
  )
>('XGetWindowProperty');

final _freeX11Memory = _x11
    .lookupFunction<Int Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'XFree',
    );

int _createAtom(String name) {
  final namePointer = name.toNativeUtf8();
  final atom = _getAtom(_display, namePointer, 1);
  malloc.free(namePointer);
  return atom;
}

final _display = _openDisplay(nullptr);
final _rootWindow = _getRootWindow(_display);
final _activeWindowAtom = _createAtom('_NET_ACTIVE_WINDOW');
final _processIdAtom = _createAtom('_NET_WM_PID');

const _typeCardinal = 6; // X11 type id for numbers
const _typeWindow = 33; // X11 type id for window ids

final _pathSeparators = RegExp(r'[\\/]');

String _getForegroundWindowProcessNameLinux() {
  if (_display == nullptr) return '';

  final window = _readNumber(_rootWindow, _activeWindowAtom, _typeWindow);
  if (window == 0) return '';

  final processId = _readNumber(window, _processIdAtom, _typeCardinal);
  if (processId == 0) return '';

  return _getProcessName(processId);
}

/// Reads a single number property from an X11 window. Returns 0 on failure.
int _readNumber(int window, int property, int type) {
  final actualType = calloc<UnsignedLong>();
  final actualFormat = calloc<Int>();
  final itemCount = calloc<UnsignedLong>();
  final bytesLeft = calloc<UnsignedLong>();
  final data = calloc<Pointer<Uint8>>();

  try {
    final status = _getWindowProperty(
      _display,
      window,
      property,
      0,
      1,
      0,
      type,
      actualType,
      actualFormat,
      itemCount,
      bytesLeft,
      data,
    );
    if (status != 0 || itemCount.value == 0) return 0;
    return data.value.cast<UnsignedLong>().value;
  } finally {
    if (data.value != nullptr) _freeX11Memory(data.value.cast());
    calloc.free(actualType);
    calloc.free(actualFormat);
    calloc.free(itemCount);
    calloc.free(bytesLeft);
    calloc.free(data);
  }
}

/// Gets the executable name, e.g. "game.exe" (Wine/Proton).
String _getProcessName(int processId) {
  try {
    // cmdline holds the program path first, then arguments, separated by 0 bytes
    final bytes = File('/proc/$processId/cmdline').readAsBytesSync();
    final end = bytes.indexOf(0);
    final programPath = utf8.decode(
      end == -1 ? bytes : bytes.sublist(0, end),
      allowMalformed: true,
    );
    if (programPath.isNotEmpty) return programPath.split(_pathSeparators).last;

    // Fallback: short name (cut to 15 characters by Linux)
    return File('/proc/$processId/comm').readAsStringSync().trim();
  } catch (_) {
    return '';
  }
}
