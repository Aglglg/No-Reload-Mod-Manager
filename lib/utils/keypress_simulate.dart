import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void simulateKeyDown(int virtualKeyCode) {
  if (Platform.isWindows) {
    _windowsSendKey(virtualKeyCode, isKeyUp: false);
  } else if (Platform.isLinux) {
    _linuxSendKey(virtualKeyCode, _keyPressed);
  }
}

void simulateKeyUp(int virtualKeyCode) {
  if (Platform.isWindows) {
    _windowsSendKey(virtualKeyCode, isKeyUp: true);
  } else if (Platform.isLinux) {
    _linuxSendKey(virtualKeyCode, _keyReleased);
  }
}

// Windows

// Windows API constant
const int KEYEVENTF_KEYUP = 0x0002;

void _windowsSendKey(int virtualKeyCode, {required bool isKeyUp}) {
  final input = calloc<INPUT>();
  input.ref.type = INPUT_KEYBOARD;
  input.ref.ki
    ..wVk = virtualKeyCode
    ..wScan = 0
    ..dwFlags = isKeyUp ? KEYEVENTF_KEYUP : 0
    ..time = 0
    ..dwExtraInfo = GetMessageExtraInfo();

  SendInput(1, input, sizeOf<INPUT>());
  calloc.free(input);
}

// Linux (uses /dev/uinput)

const int _openWriteOnly = 1;
const int _openNonBlocking = 2048;

const int _eventKey = 1;

const int _uiSetEventBit = 0x40045564;
const int _uiSetKeyBit = 0x40045565;
const int _uiDeviceSetup = 0x405C5503;
const int _uiDeviceCreate = 0x5501;

const int _keyPressed = 1;
const int _keyReleased = 0;

final DynamicLibrary _libc = DynamicLibrary.open('libc.so.6');

final int Function(Pointer<Utf8>, int) _open = _libc.lookupFunction<
  Int32 Function(Pointer<Utf8>, Int32),
  int Function(Pointer<Utf8>, int)
>('open');

final int Function(int, int, int) _ioctlWithNumber = _libc.lookupFunction<
  Int32 Function(Int32, UnsignedLong, VarArgs<(Int32,)>),
  int Function(int, int, int)
>('ioctl');

final int Function(int, int, Pointer<Void>) _ioctlWithPointer = _libc
    .lookupFunction<
      Int32 Function(Int32, UnsignedLong, VarArgs<(Pointer<Void>,)>),
      int Function(int, int, Pointer<Void>)
    >('ioctl');

final int Function(int, Pointer<Void>, int) _write = _libc.lookupFunction<
  IntPtr Function(Int32, Pointer<Void>, IntPtr),
  int Function(int, Pointer<Void>, int)
>('write');

int _keyboardFile = -1;

// One reusable buffer: 2 events x 24 bytes.
// Event 1 = the key. Event 2 = "sync" (all zeros, so we never touch it)
final Pointer<Uint8> _eventBuffer = calloc<Uint8>(48);
final ByteData _eventData = _eventBuffer.asTypedList(48).buffer.asByteData();

/// Creates the virtual keyboard once, the first time it is needed
void linuxCreateKeyboardIfNeeded() {
  if (_keyboardFile != -1) return;

  final path = '/dev/uinput'.toNativeUtf8();
  _keyboardFile = _open(path, _openWriteOnly | _openNonBlocking);
  calloc.free(path);

  if (_keyboardFile < 0) {
    throw Exception('Cannot open /dev/uinput. Check permissions.');
  }

  // Tell Linux this device sends key events, and which keys it has
  _ioctlWithNumber(_keyboardFile, _uiSetEventBit, _eventKey);
  for (final key in _windowsToLinuxKey.values) {
    _ioctlWithNumber(_keyboardFile, _uiSetKeyBit, key);
  }

  // Device info: 8 bytes id, 80 bytes name, 4 bytes ff_effects_max
  final setup = calloc<Uint8>(92);
  final setupData = setup.asTypedList(92).buffer.asByteData();
  setupData.setUint16(0, 0x06, Endian.host); // bus type: virtual
  setupData.setUint16(2, 0x1234, Endian.host); // vendor id
  setupData.setUint16(4, 0x5678, Endian.host); // product id

  final name = 'NRMM Keyboard'.codeUnits;
  for (var i = 0; i < name.length; i++) {
    setup[8 + i] = name[i];
  }

  _ioctlWithPointer(_keyboardFile, _uiDeviceSetup, setup.cast());
  calloc.free(setup);

  _ioctlWithNumber(_keyboardFile, _uiDeviceCreate, 0);

  // Give the desktop a moment to notice the new keyboard
  sleep(const Duration(milliseconds: 100));
}

