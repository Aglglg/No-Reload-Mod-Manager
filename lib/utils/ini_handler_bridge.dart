import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/get_cloud_data.dart';
import 'dart:io';

import 'package:path/path.dart' as p;

class ErroredLinesReport {
  final Map<String, List<String>> duplicateLibs = {}; //libName, filePaths
  final Map<String, String> nonExistentLibs = {}; //libName, mod

  final Map<String, List<ErroredLine>> crashLines = {}; //filePath, errorLines
  //invalid flow control lines (if-elif-else-endif) and condition line in key section
  final Map<String, List<ErroredLine>> otherError = {}; //filePath,errorLines

  ErroredLinesReport.fromPointer(
    Pointer<ErroredLineFFI> ptr,
    int count,
    Map<String, String> knownModdingLibs,
  ) {
    for (var i = 0; i < count; i++) {
      final item = ptr[i];
      final String filePath = p.normalize(item.filePath.toDartString());
      final int lineIndex = item.lineIndex;
      final String trimmedLine = item.trimmedLine.toDartString();
      final String reason = item.reason.toDartString();

      if (reason.startsWith("CRASH LINE")) {
        (crashLines[filePath] ??= []).add(ErroredLine(lineIndex, trimmedLine));
      } else if (reason.startsWith("DUPLICATE LIB:")) {
        final rawLibName =
            reason.replaceFirst("DUPLICATE LIB:", "").trim().toLowerCase();
        final libName = knownModdingLibs[rawLibName] ?? rawLibName;
        (duplicateLibs[libName] ??= []).add(filePath);
      } else if (reason.startsWith("NON EXISTENT LIB:")) {
        final rawLibName =
            reason.replaceFirst("NON EXISTENT LIB:", "").trim().toLowerCase();
        final libName = knownModdingLibs[rawLibName] ?? rawLibName;
        nonExistentLibs[libName] = filePath;
      } else {
        (otherError[filePath] ??= []).add(ErroredLine(lineIndex, trimmedLine));
      }
    }
  }
}

class ErroredLine {
  final int lineIndex;
  final String trimmedLine;

  ErroredLine(this.lineIndex, this.trimmedLine);
}

final class ErroredLineFFI extends Struct {
  @Int32()
  external int lineIndex;

  external Pointer<Utf16> filePath;
  external Pointer<Utf16> trimmedLine;
  external Pointer<Utf16> reason;
}

typedef _GetErroredLinesNative =
    Pointer<ErroredLineFFI> Function(
      Pointer<Utf8> path,
      Pointer<Utf8> basePath,
      Pointer<Pointer<Utf8>> knownLibNamespaces,
      Int32 knownLibNamespacesCount,
      Pointer<Int32> outCount,
    );

typedef _GetErroredLinesDart =
    Pointer<ErroredLineFFI> Function(
      Pointer<Utf8> path,
      Pointer<Utf8> basePath,
      Pointer<Pointer<Utf8>> knownLibNamespaces,
      int knownLibNamespacesCount,
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

final _getErroredLines = _lib
    .lookupFunction<_GetErroredLinesNative, _GetErroredLinesDart>(
      'GetErroredFlowControlLines',
    );

final _freeErroredFlowControlLinesSnapshot = _lib.lookupFunction<
  _FreeErroredLinesNDart,
  void Function(Pointer<ErroredLineFFI>, int)
>('FreeErroredFlowControlLinesSnapshot');

class IniHandlerException implements Exception {
  const IniHandlerException();
}
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////

ErroredLinesReport getErroredLines(
  String path,
  String basePath,
  Map<String, String> knownModdingLibs,
) {
  final List<String> knownLibNamespaces = knownModdingLibs.keys.toList();
  final pathPtr = path.toNativeUtf8();
  final basePtr = basePath.toNativeUtf8();
  final countPtr = calloc<Int32>();

  final knownLibNamespacesPtrs = calloc<Pointer<Utf8>>(
    knownLibNamespaces.length,
  );

  for (int i = 0; i < knownLibNamespaces.length; i++) {
    knownLibNamespacesPtrs[i] = knownLibNamespaces[i].toNativeUtf8();
  }

  Pointer<ErroredLineFFI> resultPtr = nullptr;
  int count = 0;

  try {
    resultPtr = _getErroredLines(
      pathPtr,
      basePtr,
      knownLibNamespacesPtrs,
      knownLibNamespaces.length,
      countPtr,
    );
    count = countPtr.value;

    if (resultPtr == nullptr) {
      throw IniHandlerException();
    }

    return ErroredLinesReport.fromPointer(resultPtr, count, knownModdingLibs);
  } catch (_) {
    throw IniHandlerException();
  } finally {
    if (resultPtr != nullptr) {
      _freeErroredFlowControlLinesSnapshot(resultPtr, count);
    }

    for (int i = 0; i < knownLibNamespaces.length; i++) {
      malloc.free(knownLibNamespacesPtrs[i]);
    }
    calloc.free(knownLibNamespacesPtrs);
    malloc.free(pathPtr);
    malloc.free(basePtr);
    calloc.free(countPtr);
  }
}

Future<Map<String, String>> fetchKnownModdingLib() async {
  try {
    final response = await httpClient.client.get(
      Uri.parse(ConstantVar.urlJsonUpdatedKnownModdingLib),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> raw = json.decode(response.body);
      return raw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
  } catch (_) {}
  return ConstantVar.knownModdingLibraries;
}
