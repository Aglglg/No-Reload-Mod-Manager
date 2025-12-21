import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

class ErroredLinesResult {
  final Pointer<ErroredLineFFI> _ptr;
  final int count;
  bool _isFreed = false;

  ErroredLinesResult(this._ptr, this.count);

  Map<String, dynamic> operator [](int index) {
    if (_isFreed) throw StateError("Memory already released");
    if (index < 0 || index >= count) throw IndexError.withLength(index, count);

    final item = _ptr[index];
    return {
      'lineIndex': item.lineIndex,
      'filePath': item.filePath.toDartString(),
      'trimmedLine': item.trimmedLine.toDartString(),
      'reason': item.reason.toDartString(),
    };
  }

  void dispose() {
    if (!_isFreed && _ptr != nullptr) {
      _freeErroredFlowControlLinesSnapshot(_ptr, count);
      _isFreed = true;
    }
  }
}

final class ErroredLineFFI extends Struct {
  @Int32()
  external int lineIndex;

  external Pointer<Utf16> filePath;
  external Pointer<Utf16> trimmedLine;
  external Pointer<Utf16> reason;
}

typedef _GetErroredLinesNDart =
    Pointer<ErroredLineFFI> Function(
      Pointer<Utf8> path,
      Pointer<Utf8> basePath,
      Pointer<Int32> outCount,
    );

typedef _FreeErroredLinesNDart =
    Void Function(Pointer<ErroredLineFFI> ptr, Int32 count);

final DynamicLibrary _lib = () {
  if (Platform.isWindows) {
    return DynamicLibrary.open('xxmi_lib_ini_handler.dll');
  }
  throw UnsupportedError('Platform not supported');
}();

final _getErroredFlowControlLines = _lib
    .lookupFunction<_GetErroredLinesNDart, _GetErroredLinesNDart>(
      'GetErroredFlowControlLines',
    );

final _freeErroredFlowControlLinesSnapshot = _lib.lookupFunction<
  _FreeErroredLinesNDart,
  void Function(Pointer<ErroredLineFFI>, int)
>('FreeErroredFlowControlLinesSnapshot');

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////

ErroredLinesResult? getErroredLines(String path, String basePath) {
  final pathPtr = path.toNativeUtf8();
  final basePtr = basePath.toNativeUtf8();
  final countPtr = calloc<Int32>();

  try {
    final resultPtr = _getErroredFlowControlLines(pathPtr, basePtr, countPtr);
    final count = countPtr.value;

    if (resultPtr == nullptr || count <= 0) return null;

    return ErroredLinesResult(resultPtr, count);
  } finally {
    malloc.free(pathPtr);
    malloc.free(basePtr);
    malloc.free(countPtr);
  }
}