void _linuxSendKey(int keyCode, int state) {
  int? linuxKeyCode = _windowsToLinuxKey[keyCode];

  if (linuxKeyCode == null) return;

  linuxCreateKeyboardIfNeeded();

  _eventData.setUint16(16, _eventKey, Endian.host); // type
  _eventData.setUint16(18, linuxKeyCode, Endian.host); // code
  _eventData.setInt32(20, state, Endian.host); // 1 = down, 0 = up

  _write(_keyboardFile, _eventBuffer.cast(), 48);
}

// Windows virtual key code to Linux key code
const Map<int, int> _windowsToLinuxKey = {
  // 0x03: 223, // CANCEL (approximate)
  0x08: 14, // BACKSPACE
  0x09: 15, // TAB
  0x0C: 355, // CLEAR
  0x0D: 28, // ENTER
  0x10: 42, // SHIFT (left)
  0x11: 29, // CTRL (left)
  0x12: 56, // ALT (left)
  0x13: 119, // PAUSE
  0x14: 58, // CAPS LOCK
  0x15: 122, // KANA / HANGUL (Hangul chosen)
  0x19: 123, // HANJA / KANJI (Hanja chosen)
  0x1B: 1, // ESCAPE
  0x1C: 92, // CONVERT
  0x1D: 94, // NONCONVERT
  0x20: 57, // SPACE
  0x21: 104, // PAGE UP
  0x22: 109, // PAGE DOWN
  0x23: 107, // END
  0x24: 102, // HOME
  0x25: 105, // LEFT
  0x26: 103, // UP
  0x27: 106, // RIGHT
  0x28: 108, // DOWN
  // 0x29: 353, // SELECT (approximate)
  // 0x2A: 210, // PRINT (approximate)
  0x2C: 99, // PRINT SCREEN
  0x2D: 110, // INSERT
  0x2E: 111, // DELETE
  0x2F: 138, // HELP
  // Numbers 0-9
  0x30: 11, 0x31: 2, 0x32: 3, 0x33: 4, 0x34: 5,
  0x35: 6, 0x36: 7, 0x37: 8, 0x38: 9, 0x39: 10,

  // Letters A-Z
  0x41: 30, 0x42: 48, 0x43: 46, 0x44: 32, 0x45: 18, 0x46: 33, 0x47: 34,
  0x48: 35, 0x49: 23, 0x4A: 36, 0x4B: 37, 0x4C: 38, 0x4D: 50, 0x4E: 49,
  0x4F: 24, 0x50: 25, 0x51: 16, 0x52: 19, 0x53: 31, 0x54: 20, 0x55: 22,
  0x56: 47, 0x57: 17, 0x58: 45, 0x59: 21, 0x5A: 44,

  // Numpad 0-9
  0x60: 82, 0x61: 79, 0x62: 80, 0x63: 81, 0x64: 75,
  0x65: 76, 0x66: 77, 0x67: 71, 0x68: 72, 0x69: 73,

  0x6A: 55, // NUMPAD *
  0x6B: 78, // NUMPAD +
  // 0x6C: 121, // NUMPAD SEPARATOR (approximate)
  0x6D: 74, // NUMPAD -
  0x6E: 83, // NUMPAD .
  0x6F: 98, // NUMPAD /
  // F1-F12
  0x70: 59, 0x71: 60, 0x72: 61, 0x73: 62, 0x74: 63, 0x75: 64,
  0x76: 65, 0x77: 66, 0x78: 67, 0x79: 68, 0x7A: 87, 0x7B: 88,

  // F13-F24
  0x7C: 183, 0x7D: 184, 0x7E: 185, 0x7F: 186, 0x80: 187, 0x81: 188,
  0x82: 189, 0x83: 190, 0x84: 191, 0x85: 192, 0x86: 193, 0x87: 194,

  0x90: 69, // NUM LOCK
  0x91: 70, // SCROLL LOCK
  // Left / right modifiers
  0xA0: 42, // LEFT SHIFT
  0xA1: 54, // RIGHT SHIFT
  0xA2: 29, // LEFT CTRL
  0xA3: 97, // RIGHT CTRL
  0xA4: 56, // LEFT ALT
  0xA5: 100, // RIGHT ALT
  // Symbol keys (US layout)
  0xBA: 39, // ; :
  0xBB: 13, // = +
  0xBC: 51, // , <
  0xBD: 12, // - _
  0xBE: 52, // . >
  0xBF: 53, // / ?
  0xC0: 41, // ` ~
  0xDB: 26, // [ {
  0xDC: 43, // \ |
  0xDD: 27, // ] }
  0xDE: 40, // ' "
  // 0xFA: 207, // PLAY (approximate)
  0xFB: 372, // ZOOM
};
